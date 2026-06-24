import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../services/firestore_service.dart';
import '../widgets/animated_counter.dart';
import '../widgets/task_card.dart';
import '../widgets/task_detail_sheet.dart';

class TeamProgressScreen extends StatefulWidget {
  const TeamProgressScreen({super.key});

  @override
  State<TeamProgressScreen> createState() => _TeamProgressScreenState();
}

class _DcGroup {
  final String name;
  final List<TaskItem> tasks;
  _DcGroup(this.name, this.tasks);
}

class _TeamProgressScreenState extends State<TeamProgressScreen> {
  final _fs = FirestoreService();
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_DcGroup> _groupByDc(List<TaskItem> tasks) {
    final map = <String, List<TaskItem>>{}; // keyed by stable profile ID
    for (final t in tasks) {
      map.putIfAbsent(t.assignedToUid, () => []).add(t);
    }
    final groups = map.entries.map((e) => _DcGroup(e.value.first.assignedToName, e.value)).toList();
    groups.sort((a, b) {
      final byCount = b.tasks.length.compareTo(a.tasks.length);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Team Progress')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by task, subject, or DC name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.clear), onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                }),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _fs.streamAllTasks(),
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
                        : allTasks.where((t) =>
                    t.title.toLowerCase().contains(_query) ||
                        t.subject.toLowerCase().contains(_query) ||
                        t.assignedToName.toLowerCase().contains(_query)).toList();

                    if (visible.isEmpty) {
                      content = const _MessageState(icon: Icons.search_off, title: 'No matching tasks');
                    } else {
                      final groups = _groupByDc(visible);
                      content = ListView(
                        key: const ValueKey('team-task-list'),
                        padding: const EdgeInsets.only(bottom: 16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                            child: Row(
                              children: [
                                Expanded(child: _StatCard(label: 'Pending tasks', value: allTasks.length, icon: Icons.task_alt, color: scheme.primary)),
                                const SizedBox(width: 12),
                                Expanded(child: _StatCard(label: 'Active members', value: groups.length, icon: Icons.groups_outlined, color: scheme.tertiary)),
                              ],
                            ),
                          ),
                          for (final group in groups) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                              child: Row(
                                children: [
                                  Expanded(child: Text(group.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 24))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
                                    child: Text('${group.tasks.length} pending',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          AnimatedCounter(value: value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
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