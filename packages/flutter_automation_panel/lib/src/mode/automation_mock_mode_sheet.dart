import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/mode/automation_mock_mode_tile.dart';
import 'package:flutter_automation_panel/src/mode/automation_mode_controller.dart';

/// {@category Widgets}
///
/// Shows a ready bottom sheet with the mock mode row, for a project that has no
/// debug menu of its own. The sheet takes the theme of the app.
///
/// The [context] parameter is a context under a [Navigator].
/// The [controller] parameter is the controller that saves the mode.
/// Returns when the sheet closes.
Future<void> showAutomationMockModeSheet({
  required BuildContext context,
  required AutomationModeController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) {
      return SafeArea(child: AutomationMockModeTile(controller: controller));
    },
  );
}
