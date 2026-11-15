import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// A card with a title and rows, such as a section of the mock.
class AutomationPanelCard extends StatelessWidget {
  /// Title of the card.
  final String title;

  /// Rows of the card, usually [AutomationPanelCardRow]s.
  final List<Widget> children;

  const AutomationPanelCard({
    required this.title,
    required this.children,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(AutomationPanelTheme.cardRadius),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              title,
              style: theme.textStyle(size: 15, weight: FontWeight.w600),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// {@category Widgets}
///
/// A row of a card: a label, a value, a note and a chevron. The row opens the
/// page or the sheet that edits what it shows.
class AutomationPanelCardRow extends StatelessWidget {
  /// Label on the left.
  final String label;

  /// Value on the right, in the accent color.
  final String? value;

  /// Value of an override, in the override color and before the [note].
  final String? overrideValue;

  /// Quiet note after the value.
  final String? note;

  /// Called when the tester taps the row.
  final VoidCallback? onPressed;

  const AutomationPanelCardRow({
    required this.label,
    this.value,
    this.overrideValue,
    this.note,
    this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final value = this.value;
    final overrideValue = this.overrideValue;
    final note = this.note;

    return InkWell(
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.lineSoft)),
        ),
        child: Row(
          spacing: AutomationPanelTheme.gapSmall,
          children: [
            Expanded(child: Text(label, style: theme.textStyle(size: 14))),
            if (value != null)
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textStyle(
                      size: 14,
                      weight: FontWeight.w500,
                      color: theme.accent,
                    ),
                  ),
                ),
              ),
            if (overrideValue != null)
              Text(
                overrideValue,
                style: theme.textStyle(
                  size: 14,
                  weight: FontWeight.w600,
                  color: theme.danger,
                ),
              ),
            if (note != null)
              Text(
                note,
                style: theme.textStyle(size: 14, color: theme.textSecondary),
              ),
            SizedBox.square(
              dimension: AutomationPanelTheme.touchTarget,
              child: Icon(Icons.chevron_right, color: theme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
