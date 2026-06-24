import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get tasksRef => _db.collection('tasks');
  CollectionReference get usersRef => _db.collection('users');

  Future<void> setDcName(String name) async {
    final user = _auth.currentUser!;
    await usersRef.doc(user.uid).set({
      'name': name,
      'streak': 0,
      'badgeCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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