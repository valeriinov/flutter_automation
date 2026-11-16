import 'package:flutter/widgets.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_switch_tile.dart';
import 'package:flutter_automation_panel/src/mode/automation_mode_controller.dart';
import 'package:flutter_automation_panel/src/sheets/automation_confirm_sheet.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// A ready row for the debug menu of a project: a switch that moves the app
/// between the server and the mock.
///
/// The row is an [AutomationPanelSwitchTile], so it takes the theme of the
/// panel that holds it, such as an `AutomationPanelSheet`. A switch first asks
/// the tester to confirm. The controller then sets `isRestartRequired` to true.
class AutomationMockModeTile extends StatelessWidget {
  /// The controller that saves the mode.
  final AutomationModeController controller;

  /// The texts of the row and of its confirmation sheet, the strings of the
  /// nearest panel when missing.
  final AutomationPanelStrings? strings;

  const AutomationMockModeTile({
    required this.controller,
    this.strings,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final strings = this.strings ?? AutomationPanelStrings.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return AutomationPanelSwitchTile(
          title: strings.mockMode,
          subtitle: strings.mockModeNote,
          isOn: controller.nextMode == AutomationMode.mock,
          onChanged: (isOn) => showAutomationRestartSheet(
            context: context,
            strings: strings,
            onConfirmPressed: () => controller.switchTo(
              isOn ? AutomationMode.mock : AutomationMode.server,
            ),
          ),
        );
      },
    );
  }
}
