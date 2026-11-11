import 'package:flutter_automation_runner/src/automation_localized_text.dart';
import 'package:flutter_automation_runner/src/definition/flow_finder.dart';
import 'package:flutter_automation_runner/src/definition/flow_param.dart';

/// Writes [value] the way a flow file holds it.
///
/// A [FlowParam] becomes its placeholder, a [FlowFinder] and a localized text
/// become their JSON objects, and maps and lists convert their members.
Object? writeFlowJsonValue(Object? value) {
  return switch (value) {
    final FlowParam param => param.placeholder,
    final FlowFinder finder => finder.toJson(),
    final AutomationLocalizedText text => text.toJson(),
    final Map<String, Object?> map => map.map(
      (key, member) => MapEntry(key, writeFlowJsonValue(member)),
    ),
    final List<Object?> list => list.map(writeFlowJsonValue).toList(),
    _ => value,
  };
}
