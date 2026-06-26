import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/leveling.dart';
import '../models/streak_status.dart';
import '../models/task_item.dart';
import '../services/firestore_service.dart';
import '../widgets/celebration_modal.dart';
import '../widgets/daily_goal_ring.dart';
import '../widgets/empty_state.dart';
import '../widgets/mascot.dart';
import '../widgets/tactile_3d.dart';
import '../widgets/task_card.dart';
import '../widgets/task_detail_sheet.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

/// Task-state signals the mascot reacts to. Derived from the live task
/// list, recomputed on every snapshot.
class _TaskStats {
  final int pending;
  final int overdue;
  final int dueToday;
  const _TaskStats({required this.pending, required this.overdue, required this.dueToday});

  factory _TaskStats.from(List<TaskItem> tasks) {
    int o = 0, d = 0;
    for (final t in tasks) {
      final n = t.daysUntilDue;
      if (n < 0) {
        o++;
      } else if (n == 0) {
        d++;
      }
    }
    return _TaskStats(pending: tasks.length, overdue: o, dueToday: d);
  }
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  final _fs = FirestoreService();
  final Set<String> _completingIds = {};
  late final Stream<QuerySnapshot> _tasksStream = _fs.streamMyTasks(); // cached once
  late final Stream<DocumentSnapshot> _profileStream = _fs.streamMyProfile(); // cached once

  // Pending count as of the latest build, captured before completion so the
  // "cleared your last task" modal isn't fooled by the optimistic update.
  int _pendingCount = 0;

  Future<void> _completeTask(TaskItem task) async {
    if (_completingIds.contains(task.id)) return; // guard double-tap
    final wasLastTask = _pendingCount <= 1; // captured before any await

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

    // Single most meaningful celebration, highest priority first.
    final String title;
    final String subtitle;
    final MascotMood mood;

    if (result.leveledUp) {
      title = '⭐ Level ${result.level}!';
      subtitle = 'You reached ${Leveling.titleFor(result.level)}. Keep climbing!';
      mood = MascotMood.celebrate;
    } else if (result.badgeEarned) {
      title = '🏅 Badge Earned!';
      subtitle = '${result.streak}-day streak. Keep it going!';
      mood = MascotMood.celebrate;
    } else if (wasLastTask) {
      title = '🎉 All caught up!';
      subtitle = "Every task done. Enjoy the clear list!";
      mood = MascotMood.proud;
    } else if (result.dailyGoalJustReached) {
      title = '🎯 Daily Goal Hit!';
      subtitle = "${result.dailyXp} XP today. You're on a roll!";
      mood = MascotMood.goalReached;
    } else if (result.freezeUsed) {
      title = '🛡️ Streak Saved!';
      subtitle = 'A streak freeze protected your ${result.streak}-day streak.';
      mood = MascotMood.cheer;
    } else {
      title = 'Task Complete! +${result.xpEarned} XP';
      subtitle = '"${task.title}" is done. Nice work!';
      mood = MascotMood.cheer;
    }

    showCelebrationModal(
      context,
      title: title,
      subtitle: subtitle,
      mascotMood: mood,
      secondaryLabel: 'Undo',
      onSecondary: () => _undoComplete(task, result.restore),
    );
  }

