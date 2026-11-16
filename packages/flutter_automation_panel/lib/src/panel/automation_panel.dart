import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_frame.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_sheet.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_status.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_scope.dart';
import 'package:flutter_automation_panel/src/sheets/automation_presets_sheet.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// The root page of the panel: the frame with the status row, the tabs and the
/// page of the chosen tab.
///
/// The panel needs a [Navigator] and an [AutomationPanelScope] above it.
/// `AutomationPanelLauncher` gives both.
class AutomationPanel extends StatefulWidget {
  /// Index of the tab the panel opens on.
  final int initialTab;

  const AutomationPanel({this.initialTab = 0, super.key});

  @override
  State<AutomationPanel> createState() => _AutomationPanelState();
}

class _AutomationPanelState extends State<AutomationPanel> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();

    _selectedTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AutomationPanelScope.of(context);
    final pages = controller.definition.pages;
    final page = pages[_selectedTab];

    return AutomationPanelFrame(
      title: page.label,
      onClose: controller.closePanel,
      status: _describeStatus(context, controller),
      tabs: [for (final page in pages) page.label],
      selectedTab: _selectedTab,
      onTabSelected: (index) => setState(() => _selectedTab = index),
      child: page.builder(context),
    );
  }

  AutomationPanelStatus _describeStatus(
    BuildContext context,
    AutomationPanelController controller,
  ) {
    return AutomationPanelStatus(
      text: controller.outcomeTitle ?? _resolveStateTitle(controller),
      overrideCount: controller.overrideCount,
      isChanged: controller.isChanged,
      actions: [
        AutomationPanelStatusAction(
          label: AutomationPanelStrings.presets,
          onPressed: () => _openPresets(context, controller),
        ),
        if (controller.isChanged)
          AutomationPanelStatusAction(
            label: AutomationPanelStrings.reset,
            onPressed: controller.reset,
          ),
      ],
    );
  }

  String _resolveStateTitle(AutomationPanelController controller) {
    return controller.isChanged
        ? AutomationPanelStrings.customMock
        : AutomationPanelStrings.defaultMock;
  }

  Future<void> _openPresets(
    BuildContext context,
    AutomationPanelController controller,
  ) {
    return showAutomationPanelSheet<void>(
      context: context,
      builder: (sheetContext) {
        return AutomationPresetsSheet(
          controller: controller,
          onClose: () => Navigator.of(sheetContext).pop(),
        );
      },
    );
  }
}
