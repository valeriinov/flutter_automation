import 'package:flutter/widgets.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';

/// {@category StateManagement}
///
/// Gives the pages of the panel the [AutomationPanelController] and rebuilds
/// them when it changes.
class AutomationPanelScope
    extends InheritedNotifier<AutomationPanelController> {
  const AutomationPanelScope({
    required AutomationPanelController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// The controller of the nearest panel.
  ///
  /// Throws a [StateError] when [context] has no panel above it.
  static AutomationPanelController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AutomationPanelScope>();
    final controller = scope?.notifier;

    if (controller == null) {
      throw StateError('No AutomationPanelScope above this context.');
    }

    return controller;
  }
}
