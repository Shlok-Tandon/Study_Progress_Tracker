import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/leveling.dart';
import '../models/task_item.dart';
import '../models/team.dart';

/// Thrown by [FirestoreService.claimProfile] when the name being claimed
/// already exists and the supplied PIN doesn't match it.
class WrongPinException implements Exception {
  final String name;
  WrongPinException(this.name);
  @override
  String toString() => 'Incorrect PIN for "$name".';
}

/// Thrown when creating a brand-new profile and the team code entered
/// doesn't match the code stored for that team + role.
class WrongTeamCodeException implements Exception {
  final String teamId;
  final TeamRole role;
  WrongTeamCodeException(this.teamId, this.role);
  @override
  String toString() =>
      'Incorrect ${role == TeamRole.leader ? "leader" : "member"} code for '
          '${teamLabel(teamId)}.';
}

/// Thrown when a new profile is being created but no team / code was
/// supplied (returning users don't need these; first-timers do).
class MissingTeamException implements Exception {
  @override
  String toString() => 'Select your team and enter your team code.';
}

/// Exact pre-completion state of the user doc, captured inside
/// completeTask so an Undo can restore it byte-for-byte instead of
/// trying to algebraically invert the streak/badge/XP math.
class UndoSnapshot {
  final int streak;
  final int completedCount;
  final int freezeCount;
  final int badgeCount;
  final int xp;
  final int dailyXp;
  final String? dailyXpDate;
  final Timestamp? lastCompletedAt;

  const UndoSnapshot({
    required this.streak,
    required this.completedCount,
    required this.freezeCount,
    required this.badgeCount,
    required this.xp,
    required this.dailyXp,
    required this.dailyXpDate,
    required this.lastCompletedAt,
  });
}

/// Outcome of completing a task, so the UI can show the right celebration.
class CompleteResult {
  final int streak;
  final bool freezeUsed;
  final bool badgeEarned;

  final int xpEarned;
  final int totalXp;
  final int level;
  final bool leveledUp;

  final int dailyXp;
  final int dailyGoal;
  final bool dailyGoalJustReached;

  /// Everything needed to perfectly reverse this completion.
  final UndoSnapshot restore;

  const CompleteResult({
    required this.streak,
    required this.freezeUsed,
    required this.badgeEarned,
    required this.xpEarned,
    required this.totalXp,
    required this.level,
    required this.leveledUp,
    required this.dailyXp,
    required this.dailyGoal,
    required this.dailyGoalJustReached,
    required this.restore,
  });

  bool get dailyGoalReached => dailyXp >= dailyGoal;
}

/// The current session's team context, resolved from their profile doc.
class Membership {
  final String teamId;
  final TeamRole role;
  const Membership({required this.teamId, required this.role});

