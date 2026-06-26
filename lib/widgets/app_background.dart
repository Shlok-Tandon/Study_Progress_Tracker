import 'package:flutter/material.dart';
import '../theme/app_game_colors.dart';

/// A subtle full-screen gradient sitting behind every route, so the app is
/// never a flat slab of white or black. Blends a faint wash of primary
/// (top-left) into the base surface and out to accent (bottom-right). It
/// blends over the theme's own surface, so it adapts to light/dark for free
/// and stays light enough to keep text readable.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final game = Theme.of(context).extension<AppGameColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base = scheme.surface;
    final tintTop = Color.alphaBlend(scheme.primary.withOpacity(isDark ? 0.16 : 0.07), base);
    final tintBottom = Color.alphaBlend(game.accent.withOpacity(isDark ? 0.14 : 0.08), base);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tintTop, base, tintBottom],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}