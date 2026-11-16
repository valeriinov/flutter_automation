import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button_group.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_count.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_sheet.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_changes.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The sheet that asks the tester to confirm an action that removes settings
/// or records, such as a reset of the mock or a clear of the log.
///
/// Cancel stands first and the confirm button second, as the platforms place
/// a confirm action. The confirm button closes the sheet and calls
/// [onConfirmPressed]. Cancel and the cross close the sheet only.
class AutomationConfirmSheet extends StatelessWidget {
  /// The question the sheet asks.
  final String title;

  /// What the action removes and what it keeps.
  final String message;

  /// Text of the confirm button.
  final String confirmLabel;

  /// Called after the tester confirms.
  final VoidCallback onConfirmPressed;

  const AutomationConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirmPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return AutomationPanelSheet(
      title: title,
      onClose: () => Navigator.of(context).pop(),
      footer: AutomationPanelButtonGroup(
        buttons: [
          AutomationPanelButton(
            label: AutomationPanelStrings.cancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
          AutomationPanelButton(
            label: confirmLabel,
            kind: AutomationPanelButtonKind.danger,
            onPressed: () => _confirm(context),
          ),
        ],
      ),
      child: Text(
        message,
        style: theme.textStyle(size: 15, color: theme.textSecondary),
      ),
    );
  }

  void _confirm(BuildContext context) {
    Navigator.of(context).pop();
    onConfirmPressed();
  }
}

/// {@category Widgets}
///
/// Shows an [AutomationConfirmSheet] over [context].
///
/// The [title], [message], [confirmLabel] and [onConfirmPressed] parameters
/// are those of the sheet.
Future<void> showAutomationConfirmSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required VoidCallback onConfirmPressed,
}) {
  return showAutomationPanelSheet<void>(
    context: context,
    builder: (_) => AutomationConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      onConfirmPressed: onConfirmPressed,
    ),
  );
}

/// {@category Widgets}
///
/// Shows the sheet that asks the tester to reset the mock of [controller]. The
/// title counts the changes, and the message says when the reset restarts the
/// app.
///
/// The [onReset] parameter is called after the reset, such as to close the
/// page the tester reset from.
Future<void> showAutomationResetSheet({
  required BuildContext context,
  required AutomationPanelController controller,
  VoidCallback? onReset,
}) {
  final count = AutomationPanelChanges.read(controller).count;
  final restarts = controller.requiresRestart(const {});

  return showAutomationConfirmSheet(
    context: context,
    title: count == 0
        ? AutomationPanelStrings.resetQuestion
        : AutomationPanelStrings.resetChangesQuestion(
            describeCount(count, AutomationPanelStrings.changeNoun),
          ),
    message: restarts
        ? '${AutomationPanelStrings.resetMessage} '
              '${AutomationPanelStrings.appRestarts}'
        : AutomationPanelStrings.resetMessage,
    confirmLabel: AutomationPanelStrings.reset,
    onConfirmPressed: () => _reset(controller, onReset),
  );
}

Future<void> _reset(
  AutomationPanelController controller,
  VoidCallback? onReset,
) async {
  await controller.reset();

  onReset?.call();
}
