import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// A row with a radio button, a title and a hint, for a choice that needs
/// words. The chosen row shows the accent border and a faint accent fill.
class AutomationPanelRadioTile extends StatelessWidget {
  static const _minHeight = 56.0;

  /// Title of the choice.
  final String title;

  /// Hint under the title, missing when the choice needs none.
  final String? subtitle;

  /// Whether the choice is chosen.
  final bool isSelected;

  /// Called when the tester taps the row.
  final VoidCallback onPressed;

  /// Color of the border and the radio button of the chosen row, the accent
  /// when missing.
  final Color? activeColor;

  const AutomationPanelRadioTile({
    required this.title,
    required this.isSelected,
    required this.onPressed,
    this.subtitle,
    this.activeColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final active = activeColor ?? theme.accent;
    final subtitle = this.subtitle;
    final radius = BorderRadius.circular(AutomationPanelTheme.buttonRadius);

    return Material(
      color: isSelected && activeColor == null
          ? theme.accentFaint
          : theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: isSelected ? active : theme.line,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: RoundedRectangleBorder(borderRadius: radius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AutomationPanelTheme.gapMedium,
              vertical: AutomationPanelTheme.gapSmall,
            ),
            child: Row(
              spacing: AutomationPanelTheme.gapMedium,
              children: [
                RadioGroup<bool>(
                  groupValue: isSelected ? true : null,
                  onChanged: (_) => onPressed(),
                  child: Radio<bool>(value: true, activeColor: active),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textStyle(
                          size: 14,
                          weight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: theme.textStyle(
                            size: 12,
                            color: theme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
