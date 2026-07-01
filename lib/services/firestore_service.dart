import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/leveling.dart';
import '../models/task_item.dart';

/// Thrown by [FirestoreService.claimProfile] when the name being claimed
/// already exists and the supplied PIN doesn't match it.
class WrongPinException implements Exception {
  final String name;
  WrongPinException(this.name);
  @override
  String toString() => 'Incorrect PIN for "$name".';
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

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get tasksRef => _db.collection('tasks');
  CollectionReference get usersRef => _db.collection('users');

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
  /// name). Lets screens ask "is this me?" without owning their own copy of
  /// the slugify logic. Throws StateError if no DC name is set yet (i.e.
  /// before DcNameScreen has ever been completed) — callers that just want
  /// a "who am I" comparison for UI purposes should catch that and fall
  /// back to null.
  String get myProfileId => _myProfileId;

  /// Claims a DC profile by name, gated by a PIN.
  ///
  /// - If [name] has never been claimed, this creates the profile and
  ///   sets [pin] as its PIN (first writer wins if two people somehow
  ///   claim the same brand-new name at the same instant; the loser
  ///   falls through to the "existing profile" path below and will see
  ///   [WrongPinException] if their PIN doesn't match the winner's).
  /// - If [name] already exists, this device must prove it knows the
  ///   correct PIN before it's added to that profile's authUids. A wrong
  ///   PIN throws [WrongPinException]; nothing about the real PIN is
  ///   ever sent back to the client either way.
  Future<String> claimProfile(String name, String pin) async {
    if (!isValidPin(pin)) {
      throw ArgumentError('PIN must be 4-6 digits.');
    }

    final uid = _auth.currentUser!.uid;
    final profileId = _slugify(name);
    final docRef = usersRef.doc(profileId);
    final privateRef = docRef.collection('private').doc('auth');

    // Try to atomically claim a brand-new name. Wrapped in a transaction
    // so a race between two people typing the same new name at once is
    // resolved safely: exactly one of them creates the profile, and the
    // other falls through to the existing-profile PIN check below.
    final claimedNew = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(docRef);
      if (snap.exists) return false;

      tx.set(docRef, {
        'name': name.trim(),
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

    // Existing profile: prove PIN knowledge via a write the security
    // rules only allow through if it matches the stored (hidden) PIN —
    // or, for a profile that predates the PIN system entirely (no
    // private/auth doc yet), the rules let the first claimant through
    // so the account can be adopted.
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

    // If this profile never had a PIN (a legacy account), this is where
    // it gets one, now that we're a verified owner. If it already had a
    // matching PIN, this just rewrites the same value — harmless.
    await privateRef.set({'pin': pin});
    return profileId;
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

  Stream<QuerySnapshot> streamMyTasks() =>
      tasksRef.where('assignedToUid', isEqualTo: _myProfileId).orderBy('dueDate').snapshots();
  Stream<QuerySnapshot> streamAllTasks() => tasksRef.orderBy('dueDate').snapshots();
  Stream<QuerySnapshot> streamUsers() => usersRef.snapshots();
  Stream<QuerySnapshot> streamLeaderboard() => usersRef.orderBy('streak', descending: true).snapshots();
  Stream<DocumentSnapshot> streamMyProfile() => usersRef.doc(_myProfileId).snapshots();

  Future<void> addTask({required String title, required String subject, required DateTime dueDate}) async {
    final profileId = _myProfileId;
    await tasksRef.add({
      'title': title, 'subject': subject, 'dueDate': Timestamp.fromDate(dueDate),
      'assignedToUid': profileId, 'assignedToName': _auth.currentUser?.displayName ?? 'Unassigned',
      'completed': false, 'createdBy': profileId, 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Edits an existing task's editable fields. Deliberately does NOT touch
  /// assignedToUid/assignedToName/createdBy/createdAt.
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
    final profileId = _myProfileId;

    final batch = _db.batch();
    batch.set(newTaskRef, {
      'title': task.title,
      'subject': task.subject,
      'dueDate': Timestamp.fromDate(task.dueDate),
      'assignedToUid': profileId,
      'assignedToName': _auth.currentUser?.displayName ?? 'Unassigned',
      'completed': false,
      'createdBy': profileId,
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