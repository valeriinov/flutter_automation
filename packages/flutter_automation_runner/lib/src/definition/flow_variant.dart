import 'package:flutter_automation_mock/mock_feature.dart';

import 'package:flutter_automation_runner/src/automation_localized_text.dart';
import 'package:flutter_automation_runner/src/automation_flow_entry.dart';
import 'package:flutter_automation_runner/src/definition/flow_item.dart';

/// {@category Utils}
///
/// One way through a journey: the entries it walks and what it proves.
final class FlowVariant {
  /// Name the command line asks the variant by.
  final String name;

  /// Entries the run walks, in order.
  final List<FlowItem> use;

  /// What way through the journey the variant walks, missing when it has none.
  final AutomationLocalizedText? title;

  /// What the variant proves when a run walks it, missing when it has none.
  final AutomationLocalizedText? proves;

  /// Where the variant enters its journey, missing when it starts where the
  /// other variants start.
  final AutomationFlowEntry? entry;

  /// The variant of the same flow whose frame this one shows in another state,
  /// missing for a variant that is a way of its own.
  final String? stateOf;

  /// Overrides that merge over the ones of the flow for a run of this variant.
  final List<MockOverride> scenario;

  const FlowVariant(
    this.name, {
    required this.use,
    this.title,
    this.proves,
    this.entry,
    this.stateOf,
    this.scenario = const [],
  });

  /// The variant as the flow JSON holds it.
  Map<String, Object?> toJson() => {
    'title': ?title?.toJson(),
    'proves': ?proves?.toJson(),
    'entry': ?entry?.toJson(),
    'stateOf': ?stateOf,
    if (scenario.isNotEmpty) 'mock': MockScenario(scenario).toJson(),
    'use': use.map((item) => item.toJson()).toList(),
  };
}
