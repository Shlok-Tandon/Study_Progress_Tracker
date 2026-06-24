import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_item.dart';

/// A read-only bottom sheet showing a task's full details. [onComplete]
/// is only passed in from My Tasks — the Team tab omits it, since only
/// the assignee may complete their own task.
Future<void> showTaskDetailSheet(
    BuildContext context,
    TaskItem task, {
      VoidCallback? onComplete,
    }) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _TaskDetailSheet(task: task, onComplete: onComplete),
  );
}

class _TaskDetailSheet extends StatelessWidget {
  final TaskItem task;
  final VoidCallback? onComplete;
  const _TaskDetailSheet({required this.task, this.onComplete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              task.title.isEmpty ? 'Untitled task' : task.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _DetailRow(icon: Icons.menu_book_outlined, label: 'Subject', value: task.subject.isEmpty ? '—' : task.subject),
            _DetailRow(icon: Icons.person_outline, label: 'Assigned to', value: task.assignedToName),
            _DetailRow(icon: Icons.event_outlined, label: 'Due date', value: DateFormat('EEEE, MMM d, y').format(task.dueDate)),
            if (onComplete != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onComplete!();
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark complete'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}