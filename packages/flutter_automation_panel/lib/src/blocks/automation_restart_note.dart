import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// A note with a restart icon that tells the tester the app restarts.
class AutomationRestartNote extends StatelessWidget {
  /// What the restart does, in one or two sentences.
  final String text;

  const AutomationRestartNote({required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AutomationPanelTheme.gapMedium,
        vertical: AutomationPanelTheme.gapSmall,
      ),
      decoration: BoxDecoration(
        color: theme.restartSoft,
        borderRadius: BorderRadius.circular(AutomationPanelTheme.buttonRadius),
      ),
      child: Row(
        spacing: AutomationPanelTheme.gapSmall,
        children: [
          Icon(Icons.refresh, size: 20, color: theme.restart),
          Expanded(
            child: Text(
              text,
              style: theme.textStyle(size: 13, color: theme.restartText),
            ),
          ),
        ],
      ),
    );
  }
}
