import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_item.dart';

/// Outcome of completing a task, containing pre and post state for precise rollback on undo.
class CompleteResult {
  final int streak;
  final bool freezeUsed;
  final bool badgeEarned;

  // Historical snapshots needed to safely revert the database if undone
  final int previousStreak;
  final int previousFreezeCount;
  final int previousBadgeCount;
  final DateTime? previousLastCompletedAt;

  const CompleteResult({
    required this.streak,
    required this.freezeUsed,
    required this.badgeEarned,
    required this.previousStreak,
    required this.previousFreezeCount,
    required this.previousBadgeCount,
    this.previousLastCompletedAt,
  });
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

  String get _myProfileId {
    final displayName = _auth.currentUser?.displayName;
    if (displayName == null || displayName.trim().isEmpty) {
      throw StateError('No DC name set for the current session.');
    }
    return _slugify(displayName);
  }

  Future<String> claimProfile(String name) async {
    final uid = _auth.currentUser!.uid;
    final profileId = _slugify(name);
    final docRef = usersRef.doc(profileId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (snap.exists) {
        tx.update(docRef, {'authUids': FieldValue.arrayUnion([uid]), 'updatedAt': FieldValue.serverTimestamp()});
      } else {
        tx.set(docRef, {
          'name': name.trim(),
          'streak': 0, 'badgeCount': 0, 'completedCount': 0,
          'freezeCount': 1, // start with a one-day cushion
          'kudosReceived': 0,
          'authUids': [uid],
          'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    return profileId;
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

  /// Completes a task and updates stats atomically within a single transaction.
  Future<CompleteResult> completeTask(TaskItem task) async {
    final userRef = usersRef.doc(_myProfileId);
    final taskRef = tasksRef.doc(task.id);

    return _db.runTransaction<CompleteResult>((tx) async {
      // 1. READ OPERATIONS MUST OCCUR FIRST
      // Fetch user profile data before writing any deletes or updates.
      final snap = await tx.get(userRef);
      final data = snap.data() as Map<String, dynamic>? ?? {};

      final lastDate = (data['lastCompletedAt'] as Timestamp?)?.toDate();
      final currentStreak = (data['streak'] as num?)?.toInt() ?? 0;
      final freezes = (data['freezeCount'] as num?)?.toInt() ?? 0;
      final badgeCount = (data['badgeCount'] as num?)?.toInt() ?? 0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final gap = lastDate == null
          ? null
          : today.difference(DateTime(lastDate.year, lastDate.month, lastDate.day)).inDays;

      int newStreak;
      bool freezeUsed = false;
      int freezesLeft = freezes;

      if (gap == 0) {
        newStreak = currentStreak == 0 ? 1 : currentStreak; // first ever, or same day
      } else if (gap == 1) {
        newStreak = currentStreak + 1;
      } else {
        final missed = (gap ?? 999) - 1; // days skipped
        if (missed <= freezes) {
          newStreak = currentStreak + 1;
          freezesLeft = freezes - missed;
          freezeUsed = true;
        } else {
          newStreak = 1; // streak broken
        }
      }

      final badgeEarned = newStreak > currentStreak && newStreak % 7 == 0;

      // 2. WRITE OPERATIONS OCCUR SECOND
      // Delete the task and update user statistics.
      tx.delete(taskRef);

      tx.update(userRef, {
        'streak': newStreak,
        'completedCount': FieldValue.increment(1),
        'lastCompletedAt': FieldValue.serverTimestamp(),
        'freezeCount': freezesLeft + (badgeEarned ? 1 : 0),
        'updatedAt': FieldValue.serverTimestamp(),
        if (badgeEarned) 'badgeCount': FieldValue.increment(1),
      });

      return CompleteResult(
        streak: newStreak,
        freezeUsed: freezeUsed,
        badgeEarned: badgeEarned,
        previousStreak: currentStreak,
        previousFreezeCount: freezes,
        previousBadgeCount: badgeCount,
        previousLastCompletedAt: lastDate,
      );
    });
  }

  /// Restores a deleted task with its original ID and fully rolls back the completion metrics.
  Future<void> undoCompleteTask(TaskItem task, CompleteResult result) async {
    final userRef = usersRef.doc(_myProfileId);
    final taskRef = tasksRef.doc(task.id);

    await _db.runTransaction((tx) async {
      // Recreate the task using its original document ID and parameters (Write operation)
      tx.set(taskRef, {
        'title': task.title,
        'subject': task.subject,
        'dueDate': Timestamp.fromDate(task.dueDate),
        'assignedToUid': _myProfileId,
        'assignedToName': _auth.currentUser?.displayName ?? 'Unassigned',
        'completed': false,
        'createdBy': _myProfileId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Prepare user profile rollback payload
      final rollbackData = <String, dynamic>{
        'streak': result.previousStreak,
        'completedCount': FieldValue.increment(-1), // Decrements count safely
        'freezeCount': result.previousFreezeCount,
        'badgeCount': result.previousBadgeCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Restore lastCompletedAt exactly as it was (or remove it if there wasn't one)
      if (result.previousLastCompletedAt != null) {
        rollbackData['lastCompletedAt'] = Timestamp.fromDate(result.previousLastCompletedAt!);
      } else {
        rollbackData['lastCompletedAt'] = FieldValue.delete();
      }

      // Apply rollback (Write operation)
      tx.update(userRef, rollbackData);
    });
  }

  /// Team Kudos — increments a teammate's received-kudos count.
  Future<void> sendKudos(String targetProfileId) =>
      usersRef.doc(targetProfileId).update({'kudosReceived': FieldValue.increment(1)});
}