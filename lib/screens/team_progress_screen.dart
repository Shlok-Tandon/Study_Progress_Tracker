import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task_item.dart';
import '../services/firestore_service.dart';
import '../theme/app_game_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_counter.dart';
import '../widgets/tactile_surface.dart';
import '../widgets/task_card.dart';
import '../widgets/task_detail_sheet.dart';

class TeamProgressScreen extends StatefulWidget {
  const TeamProgressScreen({super.key});

  @override
  State<TeamProgressScreen> createState() => _TeamProgressScreenState();
}

class _DcGroup {
  final String name;
  final int streak;
  final List<TaskItem> tasks;
  _DcGroup(this.name, this.streak, this.tasks);
}

class _TeamProgressScreenState extends State<TeamProgressScreen> {
  final _fs = FirestoreService();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  // Cached once — no more resubscribe-every-rebuild.
  late final Stream<QuerySnapshot> _usersStream = _fs.streamUsers();
  late final Stream<QuerySnapshot> _tasksStream = _fs.streamAllTasks();

  // Hint cycles via a notifier so ONLY the hint Text rebuilds, never the screen.
  static const _hints = ['Search by task, subject, or DC name', 'Try a subject like "Math"', "Find a teammate's tasks"];
  final ValueNotifier<int> _hintIndex = ValueNotifier(0);
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_searchFocus.hasFocus || _query.isNotEmpty) return;
      _hintIndex.value = (_hintIndex.value + 1) % _hints.length;
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _hintIndex.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<_DcGroup> _groupByDc(List<TaskItem> tasks, Map<String, int> streakByUid) {
    final map = <String, List<TaskItem>>{};
    for (final t in tasks) {
      map.putIfAbsent(t.assignedToUid, () => []).add(t);
    }
    final groups = map.entries.map((e) => _DcGroup(e.value.first.assignedToName, streakByUid[e.key] ?? 0, e.value)).toList();
    groups.sort((a, b) {
      final byCount = b.tasks.length.compareTo(a.tasks.length);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final game = Theme.of(context).extension<AppGameColors>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Team Progress')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
                    color: scheme.surfaceContainerHigh,
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    decoration: const InputDecoration(border: InputBorder.none, prefixIcon: Icon(Icons.search)),
                  ),
                ),
                if (_query.isEmpty)
                  IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: ValueListenableBuilder<int>(
                        valueListenable: _hintIndex,
                        builder: (_, i, __) => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Text(_hints[i], key: ValueKey(i), style: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.7))),
                        ),
                      ),
                    ),
                  ),
                if (_query.isNotEmpty)
                  Positioned(
                    right: 4,
                    child: IconButton(icon: const Icon(Icons.clear), onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    }),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _usersStream,
              builder: (context, userSnap) {
                final streakByUid = <String, int>{};
                if (userSnap.hasData) {
                  for (final d in userSnap.data!.docs) {
                    streakByUid[d.id] = ((d.data() as Map<String, dynamic>)['streak'] as num?)?.toInt() ?? 0;
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _tasksStream,
                  builder: (context, snap) {
                    Widget content;

                    if (snap.hasError) {
                      content = _MessageState(icon: Icons.error_outline, iconColor: scheme.error, title: 'Something went wrong', subtitle: '${snap.error}');
                    } else if (!snap.hasData) {
                      content = const _MessageState(icon: null, title: 'Loading team progress…', showSpinner: true);
                    } else {
                      final allTasks = snap.data!.docs.map((d) => TaskItem.fromDoc(d)).where((t) => !t.completed).toList();

                      if (allTasks.isEmpty) {
                        content = _MessageState(icon: Icons.celebration_outlined, iconColor: scheme.primary, title: 'All caught up!', subtitle: 'No pending tasks for the team right now.');
                      } else {
                        final visible = _query.isEmpty
                            ? allTasks
                            : allTasks.where((t) => t.title.toLowerCase().contains(_query) || t.subject.toLowerCase().contains(_query) || t.assignedToName.toLowerCase().contains(_query)).toList();

                        if (visible.isEmpty) {
                          content = const _MessageState(icon: Icons.search_off, title: 'No matching tasks');
                        } else {
                          final groups = _groupByDc(visible, streakByUid);
                          content = ListView(
                            key: const ValueKey('team-task-list'),
                            padding: const EdgeInsets.only(bottom: 16),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                                child: Row(
                                  children: [
                                    Expanded(child: _BentoStat(label: 'Pending tasks', value: allTasks.length, icon: Icons.task_alt_rounded, color: scheme.primary)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _BentoStat(label: 'Active members', value: groups.length, icon: Icons.diversity_3_rounded, color: game.accent)),
                                  ],
                                ),
                              ),
                              for (final group in groups) ...[
                                Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: _ProgressHeader(group: group, game: game, scheme: scheme)),
                                for (final task in group.tasks)
                                  TaskCard(task: task, showAssignee: false, key: ValueKey(task.id), onTap: () => showTaskDetailSheet(context, task)),
                              ],
                            ],
                          );
                        }
                      }
                    }

                    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: content);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BentoStat extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _BentoStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TactileSurface(
      color: scheme.surfaceContainerHigh,
      edgeColor: scheme.surfaceContainerHighest,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          AnimatedCounter(value: value, style: AppTheme.display(size: 28, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final _DcGroup group;
  final AppGameColors game;
  final ColorScheme scheme;
  const _ProgressHeader({required this.group, required this.game, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final progress = (group.streak % 7) / 7;
    final daysToBadge = 7 - (group.streak % 7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(group.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))),
            RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: game.accent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: game.accent.withOpacity(0.45), blurRadius: 10, spreadRadius: 0.5)],
                ),
                child: Text('${group.tasks.length} pending', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(end: const Offset(1.04, 1.04), duration: 1200.ms, curve: Curves.easeInOut),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: progress == 0 ? 0.001 : progress, minHeight: 6, backgroundColor: scheme.surfaceContainerHighest, color: game.streak),
        ),
        const SizedBox(height: 4),
        Text(
          group.streak == 0 ? 'Start a streak to earn a badge' : 'Next badge in $daysToBadge day${daysToBadge == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool showSpinner;
  const _MessageState({required this.icon, this.iconColor, required this.title, this.subtitle, this.showSpinner = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner) const CircularProgressIndicator(),
            if (icon != null) Icon(icon, size: 56, color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}