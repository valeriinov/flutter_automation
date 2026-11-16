import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// A row with a radio button, a title and a hint, for a choice that needs
/// words. Under them, a code chip and a restart badge mark the code name of
/// the choice and a choice that restarts the app. The chosen row shows the
/// accent border and a faint accent fill.
class AutomationPanelRadioTile extends StatelessWidget {
  static const _minHeight = 56.0;

  /// Title of the choice.
  final String title;

  /// Hint under the title, missing when the choice needs none.
  final String? subtitle;

  /// Code name of the choice in a chip under the hint, missing when the
  /// choice has none.
  final String? code;

  /// Whether the choice restarts the app, which a badge under the hint says.
  final bool needsRestart;

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
    this.code,
    this.needsRestart = false,
    this.activeColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final active = activeColor ?? theme.accent;
    final subtitle = this.subtitle;
    final code = this.code;
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
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle,
                            style: theme.textStyle(
                              size: 12,
                              color: theme.textSecondary,
                            ),
                          ),
                        ),
                      if (code != null || needsRestart)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AutomationPanelTheme.gapSmall,
                          ),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (code != null) _CodeChip(code: code),
                              if (needsRestart) const _RestartBadge(),
                            ],
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

class _CodeChip extends StatelessWidget {
  final String code;

  const _CodeChip({required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.track,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          code,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textStyle(size: 11, color: theme.textPath, isMono: true),
        ),
      ),
    );
  }
}

class _RestartBadge extends StatelessWidget {
  const _RestartBadge();

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.restartSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(Icons.refresh, size: 12, color: theme.restart),
            Text(
              strings.restartsTheApp,
              style: theme.textStyle(
                size: 11,
                weight: FontWeight.w600,
                color: theme.restartText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
