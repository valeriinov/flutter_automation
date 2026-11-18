import 'package:flutter_automation_runner/src/automation_localized_text.dart';
import 'package:flutter_automation_runner/src/definition/automation_flow_area.dart';

/// {@category Utils}
///
/// A group of flows that a catalogue shows under one caption.
final class AutomationFlowGroup {
  /// Name that the flows of the group refer to.
  final String name;

  /// Caption of the group, written once per locale.
  final AutomationLocalizedText title;

  /// Area the group belongs to, missing when the group stands alone.
  final AutomationFlowArea? area;

  const AutomationFlowGroup({
    required this.name,
    required this.title,
    this.area,
  });

  /// The group as the flow JSON holds it.
  Map<String, Object?> toJson() {
    return {'name': name, 'title': title.toJson(), 'area': ?area?.toJson()};
  }
}
