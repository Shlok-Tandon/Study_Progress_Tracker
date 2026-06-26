import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_game_colors.dart';

/// A reusable empty / first-run / error state: a code-drawn illustration
/// with a gentle idle float, a title, an optional subtitle, and an
/// optional action. Pass [float] = false for error states (a bobbing
/// error reads as playful when it shouldn't).
class EmptyState extends StatelessWidget {
  final Widget art;
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool float;

  const EmptyState({
    super.key,
    required this.art,
    required this.title,
    this.subtitle,
    this.action,
    this.float = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget illustration = RepaintBoundary(child: art);
    if (float) {
      // Looping bob, isolated in its own RepaintBoundary above so the
      // CustomPaint never repaints while the transform animates.
      illustration = illustration
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: 0, end: -8, duration: 1800.ms, curve: Curves.easeInOut);
    }

    final column = Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          illustration,
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ),
    );

    // Center when there's vertical room; scroll instead of overflowing when
    // the height is squeezed. This happens on the empty Tasks screen: opening
    // the Add-Task dialog raises the keyboard, whose inset shrinks the body
    // sitting behind the dialog. A bare Center can't yield, so the column
    // overflowed (~35px). LayoutBuilder + a min-height ConstrainedBox inside a
    // SingleChildScrollView keeps it centered normally and lets it scroll when
    // space runs short. Every caller gives this a bounded height (it always
    // sits in a Scaffold body or an Expanded), so maxHeight is finite.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: column),
          ),
        );
      },
    )
        .animate()
        .fadeIn(duration: 350.ms, curve: Curves.easeOut)
        .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1), duration: 350.ms, curve: Curves.easeOutBack);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Illustrations
// ─────────────────────────────────────────────────────────────────────

/// Theme-resolved colors handed to each painter (painters can't read
/// BuildContext, so we resolve once in the widget and pass them down).
class _Palette {
  final Color primary, accent, success, streak, gold, silver, bronze, surface, line, faint, error;
  const _Palette({
    required this.primary,
    required this.accent,
    required this.success,
    required this.streak,
    required this.gold,
    required this.silver,
    required this.bronze,
    required this.surface,
    required this.line,
    required this.faint,
    required this.error,
  });

  factory _Palette.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final game = Theme.of(context).extension<AppGameColors>()!;
    return _Palette(
      primary: scheme.primary,
      accent: game.accent,
      success: game.success,
      streak: game.streak,
      gold: game.gold,
      silver: game.silver,
      bronze: game.bronze,
      surface: scheme.surfaceContainerHigh, // reads as a card in both themes
      line: scheme.onSurfaceVariant,
      faint: scheme.primary.withOpacity(0.10),
      error: scheme.error,
    );
  }
}

// Shared draw helpers ---------------------------------------------------

void _rrect(Canvas c, Rect rect, double radius, Paint paint) {
  c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), paint);
}

void _check(Canvas c, Offset center, double size, Color color, double stroke) {
  final p = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final path = Path()
    ..moveTo(center.dx - size * 0.50, center.dy + size * 0.05)
    ..lineTo(center.dx - size * 0.12, center.dy + size * 0.42)
    ..lineTo(center.dx + size * 0.55, center.dy - size * 0.45);
  c.drawPath(path, p);
}

void _sparkle(Canvas c, Offset o, double r, Color color) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;
  final path = Path()
    ..moveTo(o.dx, o.dy - r)
    ..quadraticBezierTo(o.dx + r * 0.22, o.dy - r * 0.22, o.dx + r, o.dy)
    ..quadraticBezierTo(o.dx + r * 0.22, o.dy + r * 0.22, o.dx, o.dy + r)
    ..quadraticBezierTo(o.dx - r * 0.22, o.dy + r * 0.22, o.dx - r, o.dy)
    ..quadraticBezierTo(o.dx - r * 0.22, o.dy - r * 0.22, o.dx, o.dy - r)
    ..close();
  c.drawPath(path, paint);
}

// Empty tasks (clipboard) ----------------------------------------------

class EmptyTasksArt extends StatelessWidget {
  final double size;
  const EmptyTasksArt({super.key, this.size = 150});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _TasksPainter(_Palette.of(context)));
}

class _TasksPainter extends CustomPainter {
  final _Palette p;
  _TasksPainter(this.p);

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;