  /// Reverses a completion (re-adds the task and rolls back XP, daily XP,
  /// streak, badge and freeze together) with a failure snackbar.
  Future<void> _undoComplete(TaskItem task, UndoSnapshot snapshot) async {
    try {
      await _fs.undoComplete(task, snapshot);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not undo. Please try again.')),
      );
    }
  }

  /// Shared dialog for both creating a new task and editing an existing one.
  void _showTaskDialog({TaskItem? existing}) {
    final isEditing = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final subjectController = TextEditingController(text: existing?.subject ?? '');

    DateTime dueDate = existing?.dueDate ?? DateTime.now().add(const Duration(days: 2));
    TimeOfDay dueTime = existing != null
        ? TimeOfDay(hour: existing.dueDate.hour, minute: existing.dueDate.minute)
        : const TimeOfDay(hour: 23, minute: 59);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Task' : 'Add Task'),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              content: SingleChildScrollView(
                child: Column(
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

  Widget _taskArea(BuildContext context, AsyncSnapshot<QuerySnapshot> snap, List<TaskItem> tasks) {
    if (snap.hasError) return Center(child: Text('Something went wrong: ${snap.error}'));
    if (!snap.hasData) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Loading your tasks…'),
        ]),
      );
    }

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
      // The task stream wraps the whole body so the header sees task counts.
      body: StreamBuilder<QuerySnapshot>(
        stream: _tasksStream,
        builder: (context, snap) {
          final hasData = snap.hasData;
          final tasks = hasData
              ? snap.data!.docs.map((d) => TaskItem.fromDoc(d)).where((t) => !t.completed).toList()
              : <TaskItem>[];
          if (hasData) _pendingCount = tasks.length;
          final stats = hasData ? _TaskStats.from(tasks) : null;

          return Column(
            children: [
              _DailyHeader(stream: _profileStream, stats: stats),
              Expanded(child: _taskArea(context, snap, tasks)),
            ],
          );
        },
      ),
    );
  }
}

/// Header pinned above the task list: the reacting mascot, the lifetime
/// level + XP-to-next bar, and today's daily-goal ring. Combines the
/// profile stream (XP, live streak, daily progress) with live [stats]
/// (pending, overdue, due-today) to pick the mascot mood.
class _DailyHeader extends StatelessWidget {
  final Stream<DocumentSnapshot> stream;
  final _TaskStats? stats;
  const _DailyHeader({required this.stream, required this.stats});

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Mood resolver, urgency-first. A task you've already missed (overdue)
  /// always wins; rest nudges never override a real deadline or a heavy
  /// workload.
  static MascotMood _mood({
    required _TaskStats? stats,
    required int todayXp,
    required int goal,
    required int streak,
    required DateTime now,
  }) {
    final hour = now.hour;
    final goalReached = todayXp >= goal;

    if (stats != null && stats.overdue > 0) return MascotMood.overdue;        // 1 frightened
    if (stats != null && stats.dueToday > 0) return MascotMood.dueToday;      // 2 nervous
    if (stats != null && stats.pending == 0) return MascotMood.proud;         // 3 inbox zero
    if (stats != null && stats.pending >= 4) return MascotMood.grind;         // 4 heavy load
    if (hour < 6) return MascotMood.sleepy;                                   // 5 rest nudge (12am–6am)
    if (goalReached) return MascotMood.goalReached;                           // 6 goal met
    if (streak >= 1 && todayXp == 0 && hour >= 17) return MascotMood.atRisk;  // 7 streak nudge
    return MascotMood.idle;                                                   // 8 default
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot>(
      stream: stream,
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final xp = (data?['xp'] as num?)?.toInt() ?? 0;
        final goal = (data?['dailyGoal'] as num?)?.toInt() ?? Leveling.defaultDailyGoal;
        final storedKey = data?['dailyXpDate'] as String?;
        final rawDaily = (data?['dailyXp'] as num?)?.toInt() ?? 0;
        final now = DateTime.now();
        final todayXp = storedKey == _dateKey(now) ? rawDaily : 0;

        // Live streak so a lapsed streak doesn't keep triggering the at-risk
        // nudge as if it were still alive.
        final streak = computeStreakStatus(
          storedStreak: (data?['streak'] as num?)?.toInt() ?? 0,
          lastCompletedAt: (data?['lastCompletedAt'] as Timestamp?)?.toDate(),
          freezeCount: (data?['freezeCount'] as num?)?.toInt() ?? 0,
          now: now,
        ).current;

        final info = Leveling.fromXp(xp);
        final mood = _mood(stats: stats, todayXp: todayXp, goal: goal, streak: streak, now: now);

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(24)),
          child: Row(
            children: [
              Mascot(mood: mood, size: 72),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                          child: Text('Lv ${info.level}', style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            Leveling.titleFor(info.level),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: info.progress,
                        minHeight: 7,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${info.xpToNext} XP to Level ${info.level + 1}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DailyGoalRing(value: todayXp, goal: goal, size: 66),
            ],
          ),
        );
      },
    );
  }
}