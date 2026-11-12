import 'package:flutter_automation/automation_target.dart';

/// {@category Utils}
///
/// Elements of the example app that a flow addresses.
///
/// The library imports no Flutter code, so a flow on the host reads the ids.
enum ExampleTarget with AutomationIdComposer {
  loginScreen(AutomationTargetType.screen),
  loginButton(AutomationTargetType.button),
  catalogScreen(AutomationTargetType.screen),
  catalogList(AutomationTargetType.panel),
  catalogItem(AutomationTargetType.tile),
  catalogEmpty(AutomationTargetType.label);

  @override
  final AutomationTargetType type;

  const ExampleTarget(this.type);

  @override
  String get scope => 'example';
}