    c.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.44, Paint()..color = p.faint);

    final board = Rect.fromLTRB(w * 0.28, h * 0.20, w * 0.72, h * 0.86);
    _rrect(c, board, w * 0.06, Paint()..color = p.surface);
    _rrect(
      c,
      board,
      w * 0.06,
      Paint()
        ..color = p.line.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.016,
    );

    final clip = Rect.fromCenter(center: Offset(w * 0.5, h * 0.205), width: w * 0.20, height: h * 0.07);
    _rrect(c, clip, w * 0.03, Paint()..color = p.primary);

    for (int i = 0; i < 3; i++) {
      final y = h * (0.40 + i * 0.15);
      final box = Rect.fromCenter(center: Offset(w * 0.39, y), width: w * 0.09, height: w * 0.09);
      if (i == 0) {
        _rrect(c, box, w * 0.02, Paint()..color = p.success);
        _check(c, box.center, w * 0.075, Colors.white, w * 0.014);
      } else {
        _rrect(
          c,
          box,
          w * 0.02,
          Paint()
            ..color = p.line.withOpacity(0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.014,
        );
      }
      final lineRight = i == 0 ? w * 0.58 : (i == 1 ? w * 0.64 : w * 0.60);
      final line = Rect.fromLTRB(w * 0.48, y - w * 0.014, lineRight, y + w * 0.014);
      _rrect(c, line, w * 0.014, Paint()..color = p.line.withOpacity(i == 0 ? 0.30 : 0.45));
    }

    final badge = Offset(w * 0.73, h * 0.29);
    c.drawCircle(badge, w * 0.105, Paint()..color = p.surface); // halo separates from board
    c.drawCircle(badge, w * 0.092, Paint()..color = p.primary);
    final plus = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(badge.dx - w * 0.04, badge.dy), Offset(badge.dx + w * 0.04, badge.dy), plus);
    c.drawLine(Offset(badge.dx, badge.dy - w * 0.04), Offset(badge.dx, badge.dy + w * 0.04), plus);

    _sparkle(c, Offset(w * 0.20, h * 0.32), w * 0.035, p.accent);
    _sparkle(c, Offset(w * 0.80, h * 0.66), w * 0.028, p.gold);
  }

  @override
  bool shouldRepaint(covariant _TasksPainter old) => old.p.primary != p.primary || old.p.surface != p.surface;
}

// All caught up (check burst) ------------------------------------------

class AllCaughtUpArt extends StatelessWidget {
  final double size;
  const AllCaughtUpArt({super.key, this.size = 150});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CaughtUpPainter(_Palette.of(context)));
}

class _CaughtUpPainter extends CustomPainter {
  final _Palette p;
  _CaughtUpPainter(this.p);

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final center = Offset(w * 0.5, h * 0.5);

    c.drawCircle(center, w * 0.46, Paint()..color = p.faint);

    final ray = Paint()
      ..color = p.success.withOpacity(0.55)
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final a = (i / 8) * 2 * math.pi - math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      c.drawLine(center + dir * (w * 0.34), center + dir * (w * 0.42), ray);
    }

    c.drawCircle(center, w * 0.26, Paint()..color = p.success.withOpacity(0.16));
    c.drawCircle(
      center,
      w * 0.26,
      Paint()
        ..color = p.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02,
    );
    _check(c, center, w * 0.34, p.success, w * 0.05);

    _sparkle(c, Offset(w * 0.78, h * 0.26), w * 0.04, p.gold);
    _sparkle(c, Offset(w * 0.22, h * 0.30), w * 0.03, p.accent);
    _sparkle(c, Offset(w * 0.74, h * 0.74), w * 0.026, p.streak);
  }

  @override
  bool shouldRepaint(covariant _CaughtUpPainter old) => old.p.primary != p.primary || old.p.surface != p.surface;
}

// No results (magnifier) -----------------------------------------------

class NoResultsArt extends StatelessWidget {
  final double size;
  const NoResultsArt({super.key, this.size = 150});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _NoResultsPainter(_Palette.of(context)));
}

class _NoResultsPainter extends CustomPainter {
  final _Palette p;
  _NoResultsPainter(this.p);

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.46, Paint()..color = p.faint);

    final ph = Paint()..color = p.line.withOpacity(0.22);
    _rrect(c, Rect.fromLTWH(w * 0.30, h * 0.30, w * 0.34, h * 0.045), w * 0.02, ph);
    _rrect(c, Rect.fromLTWH(w * 0.30, h * 0.41, w * 0.26, h * 0.045), w * 0.02, ph);

    final lens = Offset(w * 0.45, h * 0.46);
    final r = w * 0.19;
    c.drawCircle(lens, r, Paint()..color = p.surface.withOpacity(0.65));
    c.drawCircle(
      lens,
      r,
      Paint()
        ..color = p.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045,
    );

    final dash = Paint()
      ..color = p.line.withOpacity(0.45)
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(lens.dx - w * 0.05, lens.dy), Offset(lens.dx + w * 0.05, lens.dy), dash);

    final handle = Paint()
      ..color = p.primary
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round;
    final start = lens + Offset(math.cos(math.pi / 4), math.sin(math.pi / 4)) * r;
    c.drawLine(start, start + Offset(w * 0.13, h * 0.13), handle);

    _sparkle(c, Offset(w * 0.74, h * 0.28), w * 0.03, p.accent);
  }

  @override
  bool shouldRepaint(covariant _NoResultsPainter old) => old.p.primary != p.primary || old.p.surface != p.surface;
}

