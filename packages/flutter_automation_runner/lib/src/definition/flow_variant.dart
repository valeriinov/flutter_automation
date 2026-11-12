import 'package:flutter_automation_mock/mock_section.dart';

import 'package:flutter_automation_runner/src/automation_localized_text.dart';
import 'package:flutter_automation_runner/src/automation_flow_entry.dart';
import 'package:flutter_automation_runner/src/definition/flow_item.dart';

/// {@category Utils}
///
/// One way through a journey: the items it walks and what it proves.
final class FlowVariant {
  /// Name the command line asks the variant by.
  final String name;

  /// Items the run walks, in order.
  final List<FlowItem> items;

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

  /// Overrides that follow the ones of the flow for a run of this variant.
  final List<MockOverride> scenario;

  const FlowVariant(
    this.name, {
    required this.items,
    this.title,
    this.proves,
    this.entry,
    this.stateOf,
    this.scenario = const [],
  });

  /// The variant as the flow JSON holds it.
  ///
  /// The `scenario` key holds the scenario of one list of overrides: the ones
  /// of the flow, then the ones of the variant. The key is present whenever the
  /// flow or the variant has an override, even when the result is empty.
  ///
  /// The [flowScenario] parameter is the list of overrides of the flow.
  Map<String, Object?> toJson({List<MockOverride> flowScenario = const []}) {
    final overrides = [...flowScenario, ...scenario];

    return {
      'title': ?title?.toJson(),
      'proves': ?proves?.toJson(),
      'entry': ?entry?.toJson(),
      'stateOf': ?stateOf,
      if (overrides.isNotEmpty) 'scenario': MockScenario(overrides).toJson(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
