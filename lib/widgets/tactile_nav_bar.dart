import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TactileNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const TactileNavItem({required this.icon, required this.activeIcon, required this.label});
}

/// Bottom nav with a solid top border and a Duolingo-style active cell:
/// the selected tab is a raised pill with a thick bottom "lip" that
/// collapses on press, so switching tabs feels tactile. Inactive tabs are
/// flat icons. Opaque so it reads as a bar over the app's gradient.
class TactileNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<TactileNavItem> items;
  const TactileNavBar({super.key, required this.selectedIndex, required this.onSelected, required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outline, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavCell(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatefulWidget {
  final TactileNavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavCell({required this.item, required this.selected, required this.onTap});

  @override
  State<_NavCell> createState() => _NavCellState();
}

class _NavCellState extends State<_NavCell> {
  bool _pressed = false;
  static const double _edge = 4;

  Color _darken(Color c) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness - 0.18).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selected;
    final faceColor = selected ? scheme.primaryContainer : Colors.transparent;
    final edgeColor = selected ? _darken(scheme.primaryContainer) : Colors.transparent;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) {
        setState(() => _pressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          // The lip lives on the bottom at rest and moves to the top on press,
          // so the face shifts down without changing the outer height.
          padding: EdgeInsets.only(
            top: (selected && _pressed) ? _edge : 0,
            bottom: (selected && !_pressed) ? _edge : 0,
          ),
          decoration: BoxDecoration(color: edgeColor, borderRadius: BorderRadius.circular(16)),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: faceColor, borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? widget.item.activeIcon : widget.item.icon, color: fg, size: 22),
                const SizedBox(height: 2),
                Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}