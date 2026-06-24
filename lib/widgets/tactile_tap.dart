import 'package:flutter/material.dart';

/// Wraps anything tappable with a gentle press-down shrink + bounce-back
/// release — the small physical detail that makes tactile UI read as
/// premium instead of flat. Use this around every tap target.
class TactileTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const TactileTap({super.key, required this.child, this.onTap, this.pressedScale = 0.95});

  @override
  State<TactileTap> createState() => _TactileTapState();
}

class _TactileTapState extends State<TactileTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}