import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get tasksRef => _db.collection('tasks');
  CollectionReference get usersRef => _db.collection('users');

  /// Turns a free-typed DC name into a stable document ID, so the same
  /// name always maps to the same Firestore doc — independent of which
  /// (ephemeral) anonymous Auth session happens to be active. This is
  /// what lets someone log out and back in with the same name and get
  /// their original tasks/streak back instead of a brand new identity.
  String _slugify(String name) {
    final lower = name.trim().toLowerCase();
    final collapsed = lower.replaceAll(RegExp(r'\s+'), '_');
    final cleaned = collapsed.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return cleaned.isEmpty ? 'dc_${DateTime.now().millisecondsSinceEpoch}' : cleaned;
  }

  /// The stable profile ID for whoever is currently signed in, derived
  /// from their Auth display name (set once at DC-name entry, and
  /// persisted by Firebase Auth across app restarts as long as they
  /// don't explicitly log out).
  String get _myProfileId {
    final displayName = _auth.currentUser?.displayName;
    if (displayName == null || displayName.trim().isEmpty) {
      throw StateError('No DC name set for the current session.');
    }
    return _slugify(displayName);
  }

  /// Looks up the profile for [name]. If it already exists, this
  /// session's uid is added to its authUids list so it can manage that
  /// profile's tasks going forward. If it doesn't exist, it's created
  /// once. Either way the returned ID is stable for that name — no
  /// duplicate profiles are ever created for the same DC name.
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

  Future<void> addTask({
    required String title,
    required String subject,
    required DateTime dueDate,
  }) async {
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

  Future<void> completeTask(String taskId) async {
    await tasksRef.doc(taskId).delete();
  }

  Stream<QuerySnapshot> streamLeaderboard() {
    return usersRef.orderBy('streak', descending: true).snapshots();
  }
}