  bool get isLeader => role == TeamRole.leader;
  bool get hasTeam => teamId.isNotEmpty;
}

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get tasksRef => _db.collection('tasks');
  CollectionReference get usersRef => _db.collection('users');
  CollectionReference get teamsRef => _db.collection('teams');

  String _slugify(String name) {
    final cleaned = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return cleaned.isEmpty ? 'dc_${DateTime.now().millisecondsSinceEpoch}' : cleaned;
  }

  /// PINs are 4-6 digits. Adjust the range here if you want something else.
  bool isValidPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  /// Local day key (yyyy-mm-dd) used to gate the daily-XP reset.
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _myProfileId {
    final displayName = _auth.currentUser?.displayName;
    if (displayName == null || displayName.trim().isEmpty) {
      throw StateError('No DC name set for the current session.');
    }
    return _slugify(displayName);
  }

  /// Public accessor for the current session's profile id (the slugified DC
  /// name). Throws StateError if no DC name is set yet — callers that just
  /// want a "who am I" comparison for UI purposes should catch that and
  /// fall back to null.
  String get myProfileId => _myProfileId;

  /// Resolves the current session's team + role from their own profile doc.
  /// Screens call this once, then build their team-scoped streams from it.
  Future<Membership> myMembership() async {
    final snap = await usersRef.doc(_myProfileId).get();
    final d = snap.data() as Map<String, dynamic>? ?? {};
    return Membership(
      teamId: (d['teamId'] as String?) ?? '',
      role: roleFromString(d['role'] as String?),
    );
  }

  /// Claims a DC profile by name, gated by a PIN, and (for brand-new
  /// profiles only) by a team code.
  ///
  /// - If [name] has never been claimed, a new profile is created. This
  ///   requires a [teamId], a [role], and the matching [teamCode] for that
  ///   team+role — the code is verified server-side by the security rules
  ///   (a wrong code throws [WrongTeamCodeException]).
  /// - If [name] already exists, the team arguments are ignored entirely:
  ///   a returning user only needs their name + PIN. This device proves it
  ///   knows the PIN, then gets added to the profile's authUids; the team
  ///   and role already stored on the profile carry over untouched.
  Future<String> claimProfile(
      String name,
      String pin, {
        String? teamId,
        TeamRole? role,
        String? teamCode,
      }) async {
    if (!isValidPin(pin)) {
      throw ArgumentError('PIN must be 4-6 digits.');
    }

    final uid = _auth.currentUser!.uid;
    final profileId = _slugify(name);
    final docRef = usersRef.doc(profileId);
    final privateRef = docRef.collection('private').doc('auth');

    // Returning user? If the profile already exists, name + PIN is all we
    // need — skip team selection entirely.
    final existing = await docRef.get();
    if (existing.exists) {
      return _claimExisting(name, uid, pin, docRef);
    }

    // Brand-new profile: a team + role + code are mandatory.
    if (teamId == null || teamId.isEmpty || role == null || teamCode == null || teamCode.trim().isEmpty) {
      throw MissingTeamException();
    }

    // 1) Prove the team code by writing a join doc. The rules only let this
    //    write through if the code matches the stored member/leader code
    //    for this team — so a permission-denied here means a wrong code.
    final joinRef = teamsRef.doc(teamId).collection('joins').doc(uid);
    try {
      await joinRef.set({'code': teamCode.trim(), 'role': roleToString(role)});
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw WrongTeamCodeException(teamId, role);
      rethrow;
    }

    // 2) Create the profile (transaction guards the rare race where two
    //    people claim the same brand-new name at once; the loser falls
    //    through to the returning-user path and will need the PIN).
    final claimedNew = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(docRef);
      if (snap.exists) return false;

      tx.set(docRef, {
        'name': name.trim(),
        'teamId': teamId,
        'role': roleToString(role),
        'streak': 0, 'badgeCount': 0, 'completedCount': 0,
        'freezeCount': 1, // start with a one-day cushion
        'xp': 0, 'dailyXp': 0, 'dailyXpDate': null,
        'dailyGoal': Leveling.defaultDailyGoal,
        'authUids': [uid],
        'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(privateRef, {'pin': pin});
      return true;
    });

    if (claimedNew) return profileId;

    // Lost the create race — someone else just took this exact new name.
    // Fall back to the returning-user path (they'll need the right PIN).
    return _claimExisting(name, uid, pin, docRef);
  }

  /// Adopts an already-existing profile onto this device: prove PIN
  /// knowledge via a write the rules only allow through if it matches the
  /// stored (hidden) PIN, then add this uid to the profile's authUids.
  Future<String> _claimExisting(
      String name,
      String uid,
      String pin,
      DocumentReference docRef,
      ) async {
    final unlockRef = docRef.collection('unlocks').doc(uid);
    try {
      await unlockRef.set({'pin': pin, 'verifiedAt': FieldValue.serverTimestamp()});
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw WrongPinException(name);
      rethrow;
    }

    await docRef.update({
      'authUids': FieldValue.arrayUnion([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Lets an already-signed-in owner change their own PIN (e.g. from a
  /// future "change PIN" row in Settings). Not wired into any screen yet.
  Future<void> changePin(String newPin) async {
    if (!isValidPin(newPin)) {
      throw ArgumentError('PIN must be 4-6 digits.');
    }
    final profileId = _myProfileId;
    await usersRef.doc(profileId).collection('private').doc('auth').update({'pin': newPin});
  }

  // ---------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------

  /// My own tasks — includes anything a leader assigned to me, since those
  /// are stored assigned to my profile id like any other task.
  Stream<QuerySnapshot> streamMyTasks() =>
      tasksRef.where('assignedToUid', isEqualTo: _myProfileId).orderBy('dueDate').snapshots();

  Stream<DocumentSnapshot> streamMyProfile() => usersRef.doc(_myProfileId).snapshots();

  /// Every pending task belonging to [teamId]. Not ordered server-side (so
  /// no composite index is needed) — screens sort by due date client-side.
  Stream<QuerySnapshot> streamTeamTasks(String teamId) =>
      tasksRef.where('teamId', isEqualTo: teamId).snapshots();

  /// Every member of [teamId], whether or not they currently have tasks —
  /// this is what lets the roster show people with an empty task list.
  Stream<QuerySnapshot> streamTeamMembers(String teamId) =>
      usersRef.where('teamId', isEqualTo: teamId).snapshots();

  /// The team's members for ranking. Sorted client-side by live streak in
  /// the leaderboard, so no server-side order (and no index) is required.
  Stream<QuerySnapshot> streamTeamLeaderboard(String teamId) =>
      usersRef.where('teamId', isEqualTo: teamId).snapshots();

  /// One-shot fetch of a team's roster, used to populate the leader's
  /// "assign to" picker. Sorted A->Z by name.
  Future<List<TeamMember>> getTeamMembers(String teamId) async {
    final q = await usersRef.where('teamId', isEqualTo: teamId).get();
    final list = q.docs.map((d) {
      final m = d.data() as Map<String, dynamic>;
      final rawName = (m['name'] as String?)?.trim();
      return TeamMember(
        id: d.id,
        name: (rawName != null && rawName.isNotEmpty) ? rawName : d.id,
        role: roleFromString(m['role'] as String?),
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  // ---------------------------------------------------------------------
  // Task creation
  // ---------------------------------------------------------------------

  /// Adds a task for yourself. Stamps your team on it (read once from your
  /// profile) so it shows up on team-scoped screens and passes the rules.
  Future<void> addTask({required String title, required String subject, required DateTime dueDate}) async {
    final profileId = _myProfileId;
    final me = await usersRef.doc(profileId).get();
    final teamId = (me.data() as Map<String, dynamic>?)?['teamId'] as String? ?? '';
    await tasksRef.add({
      'title': title, 'subject': subject, 'dueDate': Timestamp.fromDate(dueDate),
      'assignedToUid': profileId, 'assignedToName': _auth.currentUser?.displayName ?? 'Unassigned',
      'teamId': teamId,
      'completed': false, 'createdBy': profileId, 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Leader-only: assign the same task to one or more members of their team.
  /// Each member gets their own task document (matching the one-task-per-
  /// person model), stamped with [teamId] and createdBy = the leader, so
  /// the rules can confirm the leader is assigning within their own team.
  /// Written as a single batch so it's all-or-nothing.
  Future<void> addTaskForMembers({
    required String title,
    required String subject,
    required DateTime dueDate,
    required String teamId,
    required List<TeamMember> members,
  }) async {
    if (members.isEmpty) return;
    final leaderId = _myProfileId;
    final batch = _db.batch();
    for (final m in members) {
      final ref = tasksRef.doc();
      batch.set(ref, {
        'title': title, 'subject': subject, 'dueDate': Timestamp.fromDate(dueDate),
        'assignedToUid': m.id, 'assignedToName': m.name,
        'teamId': teamId,
        'completed': false, 'createdBy': leaderId, 'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Edits an existing task's editable fields. Deliberately does NOT touch
  /// assignedToUid/assignedToName/createdBy/createdAt/teamId.
  Future<void> updateTask({
    required String taskId,
    required String title,
    required String subject,
    required DateTime dueDate,
  }) async {
    await tasksRef.doc(taskId).update({
      'title': title,
      'subject': subject,
      'dueDate': Timestamp.fromDate(dueDate),
    });
  }

  // ---------------------------------------------------------------------
  // Completion + undo (unchanged logic)
  // ---------------------------------------------------------------------

  /// Completes a task atomically: deletes it, advances streak (with freeze
  /// protection), awards XP, recomputes level, advances today's daily XP,
  /// and earns a badge on each multiple of 7. The pre-completion state is
  /// snapshotted into [CompleteResult.restore] so it can be undone exactly.
  Future<CompleteResult> completeTask(String taskId) async {
    final userRef = usersRef.doc(_myProfileId);
    final taskRef = tasksRef.doc(taskId);

    return _db.runTransaction<CompleteResult>((tx) async {
      final snap = await tx.get(userRef); // all reads before any writes
      final data = snap.data() as Map<String, dynamic>? ?? {};

      // ---- Capture exact prior state for Undo (raw stored values) ----
      final prevStreak = (data['streak'] as num?)?.toInt() ?? 0;
      final prevFreezes = (data['freezeCount'] as num?)?.toInt() ?? 0;
      final prevCompletedCount = (data['completedCount'] as num?)?.toInt() ?? 0;
      final prevBadgeCount = (data['badgeCount'] as num?)?.toInt() ?? 0;
      final prevXp = (data['xp'] as num?)?.toInt() ?? 0;
      final storedDailyXp = (data['dailyXp'] as num?)?.toInt() ?? 0;
      final storedDailyXpDate = data['dailyXpDate'] as String?;
      final prevLastCompletedAt = data['lastCompletedAt'] as Timestamp?;

      final restore = UndoSnapshot(
        streak: prevStreak,
        completedCount: prevCompletedCount,
        freezeCount: prevFreezes,
        badgeCount: prevBadgeCount,
        xp: prevXp,
        dailyXp: storedDailyXp,
        dailyXpDate: storedDailyXpDate,
        lastCompletedAt: prevLastCompletedAt,
      );

      // ---- Streak ----
      final lastDate = prevLastCompletedAt?.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final gap = lastDate == null
          ? null
          : today.difference(DateTime(lastDate.year, lastDate.month, lastDate.day)).inDays;

      int newStreak;
      bool freezeUsed = false;
      int freezesLeft = prevFreezes;

      if (gap == 0) {
        newStreak = prevStreak == 0 ? 1 : prevStreak;
      } else if (gap == 1) {
        newStreak = prevStreak + 1;
      } else {
        final missed = (gap ?? 999) - 1;
        if (missed <= prevFreezes) {
          newStreak = prevStreak + 1;
          freezesLeft = prevFreezes - missed;
          freezeUsed = true;
        } else {
          newStreak = 1;
        }
      }
      final badgeEarned = newStreak > prevStreak && newStreak % 7 == 0;

      // ---- XP + level ----
      final newXp = prevXp + Leveling.xpPerTask;
      final prevLevel = Leveling.fromXp(prevXp).level;
      final newInfo = Leveling.fromXp(newXp);
      final leveledUp = newInfo.level > prevLevel;

      // ---- Daily goal (reset when the day key changes) ----
      final todayKey = _dateKey(now);
      final goal = (data['dailyGoal'] as num?)?.toInt() ?? Leveling.defaultDailyGoal;
      final prevDailyXp = storedDailyXpDate == todayKey ? storedDailyXp : 0;
      final newDailyXp = prevDailyXp + Leveling.xpPerTask;
      final dailyGoalJustReached = prevDailyXp < goal && newDailyXp >= goal;

      // ---- Writes ----
      tx.delete(taskRef);
      tx.update(userRef, {
        'streak': newStreak,
        'completedCount': FieldValue.increment(1),
        'lastCompletedAt': FieldValue.serverTimestamp(),
        'freezeCount': freezesLeft + (badgeEarned ? 1 : 0),
        if (badgeEarned) 'badgeCount': FieldValue.increment(1),
        'xp': newXp,
        'dailyXp': newDailyXp,
        'dailyXpDate': todayKey,
      });

      return CompleteResult(
        streak: newStreak,
        freezeUsed: freezeUsed,
        badgeEarned: badgeEarned,
        xpEarned: Leveling.xpPerTask,
        totalXp: newXp,
        level: newInfo.level,
        leveledUp: leveledUp,
        dailyXp: newDailyXp,
        dailyGoal: goal,
        dailyGoalJustReached: dailyGoalJustReached,
        restore: restore,
      );
    });
  }

  /// Reverses a completion: re-creates the task and restores the user doc
  /// to its exact pre-completion snapshot. Because it writes the captured
  /// values directly (not increments), the +10 XP, the daily XP, the
  /// streak, any badge, and any consumed/earned freeze are all rolled
  /// back together. Runs as one atomic batch.
  Future<void> undoComplete(TaskItem task, UndoSnapshot s) async {
    final userRef = usersRef.doc(_myProfileId);
    final newTaskRef = tasksRef.doc(); // fresh id for the restored task

    final batch = _db.batch();
    batch.set(newTaskRef, {
      'title': task.title,
      'subject': task.subject,
      'dueDate': Timestamp.fromDate(task.dueDate),
      'assignedToUid': task.assignedToUid,
      'assignedToName': task.assignedToName,
      'teamId': task.teamId,
      'completed': false,
      'createdBy': task.createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(userRef, {
      'streak': s.streak,
      'completedCount': s.completedCount,
      'freezeCount': s.freezeCount,
      'badgeCount': s.badgeCount,
      'xp': s.xp,
      'dailyXp': s.dailyXp,
      'dailyXpDate': s.dailyXpDate,
      'lastCompletedAt': s.lastCompletedAt,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}