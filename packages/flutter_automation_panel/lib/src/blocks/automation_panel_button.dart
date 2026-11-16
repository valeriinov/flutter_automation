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
/// A button of the panel. It fills the width of its container, or takes the
/// width of its label in a row, and never clips its label.
class AutomationPanelButton extends StatelessWidget {
  /// Text of the button.
  final String label;

  /// Look of the button.
  final AutomationPanelButtonKind kind;

  /// Called on a tap, `null` for a disabled button.
  final VoidCallback? onPressed;

  /// Icon before the label, missing when the button has none.
  final IconData? leadingIcon;

  /// Icon after the label, missing when the button has none.
  final IconData? trailingIcon;

  const AutomationPanelButton({
    required this.label,
    required this.onPressed,
    this.kind = AutomationPanelButtonKind.secondary,
    this.leadingIcon,
    this.trailingIcon,
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
    final content = _Content(
      label: label,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
    );

    if (isPrimary) {
      return FilledButton(onPressed: onPressed, style: style, child: content);
    }

    return OutlinedButton(onPressed: onPressed, style: style, child: content);
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

class _Content extends StatelessWidget {
  static const _iconSize = 18.0;
  static const _iconGap = 6.0;

  final String label;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  const _Content({
    required this.label,
    required this.leadingIcon,
    required this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final leading = leadingIcon;
    final trailing = trailingIcon;
    final text = Text(label, maxLines: 1, softWrap: false);

    if (leading == null && trailing == null) {
      return text;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: _iconGap,
      children: [
        if (leading != null) Icon(leading, size: _iconSize),
        Flexible(child: text),
        if (trailing != null) Icon(trailing, size: _iconSize),
      ],
    );
  }
}
