import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/task_item.dart';
import '../theme/app_game_colors.dart';
import 'animated_checkbox.dart';
import 'tactile_surface.dart';

class _Urgency {
  final String label;
  final Color color;
  const _Urgency(this.label, this.color);
}

_Urgency _urgencyFor(TaskItem task, AppGameColors game, ColorScheme scheme) {
  final days = task.daysUntilDue;
  if (days < 0) return _Urgency('Overdue', scheme.error);
  if (days == 0) return _Urgency('Due today', game.streak);
  if (days == 1) return _Urgency('Due tomorrow', game.accent);
  return _Urgency('Due in $days days', scheme.outline);
}

Color _subjectColor(String subject, AppGameColors game) {
  if (subject.isEmpty) return game.accent;
  final palette = [game.accent, game.success, game.streak, game.gold];
  return palette[subject.toLowerCase().hashCode.abs() % palette.length];
}

/// Shared task card for Team Progress and My Tasks. [showCheckbox]
/// controls whether the complete-action circle renders at all (Team
/// stays read-only); [checked] drives its visual state independently
/// of whether [onComplete] is currently enabled.
class TaskCard extends StatelessWidget {
  final TaskItem task;
  final bool showAssignee;
  final bool showCheckbox;
  final bool checked;
  final VoidCallback? onComplete;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.task,
    this.showAssignee = true,
    this.showCheckbox = false,
    this.checked = false,
    this.onComplete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final game = Theme.of(context).extension<AppGameColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final urgency = _urgencyFor(task, game, scheme);
    final subjectColor = _subjectColor(task.subject, game);
    final dueLabel = DateFormat('EEE, MMM d').format(task.dueDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TactileSurface(
        color: scheme.surfaceContainerHigh,
        edgeColor: scheme.surfaceContainerHighest,
        radius: 20,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            // Stack + Positioned gives the colored stripe full height for
            // free — no IntrinsicHeight (which forces a 2nd layout pass).
            child: Stack(
              children: [
                Positioned(top: 0, bottom: 0, left: 0, child: Container(width: 5, color: subjectColor)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(19, 14, 14, 14), // 14 + 5px stripe
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showCheckbox)
                        Padding(
                          padding: const EdgeInsets.only(right: 10, top: 2),
                          child: AnimatedCheckbox(checked: checked, color: scheme.primary, onTap: onComplete),
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
                                  Chip(
                                    label: Text(task.subject),
                                    backgroundColor: subjectColor.withOpacity(0.16),
                                    labelStyle: TextStyle(color: subjectColor, fontWeight: FontWeight.w600, fontSize: 12),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    side: BorderSide.none,
                                  ),
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
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 280.ms, curve: Curves.easeOut).slideY(begin: 0.08, end: 0, duration: 280.ms, curve: Curves.easeOut);
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