import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_option.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// A choice of many short values, as a wrapping row of chips 44 high.
///
/// The chosen chip takes [selectedColor]. A dashed last chip, when
/// [customLabel] is set, opens the entry of a value that no chip names.
class AutomationPanelChips<T> extends StatelessWidget {
  static const _chipHeight = 44.0;
  static const _chipMinWidth = 52.0;

  /// The values to choose from.
  final List<AutomationPanelOption<T>> options;

  /// The chosen value, missing when none is chosen.
  final T? selected;

  /// Called with the value the tester taps.
  final ValueChanged<T> onChanged;

  /// Fill of the chosen chip, the accent when missing.
  final Color? selectedColor;

  /// Whether the labels use the monospace font.
  final bool isMono;

  /// Label of the dashed last chip, missing when the row has none.
  final String? customLabel;

  /// Called when the tester taps the dashed chip.
  final VoidCallback? onCustomPressed;

  const AutomationPanelChips({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.selectedColor,
    this.isMono = false,
    this.customLabel,
    this.onCustomPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final fill = selectedColor ?? theme.accent;
    final label = customLabel;

    return Wrap(
      spacing: AutomationPanelTheme.gapSmall,
      runSpacing: AutomationPanelTheme.gapSmall,
      children: [
        for (final option in options)
          _Chip(
            option: option,
            isSelected: option.value == selected,
            fill: fill,
            isMono: isMono,
            onPressed: () => onChanged(option.value),
          ),
        if (label != null)
          _DashedChip(label: label, onPressed: onCustomPressed),
      ],
    );
  }
}

class _Chip<T> extends StatelessWidget {
  final AutomationPanelOption<T> option;
  final bool isSelected;
  final Color fill;
  final bool isMono;
  final VoidCallback onPressed;

  const _Chip({
    required this.option,
    required this.isSelected,
    required this.fill,
    required this.isMono,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Material(
      color: isSelected ? fill : theme.surface,
      shape: StadiumBorder(
        side: BorderSide(color: isSelected ? fill : theme.lineStrong),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AutomationPanelChips._chipHeight,
            minWidth: AutomationPanelChips._chipMinWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              widthFactor: 1,
              child: Text(
                option.label,
                maxLines: 1,
                softWrap: false,
                style: theme.textStyle(
                  size: isMono ? 13 : 14,
                  weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? theme.surface : theme.text,
                  isMono: isMono,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedChip extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _DashedChip({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(color: theme.lineStrong),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: theme.textStyle(size: 14, color: theme.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  static const _dash = 4.0;
  static const _gap = 3.0;

  final Color color;

  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.height / 2),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final metric in path.computeMetrics()) {
      double distance = 0;

      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);

        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
