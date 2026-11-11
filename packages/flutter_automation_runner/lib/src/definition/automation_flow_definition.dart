import 'package:flutter_automation_mock/mock_feature.dart';

import 'package:flutter_automation_runner/src/automation_localized_text.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';
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

  /// Variant a run walks when it names none, missing when the flow has one
  /// variant or the run always names it.
  final String? defaultVariant;

  /// Overrides every variant starts from.
  final List<MockOverride> scenario;

  const AutomationFlowDefinition({
    required this.name,
    required this.variants,
    this.title,
    this.subtitle,
    this.defaultVariant,
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
      'defaultVariant': ?defaultVariant,
      if (scenario.isNotEmpty) 'mock': MockScenario(scenario).toJson(),
      'variants': {
        for (final variant in variants) variant.name: variant.toJson(),
      },
    };
  }
}
