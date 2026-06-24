import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get tasksRef => _db.collection('tasks');
  CollectionReference get usersRef => _db.collection('users');

  String _slugify(String name) {
    final lower = name.trim().toLowerCase();
    final collapsed = lower.replaceAll(RegExp(r'\s+'), '_');
    final cleaned = collapsed.replaceAll(RegExp(r'[^a-z0-9_]'), '');
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
        tx.update(docRef, {
          'authUids': FieldValue.arrayUnion([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(docRef, {
          'name': name.trim(),
          'streak': 0,
          'badgeCount': 0,
          'completedCount': 0,
          'authUids': [uid],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    return profileId;
  }

  Stream<QuerySnapshot> streamMyTasks() {
    return tasksRef.where('assignedToUid', isEqualTo: _myProfileId).orderBy('dueDate').snapshots();
  }

  Stream<QuerySnapshot> streamAllTasks() {
    return tasksRef.orderBy('dueDate').snapshots();
  }

  Stream<DocumentSnapshot> streamMyProfile() {
    return usersRef.doc(_myProfileId).snapshots();
  }

  Future<void> addTask({required String title, required String subject, required DateTime dueDate}) async {
    final profileId = _myProfileId;
    await tasksRef.add({
      'title': title,
      'subject': subject,
      'dueDate': Timestamp.fromDate(dueDate),
      'assignedToUid': profileId,
      'assignedToName': _auth.currentUser?.displayName ?? 'Unassigned',
      'completed': false,
      'createdBy': profileId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes the task, then updates the assignee's streak: completing a
  /// task today after one yesterday extends the streak by 1; a second
  /// completion the same day leaves it unchanged; any gap resets it to 1.
  /// Crossing a multiple of 7 awards a badge.
  Future<void> completeTask(String taskId) async {
    final profileId = _myProfileId;
    final userRef = usersRef.doc(profileId);

    await tasksRef.doc(taskId).delete();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final lastDate = (data['lastCompletedAt'] as Timestamp?)?.toDate();
      final currentStreak = (data['streak'] as int?) ?? 0;
      final today = DateTime.now();

      final isSameDay = lastDate != null && lastDate.year == today.year && lastDate.month == today.month && lastDate.day == today.day;
      final isYesterday = lastDate != null && today.difference(DateTime(lastDate.year, lastDate.month, lastDate.day)).inDays == 1;

      final newStreak = isSameDay ? currentStreak : (isYesterday ? currentStreak + 1 : 1);
      final crossedMilestone = newStreak > currentStreak && newStreak % 7 == 0;

      tx.update(userRef, {
        'streak': newStreak,
        'completedCount': FieldValue.increment(1),
        'lastCompletedAt': FieldValue.serverTimestamp(),
        if (crossedMilestone) 'badgeCount': FieldValue.increment(1),
      });
    });
  }

  Stream<QuerySnapshot> streamLeaderboard() {
    return usersRef.orderBy('streak', descending: true).snapshots();
  }
}