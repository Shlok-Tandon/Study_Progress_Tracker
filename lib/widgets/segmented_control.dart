import 'package:flutter/material.dart';

/// A sliding-pill segmented control — replaces a plain DropdownButton
/// with something that feels considered. Generic over any value type.
class SegmentedControl<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  const SegmentedControl({super.key, required this.values, required this.labels, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedIndex = values.indexOf(selected);

    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / values.length;
        return Container(
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment(-1 + (2 * selectedIndex / (values.length - 1).clamp(1, 999)), 0),
                child: Container(
                  width: segmentWidth - 6,
                  height: double.infinity,
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(17)),
                ),
              ),
              Row(
                children: List.generate(values.length, (i) {
                  final isSelected = i == selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(values[i]),
                      child: Center(
                        child: Text(
                          labels[i],
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}