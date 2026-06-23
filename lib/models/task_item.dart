import 'package:cloud_firestore/cloud_firestore.dart';

class TaskItem {
  final String id;
  final String title;
  final String subject;
  final DateTime dueDate;
  final String assignedToUid;
  final bool completed;
  final String createdBy;

  TaskItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.assignedToUid,
    required this.completed,
    required this.createdBy,
  });

  factory TaskItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TaskItem(
      id: doc.id,
      title: d['title'] ?? '',
      subject: d['subject'] ?? '',
      dueDate: (d['dueDate'] as Timestamp).toDate(),
      assignedToUid: d['assignedToUid'] ?? '',
      completed: d['completed'] ?? false,
      createdBy: d['createdBy'] ?? '',
    );
  }
}