// Empty leaderboard (podium + trophy) ----------------------------------

class EmptyLeaderboardArt extends StatelessWidget {
  final double size;
  const EmptyLeaderboardArt({super.key, this.size = 150});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LeaderboardPainter(_Palette.of(context)));
}

class _LeaderboardPainter extends CustomPainter {
  final _Palette p;
  _LeaderboardPainter(this.p);

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawCircle(Offset(w * 0.5, h * 0.46), w * 0.46, Paint()..color = p.faint);

    void block(Rect r, Color col) {
      final rr = RRect.fromRectAndCorners(
        r,
        topLeft: Radius.circular(w * 0.03),
        topRight: Radius.circular(w * 0.03),
      );
      c.drawRRect(rr, Paint()..color = col.withOpacity(0.85));
    }

    final center = Rect.fromLTWH(w * 0.39, h * 0.52, w * 0.22, h * 0.34);
    block(Rect.fromLTWH(w * 0.17, h * 0.62, w * 0.20, h * 0.24), p.silver);
    block(Rect.fromLTWH(w * 0.63, h * 0.66, w * 0.20, h * 0.20), p.bronze);
    block(center, p.gold);

    // Trophy on the center block.
    final cx = center.center.dx;
    final cupTop = h * 0.30;
    final rw = w * 0.10;
    final cupH = h * 0.13;
    final gold = Paint()..color = p.gold;
    final bowl = Path()
      ..moveTo(cx - rw, cupTop)
      ..lineTo(cx + rw, cupTop)
      ..quadraticBezierTo(cx + rw, cupTop + cupH * 0.95, cx, cupTop + cupH)
      ..quadraticBezierTo(cx - rw, cupTop + cupH * 0.95, cx - rw, cupTop)
      ..close();
    c.drawPath(bowl, gold);

    final handle = Paint()
      ..color = p.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    c.drawArc(Rect.fromCenter(center: Offset(cx - rw, cupTop + cupH * 0.25), width: w * 0.10, height: h * 0.10),
        -math.pi * 0.5, math.pi, false, handle);
    c.drawArc(Rect.fromCenter(center: Offset(cx + rw, cupTop + cupH * 0.25), width: w * 0.10, height: h * 0.10),
        math.pi * 0.5, -math.pi, false, handle);

    _rrect(c, Rect.fromCenter(center: Offset(cx, cupTop + cupH + h * 0.03), width: w * 0.04, height: h * 0.06), w * 0.01, gold);
    _rrect(c, Rect.fromCenter(center: Offset(cx, cupTop + cupH + h * 0.075), width: w * 0.16, height: h * 0.025), w * 0.012, gold);

    _sparkle(c, Offset(cx, cupTop + cupH * 0.45), w * 0.04, Colors.white.withOpacity(0.85));
    _sparkle(c, Offset(w * 0.74, h * 0.28), w * 0.035, p.accent);
    _sparkle(c, Offset(w * 0.24, h * 0.34), w * 0.03, p.primary);
  }

  @override
  bool shouldRepaint(covariant _LeaderboardPainter old) =>
      old.p.primary != p.primary || old.p.surface != p.surface;
}

// Error (cloud off) -----------------------------------------------------

class ErrorArt extends StatelessWidget {
  final double size;
  const ErrorArt({super.key, this.size = 150});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _ErrorPainter(_Palette.of(context)));
}

class _ErrorPainter extends CustomPainter {
  final _Palette p;
  _ErrorPainter(this.p);

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.44, Paint()..color = p.faint);

    final fill = Paint()..color = p.line.withOpacity(0.18);
    _rrect(c, Rect.fromLTWH(w * 0.28, h * 0.46, w * 0.44, h * 0.16), h * 0.08, fill);
    c.drawCircle(Offset(w * 0.40, h * 0.46), w * 0.11, fill);
    c.drawCircle(Offset(w * 0.55, h * 0.41), w * 0.13, fill);
    c.drawCircle(Offset(w * 0.64, h * 0.48), w * 0.09, fill);

    final slash = Paint()
      ..color = p.error
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(w * 0.35, h * 0.37), Offset(w * 0.65, h * 0.63), slash);

    _sparkle(c, Offset(w * 0.74, h * 0.30), w * 0.03, p.accent);
  }

  @override
  bool shouldRepaint(covariant _ErrorPainter old) => old.p.error != p.error || old.p.surface != p.surface;
}