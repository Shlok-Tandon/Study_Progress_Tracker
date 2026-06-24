import 'package:cloud_firestore/cloud_firestore.dart';

/// A single task assigned to one DC (team member).
///
/// Completed tasks are deleted from Firestore rather than flagged, so any
/// task that still exists in the `tasks` collection is, by definition,
/// pending. `completed` is kept only as a defensive fallback in case a
/// document is ever edited directly in the Firebase console.
class TaskItem {
  final String id;
  final String title;
  final String subject;
  final DateTime dueDate;
  final String assignedToUid;
  final String assignedToName;
  final String createdBy;
  final bool completed;

  TaskItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.assignedToUid,
    required this.assignedToName,
    required this.createdBy,
    required this.completed,
  });

  factory TaskItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final name = (d['assignedToName'] as String?)?.trim();
    return TaskItem(
      id: doc.id,
      title: (d['title'] as String?)?.trim() ?? '',
      subject: (d['subject'] as String?)?.trim() ?? '',
      dueDate: (d['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedToUid: d['assignedToUid'] as String? ?? '',
      assignedToName: (name == null || name.isEmpty) ? 'Unassigned' : name,
      createdBy: d['createdBy'] as String? ?? '',
      completed: d['completed'] as bool? ?? false,
    );
  }

  /// Days between today and the due date. Negative means overdue.
  /// Drives the urgency indicator on the task card — derived from data
  /// that already exists, no new field required.
  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }
}