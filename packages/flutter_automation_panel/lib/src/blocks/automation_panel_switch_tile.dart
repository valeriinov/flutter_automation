import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// A row with a title and a switch, for an on-or-off choice.
class AutomationPanelSwitchTile extends StatelessWidget {
  /// Title of the choice.
  final String title;

  /// Hint under the title, missing when the choice needs none.
  final String? subtitle;

  /// Whether the switch is on.
  final bool isOn;

  /// Called with the new state when the tester flips the switch.
  final ValueChanged<bool> onChanged;

  const AutomationPanelSwitchTile({
    required this.title,
    required this.isOn,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final subtitle = this.subtitle;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AutomationPanelTheme.touchTarget,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textStyle(size: 14)),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textStyle(
                      size: 13,
                      color: theme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Switch(value: isOn, onChanged: onChanged),
        ],
      ),
    );
  }
}
