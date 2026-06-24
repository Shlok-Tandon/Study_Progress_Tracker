import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_game_colors.dart';

/// Duolingo-style daily goal ring: an animated arc that fills as today's
/// XP climbs toward the goal, with a flame + count in the middle and a
/// success check once the goal is hit. Ring is painted; the centre is
/// plain widgets in a Stack so icons and text stay crisp and themable.
class DailyGoalRing extends StatelessWidget {
  final int value;
  final int goal;
  final double size;

  const DailyGoalRing({super.key, required this.value, required this.goal, this.size = 66});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final game = Theme.of(context).extension<AppGameColors>()!;
    final target = goal <= 0 ? 1 : goal;
    final progress = (value / target).clamp(0.0, 1.0);
    final complete = value >= target;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, p, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(
                  progress: p,
                  track: scheme.surfaceContainerHighest,
                  start: game.streak,
                  end: scheme.primary,
                  stroke: size * 0.11,
                ),
              ),
              if (complete)
                Icon(Icons.check_rounded, color: game.success, size: size * 0.42)
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: game.streak, size: size * 0.24),
                    Text(
                      '$value',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.24, color: scheme.onSurface, height: 1.0),
                    ),
                    Text(
                      '/$goal',
                      style: TextStyle(fontSize: size * 0.13, color: scheme.onSurfaceVariant, height: 1.0),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track, start, end;
  final double stroke;

  _RingPainter({required this.progress, required this.track, required this.start, required this.end, required this.stroke});

  @override
  void paint(Canvas c, Size s) {
    final center = (Offset.zero & s).center;
    final radius = (s.width - stroke) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    c.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [start, end, start],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    c.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.start != start;
}