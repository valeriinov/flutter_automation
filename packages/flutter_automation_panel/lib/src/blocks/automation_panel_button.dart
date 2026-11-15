import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// How a button looks: the main action, a second action or a destructive one.
enum AutomationPanelButtonKind {
  /// Filled with the accent, 52 high.
  primary,

  /// Outlined, 48 high.
  secondary,

  /// Outlined in the override color, 48 high.
  danger,
}

/// {@category Widgets}
///
/// A button of the panel. It fills the width of its container and never clips
/// its label.
class AutomationPanelButton extends StatelessWidget {
  /// Text of the button.
  final String label;

  /// Look of the button.
  final AutomationPanelButtonKind kind;

  /// Called on a tap, `null` for a disabled button.
  final VoidCallback? onPressed;

  const AutomationPanelButton({
    required this.label,
    required this.onPressed,
    this.kind = AutomationPanelButtonKind.secondary,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final isPrimary = kind == AutomationPanelButtonKind.primary;
    final height = isPrimary
        ? AutomationPanelTheme.primaryButtonHeight
        : AutomationPanelTheme.buttonHeight;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AutomationPanelTheme.buttonRadius),
    );
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      maximumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AutomationPanelTheme.gapMedium),
      ),
      shape: WidgetStatePropertyAll(shape),
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(
        isPrimary ? theme.accent : theme.surface,
      ),
      foregroundColor: WidgetStatePropertyAll(_resolveForeground(theme)),
      side: WidgetStatePropertyAll(_resolveSide(theme)),
      textStyle: WidgetStatePropertyAll(
        theme.textStyle(size: 15, weight: FontWeight.w600),
      ),
    );
    final text = Text(label, maxLines: 1, softWrap: false);

    if (isPrimary) {
      return FilledButton(onPressed: onPressed, style: style, child: text);
    }

    return OutlinedButton(onPressed: onPressed, style: style, child: text);
  }

  Color _resolveForeground(AutomationPanelTheme theme) {
    return switch (kind) {
      AutomationPanelButtonKind.primary => theme.surface,
      AutomationPanelButtonKind.secondary => theme.text,
      AutomationPanelButtonKind.danger => theme.danger,
    };
  }

  BorderSide _resolveSide(AutomationPanelTheme theme) {
    return switch (kind) {
      AutomationPanelButtonKind.primary => BorderSide.none,
      AutomationPanelButtonKind.secondary => BorderSide(
        color: theme.lineStrong,
      ),
      AutomationPanelButtonKind.danger => BorderSide(color: theme.dangerLine),
    };
  }
}
