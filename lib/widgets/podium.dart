import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_game_colors.dart';
import '../theme/app_theme.dart';

class PodiumEntry {
  final String name;
  final int streak;
  const PodiumEntry({required this.name, required this.streak});
}

Color _lighten(Color c, [double amt = 0.14]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + amt).clamp(0.0, 1.0)).toColor();
}

Color _darken(Color c, [double amt = 0.12]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - amt).clamp(0.0, 1.0)).toColor();
}

/// Top-3 podium — shown when there are 2+ ranked users.
class Podium extends StatelessWidget {
  final List<PodiumEntry> top; // ordered 1st..3rd, length 2 or 3
  const Podium({super.key, required this.top});

  @override
  Widget build(BuildContext context) {
    final game = Theme.of(context).extension<AppGameColors>()!;
    final order = top.length == 3 ? [1, 0, 2] : [0, 1]; // visual order: 2nd-1st-3rd

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
    final scheme = Theme.of(context).colorScheme;
    final color = switch (rank) { 1 => game.gold, 2 => game.silver, _ => game.bronze };
    final height = switch (rank) { 1 => 116.0, 2 => 88.0, _ => 66.0 };
    final ringSize = rank == 1 ? 70.0 : 56.0;
    final initial = entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rank == 1)
          Icon(Icons.workspace_premium, size: 26, color: color)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.12, 1.12), duration: 1200.ms, curve: Curves.easeInOut),
        const SizedBox(height: 6),
        Container(
          width: ringSize,
          height: ringSize,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [_lighten(color), _darken(color)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: color.withOpacity(0.55), blurRadius: 14, spreadRadius: 1)],
          ),
          child: CircleAvatar(
            backgroundColor: Color.alphaBlend(color.withOpacity(0.20), scheme.surfaceContainerHighest),
            child: Text(initial, style: AppTheme.display(size: rank == 1 ? 24 : 18, color: _darken(color, 0.25))),
          ),
        ).animate().scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), duration: 440.ms, curve: Curves.elasticOut),
        const SizedBox(height: 8),
        SizedBox(
          width: rank == 1 ? 92 : 80,
          child: Text(entry.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department_rounded, size: 13, color: game.streak),
            const SizedBox(width: 2),
            Text('${entry.streak}', style: TextStyle(color: game.streak, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: 60,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_lighten(color, 0.10), color, _darken(color, 0.16)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.45), blurRadius: 16, spreadRadius: 0.5, offset: const Offset(0, 4))],
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          child: Text('#$rank', style: AppTheme.display(size: 18, color: Colors.white)),
        ).animate().slideY(begin: 1, end: 0, duration: 420.ms, curve: Curves.easeOutCubic),
      ],
    );
  }
}