import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/streak_status.dart';
import '../models/task_item.dart';
import '../models/team.dart';
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

/// One member's roster row: who they are, their live streak, their role,
/// and whatever pending tasks they hold (possibly none).
class _DcGroup {
  final String uid;
  final String name;
  final TeamRole role;
  final int streak;
  final List<TaskItem> tasks;
  _DcGroup(this.uid, this.name, this.role, this.streak, this.tasks);

  bool get isLeader => role == TeamRole.leader;
}

class _TeamProgressScreenState extends State<TeamProgressScreen> {
  final _fs = FirestoreService();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  bool _focused = false;

  // Resolved once from the current user's profile; the team-scoped streams
  // can't be built until we know which team to scope to.
  String? _teamId;
  Stream<QuerySnapshot>? _membersStream;
  Stream<QuerySnapshot>? _tasksStream;

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

    _fs.myMembership().then((m) {
      if (!mounted) return;
      setState(() {
        _teamId = m.teamId;
        _membersStream = _fs.streamTeamMembers(m.teamId);
        _tasksStream = _fs.streamTeamTasks(m.teamId);
      });
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

  bool _matches(TaskItem t) =>
      t.title.toLowerCase().contains(_query) ||
          t.subject.toLowerCase().contains(_query) ||
          t.assignedToName.toLowerCase().contains(_query);

  /// Builds one group per team member (so people with an empty task list
  /// still appear), attaches their pending tasks sorted by due date, then
  /// orders the roster: me first, then leaders, then by pending count, then
  /// name. When a search is active, a member is kept if their name matches
  /// or they hold a matching task.
  List<_DcGroup> _buildGroups(
      List<TeamMember> members,
      List<TaskItem> tasks,
      Map<String, int> streakByUid,
      String? myId,
      ) {
    final tasksByUid = <String, List<TaskItem>>{};
    for (final t in tasks) {
      tasksByUid.putIfAbsent(t.assignedToUid, () => []).add(t);
    }

    final groups = <_DcGroup>[];
    for (final m in members) {
      final mine = (tasksByUid[m.id] ?? [])..sort((a, b) => a.dueDate.compareTo(b.dueDate));

      if (_query.isNotEmpty) {
        final nameHit = m.name.toLowerCase().contains(_query);
        final visible = nameHit ? mine : mine.where(_matches).toList();
        if (!nameHit && visible.isEmpty) continue; // drop non-matching members
        groups.add(_DcGroup(m.id, m.name, m.role, streakByUid[m.id] ?? 0, visible));
      } else {
        groups.add(_DcGroup(m.id, m.name, m.role, streakByUid[m.id] ?? 0, mine));
      }
    }

    groups.sort((a, b) {
      if (myId != null) {
        final aMine = a.uid == myId;
        final bMine = b.uid == myId;
        if (aMine != bMine) return aMine ? -1 : 1;
      }
      if (a.isLeader != b.isLeader) return a.isLeader ? -1 : 1;
      final byCount = b.tasks.length.compareTo(a.tasks.length);
      return byCount != 0 ? byCount : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return groups;
  }

  /// A member's header + their task cards (or a gentle "no tasks" line).
  /// The current user's block gets a tinted, bordered container so it reads
  /// as distinct; leaders get a gold "In Charge" treatment on the header.
  Widget _buildGroupSection(BuildContext context, _DcGroup group, bool isMe, AppGameColors game, ColorScheme scheme) {
    final block = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _ProgressHeader(group: group, game: game, scheme: scheme, isMe: isMe),
        ),
        if (group.tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 16, color: scheme.onSurfaceVariant.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text('No tasks yet', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant.withOpacity(0.75))),
              ],
            ),
          )
        else
          for (final task in group.tasks)
            TaskCard(task: task, showAssignee: false, stripeByUrgency: true, key: ValueKey(task.id), onTap: () => showTaskDetailSheet(context, task)),
      ],
    );

    if (isMe) {
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

    // Leaders (that aren't me) get a subtle gold-tinted frame so "In Charge"
    // reads at a glance without competing with the "YOU" block.
    if (group.isLeader) {
      return Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        decoration: BoxDecoration(
          color: game.gold.withOpacity(0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: game.gold.withOpacity(0.35), width: 1.2),
        ),
        child: block,
      );
    }

    return block;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final game = Theme.of(context).extension<AppGameColors>()!;
    final myId = _myId;

    // Still resolving which team we belong to.
    if (_teamId == null || _membersStream == null || _tasksStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Team Progress')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Loading your team…')],
          ),
        ),
      );
    }

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
              stream: _membersStream,
              builder: (context, memberSnap) {
                // Roster + live-streak map, derived from the team's user docs.
                final members = <TeamMember>[];
                final streakByUid = <String, int>{};
                if (memberSnap.hasData) {
                  final now = DateTime.now();
                  for (final d in memberSnap.data!.docs) {
                    final m = d.data() as Map<String, dynamic>;
                    final rawName = (m['name'] as String?)?.trim();
                    members.add(TeamMember(
                      id: d.id,
                      name: (rawName != null && rawName.isNotEmpty) ? rawName : d.id,
                      role: roleFromString(m['role'] as String?),
                    ));
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
                  builder: (context, taskSnap) {
                    Widget content;

                    if (memberSnap.hasError || taskSnap.hasError) {
                      content = EmptyState(
                        key: const ValueKey('error'),
                        art: const ErrorArt(),
                        title: 'Something went wrong',
                        subtitle: '${memberSnap.error ?? taskSnap.error}',
                        float: false,
                      );
                    } else if (!memberSnap.hasData || !taskSnap.hasData) {
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
                      final allTasks = taskSnap.data!.docs.map((d) => TaskItem.fromDoc(d)).where((t) => !t.completed).toList();
                      final groups = _buildGroups(members, allTasks, streakByUid, myId);

                      if (members.isEmpty) {
                        content = const EmptyState(
                          key: ValueKey('no-members'),
                          art: AllCaughtUpArt(),
                          title: 'No teammates yet',
                          subtitle: 'Your team roster will appear here as people join.',
                        );
                      } else if (groups.isEmpty) {
                        // Only reachable when a search matches nobody.
                        content = const EmptyState(
                          key: ValueKey('no-match'),
                          art: NoResultsArt(),
                          title: 'No matching tasks',
                          subtitle: 'Try a different name or subject.',
                        );
                      } else {
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
                                  Expanded(child: _BentoStat(label: 'Team members', value: members.length, icon: Icons.diversity_3_rounded, color: game.accent)),
                                ],
                              ),
                            ),
                            for (final group in groups)
                              _buildGroupSection(context, group, myId != null && group.uid == myId, game, scheme),
                          ],
                        );
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
    // Leaders read in gold; the current user in the primary accent; everyone
    // else in the normal on-surface color.
    final nameColor = group.isLeader ? game.gold : (isMe ? scheme.primary : scheme.onSurface);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    group.name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.display(size: isMe ? 20 : 18, color: nameColor),
                  ),
                  if (isMe) _Pill(text: 'YOU', bg: scheme.primary, fg: Colors.white),
                  if (group.isLeader)
                    _Pill(
                      text: 'IN CHARGE',
                      bg: game.gold,
                      fg: Colors.black.withOpacity(0.82),
                      icon: Icons.shield_rounded,
                    ),
                ],
              ),
            ),
            if (group.tasks.isNotEmpty)
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

/// Small rounded label chip (YOU / IN CHARGE).
class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  const _Pill({required this.text, required this.bg, required this.fg, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: fg), const SizedBox(width: 3)],
          Text(text, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}