import 'package:flutter/material.dart';

/// A number that counts up/down to its new value instead of snapping —
/// used by the stat cards on the Team Progress dashboard.
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const AnimatedCounter({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) => Text(animatedValue.round().toString(), style: style),
    );
  }
}