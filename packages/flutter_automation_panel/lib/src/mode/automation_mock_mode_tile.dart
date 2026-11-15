import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/mode/automation_mode_controller.dart';

/// {@category Widgets}
///
/// A ready row for the debug menu of a project: a switch that moves the app
/// between the server and the mock.
///
/// The row takes the theme of the menu that holds it. A switch asks the
/// project to restart the app.
class AutomationMockModeTile extends StatelessWidget {
  /// The controller that saves the mode.
  final AutomationModeController controller;

  const AutomationMockModeTile({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SwitchListTile(
          title: const Text('Mock mode'),
          subtitle: const Text('The app restarts when you switch'),
          value: controller.nextMode == AutomationMode.mock,
          onChanged: (isOn) => controller.switchTo(
            isOn ? AutomationMode.mock : AutomationMode.server,
          ),
        );
      },
    );
  }
}
