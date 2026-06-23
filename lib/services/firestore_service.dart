import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/team_member.dart';
import '../models/task_item.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get membersRef => _db.collection('team_members');
  CollectionReference get tasksRef => _db.collection('tasks');
  CollectionReference get usersRef => _db.collection('users');

  Stream<List<TeamMember>> streamTeamMembers() {
    return membersRef.orderBy('name').snapshots().map(
          (s) => s.docs.map((d) => TeamMember.fromDoc(d)).toList(),
    );
  }

  Future<void> seedMembersIfEmpty(List<String> names) async {
    final snap = await membersRef.limit(1).get();
    if (snap.docs.isNotEmpty) return;
    final batch = _db.batch();
    for (final n in names) {
      final doc = membersRef.doc();
      batch.set(doc, {
        'name': n,
        'claimedByUid': null,
        'claimedByEmail': null,
        'claimedAt': null,
      });
    }
    await batch.commit();
  }

  Future<void> claimMemberName(String memberDocId) async {
    final user = _auth.currentUser!;
    final docRef = membersRef.doc(memberDocId);

    await _db.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      final data = snapshot.data() as Map<String, dynamic>;
      final claimedByUid = data['claimedByUid'] as String?;

      if (claimedByUid == null || claimedByUid == user.uid) {
        tx.update(docRef, {
          'claimedByUid': user.uid,
          'claimedByEmail': user.email,
          'claimedAt': FieldValue.serverTimestamp(),
        });

        tx.set(usersRef.doc(user.uid), {
          'email': user.email,
          'selectedMemberId': memberDocId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        throw Exception('This name is already claimed.');
      }
    });
  }

  Stream<QuerySnapshot> streamMyTasks() {
    final uid = _auth.currentUser!.uid;
    return tasksRef.where('assignedToUid', isEqualTo: uid).orderBy('dueDate').snapshots();
  }

  Stream<QuerySnapshot> streamAllTasks() {
    return tasksRef.orderBy('dueDate').snapshots();
  }

  Future<void> addTask({
    required String title,
    required String subject,
    required DateTime dueDate,
    required String assignedToUid,
  }) async {
    final uid = _auth.currentUser!.uid;
    await tasksRef.add({
      'title': title,
      'subject': subject,
      'dueDate': Timestamp.fromDate(dueDate),
      'assignedToUid': assignedToUid,
      'completed': false,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleTask(String taskId, bool value) async {
    await tasksRef.doc(taskId).update({'completed': value});
  }

  Stream<QuerySnapshot> streamLeaderboard() {
    return usersRef.orderBy('streak', descending: true).snapshots();
  }
}