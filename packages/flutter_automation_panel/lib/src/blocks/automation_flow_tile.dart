import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// A card row that opens a flow: its title, a line of numbers and a chevron.
class AutomationFlowTile extends StatelessWidget {
  /// Title of the flow.
  final String title;

  /// Line under the title, such as the count of outcomes and steps.
  final String subtitle;

  /// Called when the tester taps the tile.
  final VoidCallback onPressed;

  const AutomationFlowTile({
    required this.title,
    required this.subtitle,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final radius = BorderRadius.circular(AutomationPanelTheme.cardRadius);

    return Material(
      color: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: theme.line),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: RoundedRectangleBorder(borderRadius: radius),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            spacing: AutomationPanelTheme.gapMedium,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textStyle(size: 15, weight: FontWeight.w600),
                    ),
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
              SizedBox.square(
                dimension: AutomationPanelTheme.touchTarget,
                child: Icon(Icons.chevron_right, color: theme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
