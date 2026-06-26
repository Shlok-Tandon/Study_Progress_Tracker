import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/streak_status.dart';
import '../services/firestore_service.dart';
import '../theme/app_game_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/podium.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

/// A leaderboard row's data plus its live (re-derived) streak and badges.
class _LbEntry {
  final Map<String, dynamic> data;
  final int streak;
  final int badges;
  _LbEntry(this.data, this.streak, this.badges);
  String get name => (data['name'] ?? 'User') as String;
}

/// Ring color by rank: gold/silver/bronze for the top 3, then a vibrant
/// rotating palette below so no one is left with a dull grey ring.
Color rankRingColor(int rank, AppGameColors game, ColorScheme scheme) {
  switch (rank) {
    case 1:
      return game.gold;
    case 2:
      return game.silver;
    case 3:
      return game.bronze;
  }
  final palette = [scheme.primary, game.accent, game.success, game.streak];
  return palette[(rank - 4) % palette.length];
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _fs = FirestoreService();
  late final Stream<QuerySnapshot> _stream = _fs.streamLeaderboard(); // cached

  @override
  Widget build(BuildContext context) {
    final game = Theme.of(context).extension<AppGameColors>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Something went wrong: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          if (snap.data!.docs.isEmpty) {
            return const EmptyState(
              art: EmptyLeaderboardArt(),
              title: 'No leaderboard data yet',
              subtitle: 'Complete tasks to start a streak and claim the top spot.',
            );
          }

          // Re-derive each streak as of now, then rank by the live value.
          // Tiebreakers: more badges first, then name A->Z.
          final now = DateTime.now();
          final entries = snap.data!.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final shown = computeStreakStatus(
              storedStreak: (data['streak'] as num?)?.toInt() ?? 0,
              lastCompletedAt: (data['lastCompletedAt'] as Timestamp?)?.toDate(),
              freezeCount: (data['freezeCount'] as num?)?.toInt() ?? 0,
              now: now,
            ).current;
            final badges = (data['badgeCount'] as num?)?.toInt() ?? 0;
            return _LbEntry(data, shown, badges);
          }).toList()
            ..sort((a, b) {
              final byStreak = b.streak.compareTo(a.streak);
              if (byStreak != 0) return byStreak;
              final byBadges = b.badges.compareTo(a.badges);
              if (byBadges != 0) return byBadges;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });

          final hasPodium = entries.length >= 2;
          final podiumCount = hasPodium ? (entries.length >= 3 ? 3 : 2) : 0;
          final podiumEntries = [
            for (var i = 0; i < podiumCount; i++) PodiumEntry(name: entries[i].name, streak: entries[i].streak),
          ];

          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (podiumEntries.isNotEmpty) Podium(top: podiumEntries),
              for (var i = podiumCount; i < entries.length; i++)
                _LeaderboardRow(
                  rank: i + 1,
                  entry: entries[i],
                  game: game,
                  isTopThree: !hasPodium && i < 3,
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
  final _LbEntry entry;
  final AppGameColors game;
  final bool isTopThree;
  const _LeaderboardRow({required this.rank, required this.entry, required this.game, required this.isTopThree});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = entry.name;
    final streak = entry.streak; // live value
    final badges = entry.badges;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final ringColor = rankRingColor(rank, game, scheme);

    Widget card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Vibrant ring: a 2-tone gradient + soft glow, not a flat grey.
            gradient: LinearGradient(
              colors: [ringColor, Color.alphaBlend(Colors.white.withOpacity(0.35), ringColor)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [BoxShadow(color: ringColor.withOpacity(0.35), blurRadius: 8, spreadRadius: 0.5)],
          ),
          padding: const EdgeInsets.all(2.5),
          child: CircleAvatar(
            backgroundColor: Color.alphaBlend(ringColor.withOpacity(0.20), scheme.surfaceContainerHighest),
            child: Text(initial, style: AppTheme.display(size: 16, color: ringColor)),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            RepaintBoundary(
              child: Icon(Icons.local_fire_department_rounded, size: 15, color: game.streak)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(end: const Offset(1.12, 1.12), duration: 700.ms, curve: Curves.easeInOut)
                  .rotate(begin: -0.015, end: 0.015, duration: 700.ms, curve: Curves.easeInOut),
            ),
            const SizedBox(width: 4),
            Text('$streak', style: TextStyle(color: game.streak, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Icon(Icons.military_tech_rounded, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text('$badges'),
          ],
        ),
        trailing: Text('#$rank', style: AppTheme.display(size: 16, color: scheme.onSurfaceVariant)),
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