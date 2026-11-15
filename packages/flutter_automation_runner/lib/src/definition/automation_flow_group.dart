import 'package:flutter_automation_runner/src/automation_localized_text.dart';

/// {@category Utils}
///
/// A group of flows that a catalogue and an atlas show under one caption.
final class AutomationFlowGroup {
  /// Name that the flows of the group refer to.
  final String name;

  /// Caption of the group, written once per locale.
  final AutomationLocalizedText title;

  const AutomationFlowGroup({required this.name, required this.title});

  /// The group as the flow JSON holds it.
  Map<String, Object?> toJson() => {'name': name, 'title': title.toJson()};
}
