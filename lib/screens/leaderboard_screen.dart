import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/firestore_service.dart';
import '../theme/app_game_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/podium.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _fs = FirestoreService();
  late final Stream<QuerySnapshot> _stream = _fs.streamLeaderboard(); // cached

  Future<void> _sendKudos(String profileId, String name) async {
    try {
      await _fs.sendKudos(profileId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('👏 Kudos sent to $name')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send kudos')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final game = Theme.of(context).extension<AppGameColors>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Something went wrong: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 56, color: scheme.primary),
                    const SizedBox(height: 12),
                    Text('No leaderboard data yet', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            );
          }

          final hasPodium = docs.length >= 2;
          final podiumCount = hasPodium ? (docs.length >= 3 ? 3 : 2) : 0;
          final podiumEntries = [
            for (var i = 0; i < podiumCount; i++)
              PodiumEntry(
                name: (docs[i].data() as Map<String, dynamic>)['name'] ?? 'User',
                streak: ((docs[i].data() as Map<String, dynamic>)['streak'] as num?)?.toInt() ?? 0,
              ),
          ];

          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (podiumEntries.isNotEmpty) Podium(top: podiumEntries),
              for (var i = podiumCount; i < docs.length; i++)
                _LeaderboardRow(
                  rank: i + 1,
                  data: docs[i].data() as Map<String, dynamic>,
                  game: game,
                  isTopThree: !hasPodium && i < 3,
                  onKudos: () => _sendKudos(
                    docs[i].id,
                    ((docs[i].data() as Map<String, dynamic>)['name'] ?? 'User') as String,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> data;
  final AppGameColors game;
  final bool isTopThree;
  final VoidCallback onKudos;
  const _LeaderboardRow({required this.rank, required this.data, required this.game, required this.isTopThree, required this.onKudos});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = (data['name'] ?? 'User') as String;
    final streak = (data['streak'] as num?)?.toInt() ?? 0;
    final badges = (data['badgeCount'] as num?)?.toInt() ?? 0;
    final kudos = (data['kudosReceived'] as num?)?.toInt() ?? 0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final ringColor = switch (rank) { 1 => game.gold, 2 => game.silver, 3 => game.bronze, _ => scheme.outlineVariant };

    Widget card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 24, child: Text('$rank', textAlign: TextAlign.center, style: AppTheme.display(size: 16, color: scheme.onSurfaceVariant))),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ringColor, width: 2.5)),
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(radius: 18, backgroundColor: ringColor.withOpacity(0.18), child: Text(initial, style: AppTheme.display(size: 16, color: ringColor))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RepaintBoundary(
                            child: Icon(Icons.local_fire_department_rounded, size: 15, color: game.streak)
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scale(end: const Offset(1.12, 1.12), duration: 700.ms, curve: Curves.easeInOut)
                                .rotate(begin: -0.015, end: 0.015, duration: 700.ms, curve: Curves.easeInOut),
                          ),
                          const SizedBox(width: 4),
                          Text('$streak', style: TextStyle(color: game.streak, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.military_tech_rounded, size: 15, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('$badges', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_emotions_outlined, size: 15, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('$kudos', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_reaction_outlined, color: scheme.primary),
              tooltip: 'Send kudos',
              onPressed: onKudos,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (rank * 40).ms, duration: 260.ms).slideX(begin: 0.04, end: 0, delay: (rank * 40).ms, duration: 260.ms);

    if (isTopThree) {
      card = RepaintBoundary(
        child: card.animate(onPlay: (c) => c.repeat()).shimmer(duration: 1800.ms, delay: 700.ms, color: scheme.primary.withOpacity(0.22)),
      );
    }
    return card;
  }
}