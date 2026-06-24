import 'package:flutter/material.dart';

/// Duolingo-style "tactile" surface: a solid block with a flat, slightly
/// different-toned strip along the bottom edge instead of a drop shadow —
/// reads as a physical, pressable object rather than a floating card.
class TactileSurface extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color edgeColor;
  final double radius;
  final double edgeThickness;
  final EdgeInsetsGeometry padding;

  const TactileSurface({
    super.key,
    required this.child,
    required this.color,
    required this.edgeColor,
    this.radius = 20,
    this.edgeThickness = 4,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: edgeColor, borderRadius: BorderRadius.circular(radius)),
      padding: EdgeInsets.only(bottom: edgeThickness),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
        child: child,
      ),
    );
  }
}