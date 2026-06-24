import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_game_colors.dart';

enum MascotMood {
  idle,        // resting, gentle float
  cheer,       // small win: task complete / freeze saved
  celebrate,   // big win: level up / badge
  goalReached, // daily XP goal met
  proud,       // inbox zero: everything cleared
  grind,       // heavy load: 4+ tasks pending, determined
  dueToday,    // a task is due today and not yet done: nervous
  overdue,     // a task is overdue: frightened
  atRisk,      // streak alive but no progress, evening
  sleepy,      // late night: drowsy, rest nudge
}

/// A fully code-drawn study buddy. Its pose is a pure function of [mood]:
/// task and XP data change the mood, which changes the pose, so it reads
/// as reactive with no transient state to manage. A cheap self-scheduling
/// blink adds life while idle.
class Mascot extends StatefulWidget {
  final MascotMood mood;
  final double size;

  const Mascot({super.key, this.mood = MascotMood.idle, this.size = 96});

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> {
  bool _blink = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  void _scheduleBlink() {
    _t = Timer(Duration(milliseconds: 2600 + math.Random().nextInt(2200)), () async {
      if (!mounted) return;
      setState(() => _blink = true);
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() => _blink = false);
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final game = Theme.of(context).extension<AppGameColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Facial ink must stay dark in BOTH themes: it sits on the always-light
    // sclera and belly. In dark mode scheme.onSurface is near-white, which
    // made the pupils vanish; pin a near-black instead.
    final faceInk = isDark ? const Color(0xFF1E1B2E) : scheme.onSurface;

    Widget art = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _MascotPainter(
          mood: widget.mood,
          blink: _blink && widget.mood == MascotMood.idle, // only blink while calm
          body: scheme.primary,
          belly: Color.lerp(scheme.primary, Colors.white, 0.80)!,
          ink: faceInk,
          cheek: game.streak,
          accent: game.accent,
          spark: game.gold,
          sweat: game.accent,
          error: scheme.error,
        ),
      ),
    );

    // Mood-based idle motion, isolated above so the paint never reruns.
    switch (widget.mood) {
      case MascotMood.celebrate:
      case MascotMood.cheer:
      case MascotMood.goalReached:
        art = art
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 700.ms, curve: Curves.easeInOut);
        break;
      case MascotMood.proud:
        art = art
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(1, 1), end: const Offset(1.03, 1.03), duration: 1500.ms, curve: Curves.easeInOut);
        break;
      case MascotMood.grind:
      // Quick determined bob, like heads-down work.
        art = art
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -3, duration: 480.ms, curve: Curves.easeInOut);
        break;
      case MascotMood.overdue:
      // Fast panic shake.
        art = art
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .rotate(begin: -0.04, end: 0.04, duration: 220.ms, curve: Curves.easeInOut);
        break;
      case MascotMood.dueToday:
      case MascotMood.atRisk:
      // Slow nervous sway.
        art = art
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .rotate(begin: -0.02, end: 0.02, duration: 1400.ms, curve: Curves.easeInOut);
        break;
      case MascotMood.sleepy:
        art = art
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -3, duration: 2600.ms, curve: Curves.easeInOut);
        break;
      case MascotMood.idle:
        art = art
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -4, duration: 1900.ms, curve: Curves.easeInOut);
        break;
    }
    return art;
  }
}

class _MascotPainter extends CustomPainter {
  final MascotMood mood;
  final bool blink;
  final Color body, belly, ink, cheek, accent, spark, sweat, error;

  _MascotPainter({
    required this.mood,
    required this.blink,
    required this.body,
    required this.belly,
    required this.ink,
    required this.cheek,
    required this.accent,
    required this.spark,
    required this.sweat,
    required this.error,
  });

