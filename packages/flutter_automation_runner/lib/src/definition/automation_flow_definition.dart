import 'package:flutter_automation_mock/mock_section.dart';

import 'package:flutter_automation_runner/src/automation_localized_text.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';
import 'package:flutter_automation_runner/src/definition/automation_flow_group.dart';
import 'package:flutter_automation_runner/src/definition/flow_variant.dart';

/// {@category Utils}
///
/// A journey written in Dart: its variants, the scenario they start from and
/// the words that describe it.
///
/// [toJson] gives the model that the runner reads, so a flow in Dart and its
/// JSON form give one `--dry-run` report.
final class AutomationFlowDefinition {
  /// Name the command line asks the flow by.
  final String name;

  /// Variants of the flow, one per way through it.
  final List<FlowVariant> variants;

  /// What the journey is, in words for people, missing when it has none.
  final AutomationLocalizedText? title;

  /// What the journey is about in one sentence, missing when it has none.
  final AutomationLocalizedText? subtitle;

  /// Group the flow belongs to, missing when it has none.
  final AutomationFlowGroup? group;

  /// Variant a run walks when it names none, missing when the flow has one
  /// variant or the run always names it.
  final String? defaultVariant;

  /// Whether the QA catalogue of the panel lists the flow. A flow a tester
  /// walks by hand sets it.
  final bool isInQaCatalogue;

  /// Overrides every variant starts from.
  final List<MockOverride> scenario;

  const AutomationFlowDefinition({
    required this.name,
    required this.variants,
    this.title,
    this.subtitle,
    this.group,
    this.defaultVariant,
    this.isInQaCatalogue = false,
    this.scenario = const [],
  });

  /// The flow as the flow JSON holds it.
  ///
  /// Throws an [AutomationRunnerException] when two variants share a name.
  Map<String, Object?> toJson() {
    final names = variants.map((variant) => variant.name);

    if (names.toSet().length != variants.length) {
      throw AutomationRunnerException(
        'Flow "$name" repeats a variant name in ${names.toList()}.',
      );
    }

    return {
      'title': ?title?.toJson(),
      'subtitle': ?subtitle?.toJson(),
      'group': ?group?.toJson(),
      'defaultVariant': ?defaultVariant,
      if (isInQaCatalogue) 'isInQaCatalogue': true,
      if (scenario.isNotEmpty) 'scenario': MockScenario(scenario).toJson(),
      'variants': {
        for (final variant in variants)
          variant.name: variant.toJson(flowScenario: scenario),
      },
    };
  }
}
