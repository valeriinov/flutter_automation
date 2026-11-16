import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button_group.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_sheet.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_changes.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The sheet that asks the tester to confirm an action that removes settings
/// or records, such as a reset of the mock or a clear of the log, or an action
/// that restarts the app.
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

  /// The texts of the sheet, the strings of the nearest panel when missing.
  final AutomationPanelStrings? strings;

  const AutomationConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirmPressed,
    this.strings,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final strings = this.strings ?? AutomationPanelStrings.of(context);

    return AutomationPanelSheet(
      title: title,
      strings: strings,
      onClose: () => Navigator.of(context).pop(),
      footer: AutomationPanelButtonGroup(
        buttons: [
          AutomationPanelButton(
            label: strings.cancel,
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
/// The [title], [message], [confirmLabel], [onConfirmPressed] and [strings]
/// parameters are those of the sheet.
Future<void> showAutomationConfirmSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required VoidCallback onConfirmPressed,
  AutomationPanelStrings? strings,
}) {
  final sheetStrings = strings ?? AutomationPanelStrings.of(context);

  return showAutomationPanelSheet<void>(
    context: context,
    builder: (_) => AutomationConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      onConfirmPressed: onConfirmPressed,
      strings: sheetStrings,
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
  final strings = controller.definition.strings;
  final count = AutomationPanelChanges.read(controller).count;
  final restarts = controller.requiresRestart(const {});

  return showAutomationConfirmSheet(
    context: context,
    title: count == 0
        ? strings.resetQuestion
        : strings.resetChangesQuestion(strings.changeCount(count)),
    message: restarts
        ? '${strings.resetMessage} '
              '${strings.appRestarts}'
        : strings.resetMessage,
    confirmLabel: strings.reset,
    onConfirmPressed: () => _reset(controller, onReset),
    strings: strings,
  );
}

/// {@category Widgets}
///
/// Shows the sheet that asks the tester to apply a change that only a restart
/// of the app applies.
///
/// The [onConfirmPressed] parameter applies the change. The [strings]
/// parameter holds the texts of the sheet, the strings of the nearest panel
/// when missing.
Future<void> showAutomationRestartSheet({
  required BuildContext context,
  required VoidCallback onConfirmPressed,
  AutomationPanelStrings? strings,
}) {
  final sheetStrings = strings ?? AutomationPanelStrings.of(context);

  return showAutomationConfirmSheet(
    context: context,
    title: sheetStrings.restartQuestion,
    message: sheetStrings.restartMessage,
    confirmLabel: sheetStrings.apply,
    onConfirmPressed: onConfirmPressed,
    strings: sheetStrings,
  );
}

/// {@category Widgets}
///
/// Replaces the scenario of [controller] with [scenario]. When the new
/// scenario restarts the app, a [showAutomationRestartSheet] asks the tester
/// first, and Cancel keeps the scenario.
///
/// The [onApplied] parameter is called before the scenario changes, such as
/// to close the sheet the tester chose from.
Future<void> applyAutomationScenario({
  required BuildContext context,
  required AutomationPanelController controller,
  required MockScenario scenario,
  VoidCallback? onApplied,
}) async {
  if (!controller.needsRestartFor(scenario)) {
    return _apply(controller, scenario, onApplied);
  }

  return showAutomationRestartSheet(
    context: context,
    onConfirmPressed: () => _apply(controller, scenario, onApplied),
  );
}

Future<void> _reset(
  AutomationPanelController controller,
  VoidCallback? onReset,
) async {
  await controller.reset();

  onReset?.call();
}

Future<void> _apply(
  AutomationPanelController controller,
  MockScenario scenario,
  VoidCallback? onApplied,
) async {
  onApplied?.call();

  await controller.updateScenario(scenario);
}
