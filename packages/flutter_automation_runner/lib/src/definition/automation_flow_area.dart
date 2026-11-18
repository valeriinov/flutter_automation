import 'package:flutter_automation_runner/src/automation_localized_text.dart';

/// {@category Utils}
///
/// An area of a catalogue: the top level that holds groups of flows under one
/// caption.
final class AutomationFlowArea {
  /// Name that the groups of the area refer to.
  final String name;

  /// Caption of the area, written once per locale.
  final AutomationLocalizedText title;

  const AutomationFlowArea({required this.name, required this.title});

  /// The area as the flow JSON holds it.
  Map<String, Object?> toJson() => {'name': name, 'title': title.toJson()};
}
