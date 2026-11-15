import 'package:flutter_automation_mock/src/state/automation_mode.dart';
import 'package:flutter_automation_mock/src/state/automation_walk_progress.dart';

/// {@category Utils}
///
/// The choice a tester made, kept between launches of the app.
final class AutomationState {
  static const _modeKey = 'mode';
  static const _scenarioKey = 'scenario';
  static const _walkKey = 'walk';
  static const _outcomeFailuresKey = 'outcomeFailures';

  /// Backend the app starts on.
  final AutomationMode mode;

  /// Scenario JSON the mock starts from.
  final Map<String, Object?> scenario;

  /// The manual walk in progress, missing when none runs.
  final AutomationWalkProgress? walk;

  /// The `failures` JSON of the outcome the tester chose last, so the panel
  /// tells them apart from the overrides of the tester after a restart.
  final Map<String, Object?> outcomeFailures;

  const AutomationState({
    this.mode = AutomationMode.server,
    this.scenario = const {},
    this.walk,
    this.outcomeFailures = const {},
  });

  /// Reads the state out of [json]. A missing or unknown part takes its
  /// default.
  factory AutomationState.fromJson(Map<String, Object?> json) {
    final scenario = json[_scenarioKey];
    final outcomeFailures = json[_outcomeFailuresKey];

    return AutomationState(
      mode:
          AutomationMode.values.asNameMap()[json[_modeKey]] ??
          AutomationMode.server,
      scenario: scenario is Map<String, Object?> ? scenario : const {},
      walk: AutomationWalkProgress.tryFromJson(json[_walkKey]),
      outcomeFailures: outcomeFailures is Map<String, Object?>
          ? outcomeFailures
          : const {},
    );
  }

  /// State with the given parts replaced.
  ///
  /// The [mode] parameter is the new backend.
  /// The [scenario] parameter is the new scenario JSON.
  /// The [walk] parameter is the new walk; [hasWalk] tells whether it replaces
  /// the current one, so `null` can end a walk.
  /// The [outcomeFailures] parameter is the new `failures` JSON of the outcome.
  AutomationState copyWith({
    AutomationMode? mode,
    Map<String, Object?>? scenario,
    AutomationWalkProgress? walk,
    bool hasWalk = false,
    Map<String, Object?>? outcomeFailures,
  }) {
    return AutomationState(
      mode: mode ?? this.mode,
      scenario: scenario ?? this.scenario,
      walk: hasWalk ? walk : this.walk,
      outcomeFailures: outcomeFailures ?? this.outcomeFailures,
    );
  }

  /// The state as the JSON of `state.json`.
  Map<String, Object?> toJson() {
    return {
      _modeKey: mode.name,
      _scenarioKey: scenario,
      _walkKey: ?walk?.toJson(),
      if (outcomeFailures.isNotEmpty) _outcomeFailuresKey: outcomeFailures,
    };
  }
}
