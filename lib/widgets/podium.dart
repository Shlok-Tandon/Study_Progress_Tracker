import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_game_colors.dart';
import '../theme/app_theme.dart';

class PodiumEntry {
  final String name;
  final int streak;
  const PodiumEntry({required this.name, required this.streak});
}

/// Top-3 podium — only meant to be shown when there are 2+ ranked users.
class Podium extends StatelessWidget {
  final List<PodiumEntry> top; // ordered 1st..3rd, length 2 or 3
  const Podium({super.key, required this.top});

  @override
  Widget build(BuildContext context) {
    final game = Theme.of(context).extension<AppGameColors>()!;
    final order = top.length == 3 ? [1, 0, 2] : [0, 1]; // visual order: 2nd-1st-3rd

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final i in order)
            if (i < top.length) _PodiumColumn(rank: i + 1, entry: top[i], game: game),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final int rank;
  final PodiumEntry entry;
  final AppGameColors game;
  const _PodiumColumn({required this.rank, required this.entry, required this.game});

  @override
  Widget build(BuildContext context) {
    final color = switch (rank) { 1 => game.gold, 2 => game.silver, _ => game.bronze };
    final height = switch (rank) { 1 => 108.0, 2 => 84.0, _ => 64.0 };
    final initial = entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rank == 1) const Icon(Icons.emoji_events, size: 20, color: Color(0xFFE8A613)),
        const SizedBox(height: 6),
        Container(
          width: rank == 1 ? 64 : 52,
          height: rank == 1 ? 64 : 52,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 3)),
          child: CircleAvatar(
            backgroundColor: color.withOpacity(0.18),
            child: Text(initial, style: AppTheme.display(size: rank == 1 ? 22 : 18, color: color)),
          ),
        ).animate().scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), duration: 420.ms, curve: Curves.elasticOut),
        const SizedBox(height: 8),
        Text(entry.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Container(
          width: 52,
          height: height,
          decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text('#$rank', style: AppTheme.display(size: 16, color: Colors.white)),
        ).animate().slideY(begin: 1, end: 0, duration: 380.ms, curve: Curves.easeOutCubic),
      ],
    );
  }
}