import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// A small capital label over a group of rows, such as RESPONSE LATENCY.
///
/// A [detail] follows the label after a dot, in the monospace font.
class AutomationPanelLabel extends StatelessWidget {
  /// The text of the label. The label draws it in capitals.
  final String text;

  /// A request or another detail that follows the text, missing when there is
  /// none.
  final String? detail;

  const AutomationPanelLabel({required this.text, this.detail, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final detail = this.detail;
    final style = theme
        .textStyle(
          size: 11,
          weight: FontWeight.w600,
          color: theme.textSecondary,
        )
        .copyWith(letterSpacing: 0.66);

    if (detail == null) {
      return Text(text.toUpperCase(), style: style);
    }

    return Text.rich(
      TextSpan(
        text: '${text.toUpperCase()} · ',
        children: [
          TextSpan(
            text: detail,
            style: theme.textStyle(
              size: 11,
              weight: FontWeight.w600,
              color: theme.textSecondary,
              isMono: true,
            ),
          ),
        ],
      ),
      style: style,
    );
  }
}