  bool get _happy => mood == MascotMood.cheer || mood == MascotMood.celebrate || mood == MascotMood.goalReached;
  bool get _proud => mood == MascotMood.proud;
  bool get _grind => mood == MascotMood.grind;
  bool get _overdue => mood == MascotMood.overdue;
  bool get _sleepy => mood == MascotMood.sleepy;
  bool get _worried => mood == MascotMood.atRisk || mood == MascotMood.dueToday;
  bool get _showCheeks => _happy || _proud || _sleepy || mood == MascotMood.idle;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;

    // Contact shadow.
    c.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.92), width: w * 0.5, height: h * 0.10),
        Paint()..color = ink.withOpacity(0.10));

    // Feet.
    final bodyPaint = Paint()..color = body..isAntiAlias = true;
    c.drawOval(Rect.fromCenter(center: Offset(w * 0.40, h * 0.90), width: w * 0.16, height: h * 0.09), bodyPaint);
    c.drawOval(Rect.fromCenter(center: Offset(w * 0.60, h * 0.90), width: w * 0.16, height: h * 0.09), bodyPaint);

    _arms(c, w, h);

    // Body + belly.
    c.drawOval(Rect.fromLTWH(w * 0.18, h * 0.16, w * 0.64, h * 0.70), bodyPaint);
    c.drawOval(Rect.fromLTWH(w * 0.31, h * 0.40, w * 0.38, h * 0.40), Paint()..color = belly);

    // Antenna.
    c.drawLine(Offset(w * 0.5, h * 0.17), Offset(w * 0.5, h * 0.07), _stroke(body, w * 0.03));
    c.drawCircle(Offset(w * 0.5, h * 0.05), w * 0.035, Paint()..color = accent);

    if (_grind) _headband(c, w, h);

    if (_showCheeks) {
      final cheekPaint = Paint()..color = cheek.withOpacity(0.45);
      c.drawCircle(Offset(w * 0.34, h * 0.52), w * 0.045, cheekPaint);
      c.drawCircle(Offset(w * 0.66, h * 0.52), w * 0.045, cheekPaint);
    }

    _eyes(c, w, h);
    _brows(c, w, h);
    _mouth(c, w, h);

    if (_happy || _proud) _sparkles(c, w, h);
    if (_grind || _worried) _sweatDrop(c, w, h);
    if (_overdue) {
      _exclaim(c, w, h);
      _sweatDrop(c, w, h);
    }
    if (_sleepy) _zzz(c, w, h);
  }

  void _arms(Canvas c, double w, double h) {
    final fill = Paint()..color = body;
    if (_happy) {
      // Raised in excitement.
      c.drawOval(Rect.fromCenter(center: Offset(w * 0.17, h * 0.34), width: w * 0.16, height: h * 0.10), fill);
      c.drawOval(Rect.fromCenter(center: Offset(w * 0.83, h * 0.34), width: w * 0.16, height: h * 0.10), fill);
    } else {
      c.drawOval(Rect.fromCenter(center: Offset(w * 0.16, h * 0.55), width: w * 0.12, height: h * 0.16), fill);
      c.drawOval(Rect.fromCenter(center: Offset(w * 0.84, h * 0.55), width: w * 0.12, height: h * 0.16), fill);
    }
  }

  void _eyes(Canvas c, double w, double h) {
    final le = Offset(w * 0.41, h * 0.45), re = Offset(w * 0.59, h * 0.45);
    if (_happy || _proud) {
      _happyEye(c, le, w);
      _happyEye(c, re, w);
    } else if (_sleepy) {
      _sleepyEye(c, le, w);
      _sleepyEye(c, re, w);
    } else if (_overdue) {
      _scaredEye(c, le, w);
      _scaredEye(c, re, w);
    } else if (blink) {
      _closedEye(c, le, w);
      _closedEye(c, re, w);
    } else {
      _openEye(c, le, w, worried: _worried);
      _openEye(c, re, w, worried: _worried);
    }
  }

  void _openEye(Canvas c, Offset o, double w, {bool worried = false}) {
    c.drawCircle(o, w * 0.075, Paint()..color = Colors.white);
    final pr = worried ? w * 0.030 : w * 0.042;
    final pc = o.translate(0, worried ? -w * 0.005 : w * 0.012);
    c.drawCircle(pc, pr, Paint()..color = ink);
    c.drawCircle(pc.translate(pr * 0.4, -pr * 0.4), pr * 0.32, Paint()..color = Colors.white);
  }

  void _scaredEye(Canvas c, Offset o, double w) {
    c.drawCircle(o, w * 0.085, Paint()..color = Colors.white);
    c.drawCircle(o, w * 0.085, _stroke(ink, w * 0.012));
    c.drawCircle(o, w * 0.026, Paint()..color = ink); // small pupil = wide-eyed
  }

  void _closedEye(Canvas c, Offset o, double w) {
    c.drawPath(
      Path()
        ..moveTo(o.dx - w * 0.06, o.dy)
        ..quadraticBezierTo(o.dx, o.dy + w * 0.03, o.dx + w * 0.06, o.dy),
      _stroke(ink, w * 0.02),
    );
  }

  void _sleepyEye(Canvas c, Offset o, double w) {
    c.drawPath(
      Path()
        ..moveTo(o.dx - w * 0.06, o.dy)
        ..quadraticBezierTo(o.dx, o.dy + w * 0.018, o.dx + w * 0.06, o.dy),
      _stroke(ink, w * 0.022),
    );
  }

  void _happyEye(Canvas c, Offset o, double w) {
    c.drawPath(
      Path()
        ..moveTo(o.dx - w * 0.06, o.dy + w * 0.02)
        ..quadraticBezierTo(o.dx, o.dy - w * 0.05, o.dx + w * 0.06, o.dy + w * 0.02),
      _stroke(ink, w * 0.024),
    );
  }

  void _brows(Canvas c, double w, double h) {
    final br = _stroke(ink, w * 0.022);
    if (_worried) {
      // Inner ends raised (anxious).
      c.drawLine(Offset(w * 0.34, h * 0.40), Offset(w * 0.45, h * 0.37), br);
      c.drawLine(Offset(w * 0.66, h * 0.40), Offset(w * 0.55, h * 0.37), br);
    } else if (_grind) {
      // Inner ends lowered (determined).
      c.drawLine(Offset(w * 0.34, h * 0.39), Offset(w * 0.46, h * 0.43), br);
      c.drawLine(Offset(w * 0.66, h * 0.39), Offset(w * 0.54, h * 0.43), br);
    } else if (_overdue) {
      // High and arched (alarm).
      c.drawLine(Offset(w * 0.34, h * 0.36), Offset(w * 0.45, h * 0.345), br);
      c.drawLine(Offset(w * 0.66, h * 0.36), Offset(w * 0.55, h * 0.345), br);
    }
  }

  void _mouth(Canvas c, double w, double h) {
    final cx = w * 0.5;
    final p = _stroke(ink, w * 0.024);

    if (_happy) {
      c.drawPath(
        Path()
          ..moveTo(cx - w * 0.10, h * 0.58)
          ..quadraticBezierTo(cx, h * 0.72, cx + w * 0.10, h * 0.58)
          ..close(),
        Paint()..color = ink,
      );
      c.drawCircle(Offset(cx, h * 0.645), w * 0.028, Paint()..color = cheek); // tongue
    } else if (_proud) {
      c.drawPath(
        Path()
          ..moveTo(cx - w * 0.09, h * 0.59)
          ..quadraticBezierTo(cx, h * 0.67, cx + w * 0.09, h * 0.59),
        p,
      );
    } else if (_overdue) {
      c.drawOval(Rect.fromCenter(center: Offset(cx, h * 0.625), width: w * 0.07, height: h * 0.06), Paint()..color = ink);
    } else if (_sleepy) {
      c.drawOval(Rect.fromCenter(center: Offset(cx, h * 0.63), width: w * 0.065, height: h * 0.05), Paint()..color = ink);
    } else if (_grind) {
      c.drawLine(Offset(cx - w * 0.08, h * 0.61), Offset(cx + w * 0.08, h * 0.61), p);
    } else if (_worried) {
      c.drawPath(
        Path()
          ..moveTo(cx - w * 0.07, h * 0.64)
          ..quadraticBezierTo(cx, h * 0.60, cx + w * 0.07, h * 0.64),
        p,
      );
    } else {
      // idle
      c.drawPath(
        Path()
          ..moveTo(cx - w * 0.07, h * 0.60)
          ..quadraticBezierTo(cx, h * 0.66, cx + w * 0.07, h * 0.60),
        p,
      );
    }
  }

  void _headband(Canvas c, double w, double h) {
    final band = Paint()..color = accent;
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.19, h * 0.30, w * 0.62, h * 0.06), Radius.circular(w * 0.02)),
      band,
    );
    c.drawCircle(Offset(w * 0.21, h * 0.33), w * 0.03, band); // knot
    final tail = _stroke(accent, w * 0.02);
    c.drawLine(Offset(w * 0.21, h * 0.33), Offset(w * 0.13, h * 0.36), tail);
    c.drawLine(Offset(w * 0.21, h * 0.345), Offset(w * 0.12, h * 0.41), tail);
  }

  void _sparkles(Canvas c, double w, double h) {
    _spark(c, Offset(w * 0.16, h * 0.18), w * 0.035, spark);
    _spark(c, Offset(w * 0.85, h * 0.22), w * 0.028, accent);
    _spark(c, Offset(w * 0.80, h * 0.55), w * 0.022, spark);
  }

  void _spark(Canvas c, Offset o, double r, Color col) {
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy - r)
        ..quadraticBezierTo(o.dx + r * 0.25, o.dy - r * 0.25, o.dx + r, o.dy)
        ..quadraticBezierTo(o.dx + r * 0.25, o.dy + r * 0.25, o.dx, o.dy + r)
        ..quadraticBezierTo(o.dx - r * 0.25, o.dy + r * 0.25, o.dx - r, o.dy)
        ..quadraticBezierTo(o.dx - r * 0.25, o.dy - r * 0.25, o.dx, o.dy - r)
        ..close(),
      Paint()..color = col,
    );
  }

  void _sweatDrop(Canvas c, double w, double h) {
    final o = Offset(w * 0.74, h * 0.40);
    final r = w * 0.03;
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy - r * 1.6)
        ..quadraticBezierTo(o.dx + r, o.dy, o.dx, o.dy + r)
        ..quadraticBezierTo(o.dx - r, o.dy, o.dx, o.dy - r * 1.6)
        ..close(),
      Paint()..color = sweat,
    );
  }

  void _exclaim(Canvas c, double w, double h) {
    final ex = _stroke(error, w * 0.03);
    c.drawLine(Offset(w * 0.81, h * 0.15), Offset(w * 0.81, h * 0.23), ex);
    c.drawCircle(Offset(w * 0.81, h * 0.275), w * 0.018, Paint()..color = error);
  }

  void _zzz(Canvas c, double w, double h) {
    _z(c, Offset(w * 0.70, h * 0.20), w * 0.05, accent);
    _z(c, Offset(w * 0.79, h * 0.12), w * 0.065, accent);
    _z(c, Offset(w * 0.89, h * 0.04), w * 0.08, accent);
  }

  void _z(Canvas c, Offset o, double s, Color col) {
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy)
        ..lineTo(o.dx + s, o.dy)
        ..lineTo(o.dx, o.dy + s)
        ..lineTo(o.dx + s, o.dy + s),
      _stroke(col, s * 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant _MascotPainter old) =>
      old.mood != mood || old.blink != blink || old.body != body || old.ink != ink;
}