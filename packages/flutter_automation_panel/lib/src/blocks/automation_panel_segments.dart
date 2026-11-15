import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_option.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// A choice of up to four short values, as a segmented control. Each segment
/// is 44 high.
class AutomationPanelSegments<T> extends StatelessWidget {
  static const _trackPadding = 2.0;
  static const _segmentHeight = AutomationPanelTheme.touchTarget;

  /// The values to choose from.
  final List<AutomationPanelOption<T>> options;

  /// The chosen value.
  final T selected;

  /// Called with the value the tester taps.
  final ValueChanged<T> onChanged;

  const AutomationPanelSegments({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: theme.track,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_trackPadding),
        child: Row(
          spacing: _trackPadding,
          children: [
            for (final option in options)
              Expanded(
                child: _Segment(
                  option: option,
                  isSelected: option.value == selected,
                  onPressed: () => onChanged(option.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  final AutomationPanelOption<T> option;
  final bool isSelected;
  final VoidCallback onPressed;

  const _Segment({
    required this.option,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        shadows: isSelected
            ? [
                BoxShadow(
                  color: theme.text.withValues(alpha: 0.12),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Material(
        color: isSelected ? theme.surface : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: AutomationPanelSegments._segmentHeight,
            child: Center(
              child: Text(
                option.label,
                maxLines: 1,
                softWrap: false,
                style: theme.textStyle(
                  size: 14,
                  weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? theme.text : theme.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
