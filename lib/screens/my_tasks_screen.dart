import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task_item.dart';
import '../services/firestore_service.dart';
import '../widgets/tactile_tap.dart';
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
      result = await _fs.completeTask(task);
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

    // UI clean-up: remove item ID from loading state once complete
    setState(() => _completingIds.remove(task.id));

    final msg = result.badgeEarned
        ? '🏅 Badge earned! ${result.streak}-day streak'
        : result.freezeUsed
        ? '🛡️ Streak freeze used — your ${result.streak}-day streak is safe'
        : '"${task.title}" completed 🎉';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          try {
            await _fs.undoCompleteTask(task, result);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Failed to undo task completion.'),
            ));
          }
        },
      ),
    ));
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 2));

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(labelText: 'Task title'), onChanged: (_) => setDialogState(() {})),
                  const SizedBox(height: 8),
                  TextField(controller: subjectController, decoration: const InputDecoration(labelText: 'Subject')),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: dueDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (picked != null) setDialogState(() => dueDate = picked);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [const Icon(Icons.event_outlined, size: 18), const SizedBox(width: 8), Text('Due: ${dueDate.toString().split(' ').first}')]),
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
                    await _fs.addTask(title: titleController.text.trim(), subject: subjectController.text.trim(), dueDate: dueDate);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text('Add'),
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
        child: TactileTap(
          onTap: _showAddTaskDialog,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [scheme.primary, scheme.primary.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: scheme.primary.withOpacity(0.45), blurRadius: 20, spreadRadius: 2)],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(end: const Offset(1.06, 1.06), duration: 900.ms, curve: Curves.easeInOut),
        ),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.task_alt, size: 56, color: scheme.primary),
                    const SizedBox(height: 12),
                    Text('No tasks yet', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Tap + to add your first task.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
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
                    onTap: removing ? null : () => showTaskDetailSheet(context, task, onComplete: () => _completeTask(task)),
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