import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/streak_status.dart';
import '../models/task_item.dart';
import '../services/firestore_service.dart';
import '../theme/app_game_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_counter.dart';
import '../widgets/empty_state.dart';
import '../widgets/tactile_surface.dart';
import '../widgets/task_card.dart';
import '../widgets/task_detail_sheet.dart';

class TeamProgressScreen extends StatefulWidget {
  const TeamProgressScreen({super.key});

  @override
  State<TeamProgressScreen> createState() => _TeamProgressScreenState();
}

class _DcGroup {
  final String uid;
  final String name;
  final int streak;
  final List<TaskItem> tasks;
  _DcGroup(this.uid, this.name, this.streak, this.tasks);
}

class _TeamProgressScreenState extends State<TeamProgressScreen> {
  final _fs = FirestoreService();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  bool _focused = false;

  late final Stream<QuerySnapshot> _usersStream = _fs.streamUsers();
  late final Stream<QuerySnapshot> _tasksStream = _fs.streamAllTasks();

  /// Null if no DC name is set for this session yet (shouldn't normally
  /// happen here, since you can't reach this screen without one, but this
  /// keeps the "pin me to the top" logic from throwing if it ever does).
  String? get _myId {
    try {
      return _fs.myProfileId;
    } catch (_) {
      return null;
    }
  }

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
    _searchFocus.addListener(() => setState(() => _focused = _searchFocus.hasFocus));
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _hintIndex.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Groups tasks by assignee, then sorts so the current user's group is
  /// always first — everyone else follows by task count (most pending
  /// first), then name. That way your own tasks are never buried further
  /// down the list just because a teammate has more open items than you.
  List<_DcGroup> _groupByDc(List<TaskItem> tasks, Map<String, int> streakByUid, String? myId) {
    final map = <String, List<TaskItem>>{};
    for (final t in tasks) {
      map.putIfAbsent(t.assignedToUid, () => []).add(t);
    }
    final groups = map.entries
        .map((e) => _DcGroup(e.key, e.value.first.assignedToName, streakByUid[e.key] ?? 0, e.value))
        .toList();
    groups.sort((a, b) {
      if (myId != null) {
        final aMine = a.uid == myId;
        final bMine = b.uid == myId;
        if (aMine != bMine) return aMine ? -1 : 1;
      }
      final byCount = b.tasks.length.compareTo(a.tasks.length);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });
    return groups;
  }

  /// A group's header + its task cards. The current user's group gets a
  /// tinted, bordered container wrapped around the whole block so it reads
  /// as visually distinct from every other teammate's plain section.
  Widget _buildGroupSection(BuildContext context, _DcGroup group, bool isMe, AppGameColors game, ColorScheme scheme) {
    final block = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _ProgressHeader(group: group, game: game, scheme: scheme, isMe: isMe),
        ),
        for (final task in group.tasks)
          TaskCard(task: task, showAssignee: false, stripeByUrgency: true, key: ValueKey(task.id), onTap: () => showTaskDetailSheet(context, task)),
      ],
    );

    if (!isMe) return block;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withOpacity(0.45), width: 1.4),
      ),
      child: block,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final game = Theme.of(context).extension<AppGameColors>()!;
    final myId = _myId;

    return Scaffold(
      appBar: AppBar(title: const Text('Team Progress')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      colors: _focused
                          ? [game.accent, scheme.primary]
                          : [game.accent.withOpacity(0.55), scheme.primary.withOpacity(0.55)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: RepaintBoundary(
                    child: Container(
                      // Without this, the TextField's own opaque fill paints
                      // as a plain rectangle and its square corners poke out
                      // past this container's rounded edge — clipping to the
                      // decoration's shape is what actually makes the fill
                      // follow the pill border above.
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: scheme.surfaceContainerHigh,
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                        decoration: const InputDecoration(border: InputBorder.none, prefixIcon: Icon(Icons.search)),
                      ),
                    ),
                  ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2600.ms, delay: 400.ms, color: game.accent.withOpacity(0.22)),
                ),
                if (_query.isEmpty)
                  IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 50),
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
                    right: 6,
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
                // Build streak map from the LIVE (re-derived) streak.
                final streakByUid = <String, int>{};
                if (userSnap.hasData) {
                  final now = DateTime.now();
                  for (final d in userSnap.data!.docs) {
                    final m = d.data() as Map<String, dynamic>;
                    streakByUid[d.id] = computeStreakStatus(
                      storedStreak: (m['streak'] as num?)?.toInt() ?? 0,
                      lastCompletedAt: (m['lastCompletedAt'] as Timestamp?)?.toDate(),
                      freezeCount: (m['freezeCount'] as num?)?.toInt() ?? 0,
                      now: now,
                    ).current;
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _tasksStream,
                  builder: (context, snap) {
                    Widget content;

                    if (snap.hasError) {
                      content = EmptyState(
                        key: const ValueKey('error'),
                        art: const ErrorArt(),
                        title: 'Something went wrong',
                        subtitle: '${snap.error}',
                        float: false,
                      );
                    } else if (!snap.hasData) {
                      content = const Center(
                        key: ValueKey('loading'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Loading team progress…'),
                          ],
                        ),
                      );
                    } else {
                      final allTasks = snap.data!.docs.map((d) => TaskItem.fromDoc(d)).where((t) => !t.completed).toList();

                      if (allTasks.isEmpty) {
                        content = const EmptyState(
                          key: ValueKey('caught-up'),
                          art: AllCaughtUpArt(),
                          title: 'All caught up!',
                          subtitle: 'No pending tasks for the team right now.',
                        );
                      } else {
                        final visible = _query.isEmpty
                            ? allTasks
                            : allTasks.where((t) => t.title.toLowerCase().contains(_query) || t.subject.toLowerCase().contains(_query) || t.assignedToName.toLowerCase().contains(_query)).toList();

                        if (visible.isEmpty) {
                          content = const EmptyState(
                            key: ValueKey('no-match'),
                            art: NoResultsArt(),
                            title: 'No matching tasks',
                            subtitle: 'Try a different name or subject.',
                          );
                        } else {
                          final groups = _groupByDc(visible, streakByUid, myId);
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
                              for (final group in groups)
                                _buildGroupSection(context, group, myId != null && group.uid == myId, game, scheme),
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
  final bool isMe;
  const _ProgressHeader({required this.group, required this.game, required this.scheme, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final progress = (group.streak % 7) / 7;
    final daysToBadge = 7 - (group.streak % 7);
    final nameColor = isMe ? scheme.primary : scheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      group.name,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.display(size: isMe ? 20 : 18, color: nameColor),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(20)),
                      child: const Text(
                        'YOU',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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