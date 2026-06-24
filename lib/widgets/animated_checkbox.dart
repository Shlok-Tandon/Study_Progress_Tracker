import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A bouncy custom checkbox for task cards: tapping plays a quick
/// overshoot scale on the whole circle, plus an elastic checkmark pop.
class AnimatedCheckbox extends StatefulWidget {
  final bool checked;
  final Color color;
  final VoidCallback? onTap;

  const AnimatedCheckbox({super.key, required this.checked, required this.color, this.onTap});

  @override
  State<AnimatedCheckbox> createState() => _AnimatedCheckboxState();
}

class _AnimatedCheckboxState extends State<AnimatedCheckbox> {
  int _pulse = 0;

  @override
  void didUpdateWidget(AnimatedCheckbox old) {
    super.didUpdateWidget(old);
    if (old.checked != widget.checked) setState(() => _pulse++);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.checked ? widget.color : Colors.transparent,
          border: Border.all(color: widget.color, width: 2),
        ),
        child: widget.checked
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            .animate(key: ValueKey('check-$_pulse'))
            .scale(begin: const Offset(0.2, 0.2), end: const Offset(1, 1), duration: 280.ms, curve: Curves.elasticOut)
            : const SizedBox.shrink(),
      ),
    )
        .animate(key: ValueKey('bounce-$_pulse'))
        .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 110.ms, curve: Curves.easeOut)
        .then()
        .scale(end: const Offset(1, 1), duration: 160.ms, curve: Curves.easeOut);
  }
}