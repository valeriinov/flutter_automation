import 'package:flutter/widgets.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_sheet.dart';
import 'package:flutter_automation_panel/src/mode/automation_mock_mode_tile.dart';
import 'package:flutter_automation_panel/src/mode/automation_mode_controller.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// Shows a ready bottom sheet with the mock mode row, for a project that has no
/// debug menu of its own. The sheet takes the theme of the panel.
///
/// The [context] parameter is a context under a [Navigator].
/// The [controller] parameter is the controller that saves the mode.
/// The [strings] parameter holds the texts of the row and of the sheet, the
/// strings of the nearest panel when missing.
/// Returns when the sheet closes.
Future<void> showAutomationMockModeSheet({
  required BuildContext context,
  required AutomationModeController controller,
  AutomationPanelStrings? strings,
}) {
  final sheetStrings = strings ?? AutomationPanelStrings.of(context);

  return showAutomationPanelSheet<void>(
    context: context,
    builder: (_) {
      return AutomationPanelSheet(
        strings: sheetStrings,
        child: AutomationMockModeTile(
          controller: controller,
          strings: sheetStrings,
        ),
      );
    },
  );
}
