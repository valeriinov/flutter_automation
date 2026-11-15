import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The capsule that holds the status code of an answer: green below 400, red
/// from 400. Code 0 is red as well.
class AutomationCodeBadge extends StatelessWidget {
  /// Status code to show.
  final int code;

  const AutomationCodeBadge({required this.code, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final isError = code >= 400 || code == 0;

    return Container(
      constraints: const BoxConstraints(minWidth: 30),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: isError ? theme.dangerSoft : theme.successSoft,
      ),
      child: Text(
        '$code',
        textAlign: TextAlign.center,
        style: theme.textStyle(
          size: 12,
          weight: FontWeight.w600,
          color: isError ? theme.danger : theme.success,
        ),
      ),
    );
  }
}
