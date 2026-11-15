import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// A group of buttons. Two buttons stand in a row only when both labels hold
/// [maxRowLabelLength] characters or fewer. Otherwise the buttons stand in a
/// column and the first one stays on top.
class AutomationPanelButtonGroup extends StatelessWidget {
  /// Longest label that still lets two buttons share a row.
  static const maxRowLabelLength = 12;

  /// The buttons, the main one first.
  final List<AutomationPanelButton> buttons;

  const AutomationPanelButtonGroup({required this.buttons, super.key});

  @override
  Widget build(BuildContext context) {
    if (_sharesRow) {
      return Row(
        spacing: AutomationPanelTheme.gapSmall,
        children: [for (final button in buttons) Expanded(child: button)],
      );
    }

    return Column(
      spacing: AutomationPanelTheme.gapSmall,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: buttons,
    );
  }

  bool get _sharesRow {
    return buttons.length == 2 &&
        buttons.every((button) => button.label.length <= maxRowLabelLength);
  }
}
