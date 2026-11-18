import 'package:flutter_automation_runner/flutter_automation_runner.dart';

/// {@category Utils}
///
/// The stages one walk of a variant captures: every stage, or the named ones
/// of a walk that stops after the last of them.
final class AtlasStageScope {
  /// Indexes of the stages the walk shoots, in order; empty for every stage.
  final List<int> stages;

  /// The stage the walk stops after, absent when it walks to the end.
  final int? until;

  /// Every stage of a walk to the end.
  const AtlasStageScope.every() : stages = const [], until = null;

  const AtlasStageScope._(this.stages, {required this.until});

  /// The [stages] of a variant holding [stageCount] stages, the walk stopping
  /// after the last of them unless it is the last stage of the variant.
  factory AtlasStageScope.of(Iterable<int> stages, {required int stageCount}) {
    final sortedStages = stages.toSet().toList()..sort();
    final lastStage = sortedStages.lastOrNull;

    return AtlasStageScope._(
      sortedStages,
      until: lastStage == null || lastStage >= stageCount - 1
          ? null
          : lastStage,
    );
  }

  /// Whether the walk shoots every stage.
  bool get isEveryStage => stages.isEmpty;

  /// The options of the automation runner walking this scope.
  List<String> get runnerArguments {
    return [
      if (stages.isNotEmpty) ...[
        AutomationCaptureStages.shootOption,
        stages.join(','),
      ],
      if (until case final until?) ...[
        AutomationCaptureStages.untilOption,
        '$until',
      ],
    ];
  }
}
