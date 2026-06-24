import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Returns a darker variant of [base] for the "shadow" lip beneath a
/// Tactile3D surface, when the caller doesn't supply one explicitly.
Color _autoShadow(Color base) {
  final hsl = HSLColor.fromColor(base);
  return hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
}

/// Shared Neubrutalist mechanic: a solid colored "face" sitting on a
/// darker "shadow" base, with a thick bottom lip in its resting state.
/// On press, the lip shrinks to 0 and the face shifts down by the same
/// amount — done by animating top/bottom padding in lockstep (so the
/// outer bounding box height never changes, meaning no layout jump for
/// surrounding widgets while the button is held down).
///
/// IMPORTANT: both the outer (shadow) and inner (face) layers share the
/// exact same [width]/[height]. They must always match — if the inner
/// layer is given a different size hint than the outer (e.g. forcing it
/// to double.infinity while the outer stays fixed), the face can end up
/// sized independently of the shadow base, which is exactly the bug that
/// made a FAB's colored face stretch across the screen while its shadow
/// stayed a correctly-sized circle underneath.
class _Tactile3DSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color shadowColor;
  final double radius;
  final double edgeThickness;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;
  final double? width;
  final double? height;
  final bool enableHaptics;

  const _Tactile3DSurface({
    required this.child,
    required this.color,
    required this.shadowColor,
    required this.radius,
    required this.edgeThickness,
    required this.padding,
    required this.alignment,
    this.onTap,
    this.width,
    this.height,
    this.enableHaptics = true,
  });

  @override
  State<_Tactile3DSurface> createState() => _Tactile3DSurfaceState();
}

class _Tactile3DSurfaceState extends State<_Tactile3DSurface> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final surface = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      width: widget.width,
      height: widget.height,
      padding: EdgeInsets.only(
        top: _pressed ? widget.edgeThickness : 0,
        bottom: _pressed ? 0 : widget.edgeThickness,
      ),
      decoration: BoxDecoration(
        color: widget.shadowColor,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        // Matches the outer layer exactly — see the class doc above for
        // why this must never diverge from `widget.width`.
        width: widget.width,
        padding: widget.padding,
        alignment: widget.alignment,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: widget.child,
      ),
    );

    if (widget.onTap == null) return surface; // static — no gesture wrapper at all

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        setState(() => _pressed = true);
        if (widget.enableHaptics) HapticFeedback.lightImpact();
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: surface,
    );
  }
}

/// A Duolingo-style 3D button: a flat colored "clay" face on a darker
/// base, with a thick bottom edge that flattens when pressed. Defaults
/// to [ColorScheme.primary]; pass [color] for any other tone.
///
/// Pass [width]/[height] for a fixed-size button (e.g. a circular FAB);
/// leave both null to shrink-wrap to content; pass `width: double.infinity`
/// for a button that fills its parent's available width (only valid
/// inside an ancestor that actually bounds that width, e.g. a Card or
/// Padding with a finite max-width — never inside something unbounded
/// like a bare FloatingActionButton slot).
class Tactile3DButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Color? shadowColor;
  final double radius;
  final double edgeThickness;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final bool enableHaptics;

  const Tactile3DButton({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.shadowColor,
    this.radius = 18,
    this.edgeThickness = 4,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
    this.width,
    this.height,
    this.enableHaptics = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final face = color ?? scheme.primary;
    final surface = _Tactile3DSurface(
      onTap: onTap,
      color: face,
      shadowColor: shadowColor ?? _autoShadow(face),
      radius: radius,
      edgeThickness: edgeThickness,
      padding: padding,
      alignment: Alignment.center,
      width: width,
      height: height,
      enableHaptics: enableHaptics,
      child: child,
    );
    // A button with no onTap reads as disabled — dim it. (A card with no
    // onTap is just a normal static card, so Tactile3DCard skips this.)
    return onTap == null ? Opacity(opacity: 0.5, child: surface) : surface;
  }
}

/// The same Neubrutalist surface, styled for content blocks rather than
/// actions: left-aligned by default, optional [onTap] (omit it for a
/// purely static card — no gesture wrapper is attached at all in that
/// case, so it never intercepts touches it doesn't need).
class Tactile3DCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Color? shadowColor;
  final double radius;
  final double edgeThickness;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;
  final double? width;
  final double? height;
  final bool enableHaptics;

  const Tactile3DCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.shadowColor,
    this.radius = 20,
    this.edgeThickness = 5,
    this.padding = const EdgeInsets.all(16),
    this.alignment = Alignment.topLeft,
    this.width,
    this.height,
    this.enableHaptics = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final face = color ?? scheme.surfaceContainerHigh;
    return _Tactile3DSurface(
      onTap: onTap,
      color: face,
      shadowColor: shadowColor ?? _autoShadow(face),
      radius: radius,
      edgeThickness: edgeThickness,
      padding: padding,
      alignment: alignment,
      width: width,
      height: height,
      enableHaptics: enableHaptics,
      child: child,
    );
  }
}