import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// A row with a title and a switch, for an on-or-off choice.
class AutomationPanelSwitchTile extends StatelessWidget {
  /// Title of the choice.
  final String title;

  /// Whether the switch is on.
  final bool isOn;

  /// Called with the new state when the tester flips the switch.
  final ValueChanged<bool> onChanged;

  const AutomationPanelSwitchTile({
    required this.title,
    required this.isOn,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AutomationPanelTheme.touchTarget,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textStyle(size: 14))),
          Switch(value: isOn, onChanged: onChanged),
        ],
      ),
    );
  }
}
