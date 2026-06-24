import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/task_item.dart';

class _Urgency {
  final String label;
  final Color color;
  const _Urgency(this.label, this.color);
}

_Urgency _urgencyFor(TaskItem task, ColorScheme scheme) {
  final days = task.daysUntilDue;
  if (days < 0) return _Urgency('Overdue', scheme.error);
  if (days == 0) return _Urgency('Due today', const Color(0xFFB45309));
  if (days == 1) return _Urgency('Due tomorrow', scheme.tertiary);
  return _Urgency('Due in $days days', scheme.outline);
}

/// Shared Material 3 task card used by Team Progress and My Tasks.
/// Tapping it opens a read-only detail sheet ([onTap]); the small
/// leading circle, when present, is a separate quick "complete" action.
class TaskCard extends StatelessWidget {
  final TaskItem task;
  final bool showAssignee;
  final VoidCallback? onComplete;
  final VoidCallback? onTap;

  const TaskCard({super.key, required this.task, this.showAssignee = true, this.onComplete, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final urgency = _urgencyFor(task, scheme);
    final dueLabel = DateFormat('EEE, MMM d').format(task.dueDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onComplete != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4, top: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onComplete,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.radio_button_unchecked, color: scheme.primary),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title.isEmpty ? 'Untitled task' : task.title,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (task.subject.isNotEmpty)
                          Chip(label: Text(task.subject), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        if (showAssignee) _InfoPill(icon: Icons.person_outline, label: task.assignedToName),
                        _InfoPill(icon: Icons.event_outlined, label: dueLabel),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: urgency.color),
                        const SizedBox(width: 6),
                        Text(urgency.label, style: textTheme.labelMedium?.copyWith(color: urgency.color, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 280.ms, curve: Curves.easeOut).slideY(begin: 0.06, end: 0, duration: 280.ms, curve: Curves.easeOut);
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}