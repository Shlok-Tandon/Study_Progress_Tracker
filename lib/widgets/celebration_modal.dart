import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_game_colors.dart';
import '../theme/app_theme.dart';
import 'mascot.dart';
import 'tactile_3d.dart';

/// Shows the full-screen celebration modal: confetti shower, a bouncy
/// scale-in entrance, and a giant Tactile3D "CONTINUE" button. Pass
/// [mascotMood] to show the reacting buddy instead of the default icon
/// (used for level-ups, badges, and daily-goal hits).
Future<void> showCelebrationModal(
    BuildContext context, {
      required String title,
      String? subtitle,
      String continueLabel = 'CONTINUE',
      VoidCallback? onContinue,
      String? secondaryLabel,
      VoidCallback? onSecondary,
      MascotMood? mascotMood,
    }) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.55),
    barrierLabel: title,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (context, _, __) => _CelebrationModal(
      title: title,
      subtitle: subtitle,
      continueLabel: continueLabel,
      onContinue: onContinue,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
      mascotMood: mascotMood,
    ),
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
          child: child,
        ),
      );
    },
  );
}

class _ConfettiPiece {
  final double dx;
  final double size;
  final double delay;
  final double driftAmplitude;
  final double driftFrequency;
  final int colorIndex;
  final double rotationSign;

  _ConfettiPiece({
    required this.dx,
    required this.size,
    required this.delay,
    required this.driftAmplitude,
    required this.driftFrequency,
    required this.colorIndex,
    required this.rotationSign,
  });
}

List<_ConfettiPiece> _buildConfetti(int count) {
  final rnd = Random();
  return List.generate(count, (_) {
    return _ConfettiPiece(
      dx: rnd.nextDouble(),
      size: 6 + rnd.nextDouble() * 7,
      delay: rnd.nextDouble() * 0.3,
      driftAmplitude: 10 + rnd.nextDouble() * 18,
      driftFrequency: 2 + rnd.nextDouble() * 3,
      colorIndex: rnd.nextInt(6),
      rotationSign: rnd.nextBool() ? 1 : -1,
    );
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiPiece> pieces;
  final List<Color> colors;

  _ConfettiPainter({required this.progress, required this.pieces, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final local = ((progress - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      final fall = Curves.easeIn.transform(local);
      final x = piece.dx * size.width + sin(local * piece.driftFrequency * pi) * piece.driftAmplitude;
      final y = fall * (size.height + piece.size) - piece.size;
      final opacity = local > 0.85 ? ((1 - local) / 0.15).clamp(0.0, 1.0) : 1.0;

      final paint = Paint()..color = colors[piece.colorIndex % colors.length].withOpacity(opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * piece.rotationSign * 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: piece.size, height: piece.size * 0.5),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}

class _CelebrationModal extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String continueLabel;
  final VoidCallback? onContinue;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final MascotMood? mascotMood;

  const _CelebrationModal({
    required this.title,
    this.subtitle,
    required this.continueLabel,
    this.onContinue,
    this.secondaryLabel,
    this.onSecondary,
    this.mascotMood,
  });

  @override
  State<_CelebrationModal> createState() => _CelebrationModalState();
}

class _CelebrationModalState extends State<_CelebrationModal> with SingleTickerProviderStateMixin {
  late final AnimationController _confetti;
  late final List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
    _pieces = _buildConfetti(36);
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final game = Theme.of(context).extension<AppGameColors>()!;
    final confettiColors = [scheme.primary, scheme.tertiary, game.gold, game.success, game.streak, game.accent];

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _confetti,
                  builder: (context, _) => CustomPaint(
                    painter: _ConfettiPainter(progress: _confetti.value, pieces: _pieces, colors: confettiColors),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Tactile3DCard(
                alignment: Alignment.center,
                radius: 28,
                edgeThickness: 6,
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.mascotMood != null)
                      Mascot(mood: widget.mascotMood!, size: 104)
                    else
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(color: game.success.withOpacity(0.15), shape: BoxShape.circle),
                        child: Icon(Icons.celebration_rounded, color: game.success, size: 46),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: AppTheme.display(size: 26, color: scheme.onSurface),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Tactile3DButton(
                      width: double.infinity,
                      color: game.success,
                      radius: 18,
                      edgeThickness: 6,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onContinue?.call();
                      },
                      child: Text(
                        widget.continueLabel,
                        style: AppTheme.display(size: 18, color: Colors.white).copyWith(letterSpacing: 0.5),
                      ),
                    ),
                    if (widget.secondaryLabel != null) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onSecondary?.call();
                        },
                        child: Text(
                          widget.secondaryLabel!,
                          style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}