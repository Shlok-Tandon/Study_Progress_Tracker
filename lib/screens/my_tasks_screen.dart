import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task_item.dart';
import '../services/firestore_service.dart';
import '../widgets/celebration_modal.dart';
import '../widgets/empty_state.dart';
import '../widgets/tactile_3d.dart';
import '../widgets/task_card.dart';
import '../widgets/task_detail_sheet.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  final _fs = FirestoreService();
  final Set<String> _completingIds = {};
  late final Stream<QuerySnapshot> _tasksStream = _fs.streamMyTasks(); // cached once

  Future<void> _completeTask(TaskItem task) async {
    if (_completingIds.contains(task.id)) return; // guard double-tap
    setState(() => _completingIds.add(task.id));
    await Future.delayed(const Duration(milliseconds: 320)); // let the checkbox bounce play

    CompleteResult result;
    try {
      result = await _fs.completeTask(task.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _completingIds.remove(task.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not complete "${task.title}"'),
        action: SnackBarAction(label: 'Retry', onPressed: () => _completeTask(task)),
      ));
      return;
    }

    if (!mounted) return;

    final title = result.badgeEarned
        ? '🏅 Badge Earned!'
        : result.freezeUsed
        ? '🛡️ Streak Saved!'
        : 'Task Complete!';
    final subtitle = result.badgeEarned
        ? '${result.streak}-day streak — keep it going!'
        : result.freezeUsed
        ? 'A streak freeze protected your ${result.streak}-day streak.'
        : '"${task.title}" is done. Nice work!';

    showCelebrationModal(
      context,
      title: title,
      subtitle: subtitle,
      secondaryLabel: 'Undo',
      onSecondary: () => _fs.addTask(title: task.title, subject: task.subject, dueDate: task.dueDate),
    );
  }

  /// Shared dialog for both creating a new task and editing an existing
  /// one. When [existing] is null this adds a task; otherwise it edits
  /// that task in place — ownership/creation fields are left untouched.
  void _showTaskDialog({TaskItem? existing}) {
    final isEditing = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final subjectController = TextEditingController(text: existing?.subject ?? '');

    DateTime dueDate = existing?.dueDate ?? DateTime.now().add(const Duration(days: 2));
    TimeOfDay dueTime = existing != null
        ? TimeOfDay(hour: existing.dueDate.hour, minute: existing.dueDate.minute)
        : const TimeOfDay(hour: 23, minute: 59); // default: due by end of day

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Task' : 'Add Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Task title'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: subjectController, decoration: const InputDecoration(labelText: 'Subject')),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: isEditing ? DateTime.now().subtract(const Duration(days: 365)) : DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setDialogState(() => dueDate = picked);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.event_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text('Date: ${dueDate.toString().split(' ').first}'),
                      ]),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: dueTime);
                      if (picked != null) setDialogState(() => dueTime = picked);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.schedule_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text('Time: ${dueTime.format(context)}'),
                      ]),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                FilledButton(
                  onPressed: titleController.text.trim().isEmpty
                      ? null
                      : () async {
                    final combinedDueDate =
                    DateTime(dueDate.year, dueDate.month, dueDate.day, dueTime.hour, dueTime.minute);
                    if (isEditing) {
                      await _fs.updateTask(
                        taskId: existing!.id,
                        title: titleController.text.trim(),
                        subject: subjectController.text.trim(),
                        dueDate: combinedDueDate,
                      );
                    } else {
                      await _fs.addTask(
                        title: titleController.text.trim(),
                        subject: subjectController.text.trim(),
                        dueDate: combinedDueDate,
                      );
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: Text(isEditing ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      floatingActionButton: RepaintBoundary(
        child: Tactile3DButton(
          onTap: () => _showTaskDialog(),
          color: scheme.primary,
          radius: 22,
          edgeThickness: 5,
          width: 60,
          height: 60,
          padding: const EdgeInsets.all(16),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(end: const Offset(1.04, 1.04), duration: 1100.ms, curve: Curves.easeInOut),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _tasksStream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Something went wrong: ${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Loading your tasks…')]));
          }

          final tasks = snap.data!.docs.map((d) => TaskItem.fromDoc(d)).where((t) => !t.completed).toList();

          if (tasks.isEmpty) {
            return EmptyState(
              art: const EmptyTasksArt(),
              title: 'No tasks yet',
              subtitle: 'Add your first task and start building a streak.',
              action: FilledButton.icon(
                onPressed: () => _showTaskDialog(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add your first task'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 90),
            itemCount: tasks.length,
            itemBuilder: (_, i) {
              final task = tasks[i];
              final removing = _completingIds.contains(task.id);
              return AnimatedSize(
                key: ValueKey(task.id),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: removing ? 0 : 1,
                  duration: const Duration(milliseconds: 260),
                  child: TaskCard(
                    task: task,
                    showAssignee: false,
                    showCheckbox: true,
                    checked: removing,
                    onComplete: removing ? null : () => _completeTask(task),
                    onTap: removing
                        ? null
                        : () => showTaskDetailSheet(
                      context,
                      task,
                      onComplete: () => _completeTask(task),
                      onEdit: () => _showTaskDialog(existing: task),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}