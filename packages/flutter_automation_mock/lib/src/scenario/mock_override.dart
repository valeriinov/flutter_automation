import 'package:flutter_automation_mock/src/scenario/mock_scenario.dart';
import 'package:flutter_automation_mock/src/transport/mock_latency_profile.dart';

/// {@category Utils}
///
/// One key of a scenario and the value a run sets it to.
///
/// A [MockScenario] applies its overrides in order. A raw
/// `MockOverride(key, value)` merges a nested object key by key, so it states
/// only the leaves it changes. A typed override of a section, from
/// `MockSection.override`, replaces its section.
class MockOverride {
  /// Top-level key of the scenario JSON: a section name or a transport key.
  final String key;

  /// Value of the key: a JSON object for a section, a JSON value otherwise.
  ///
  /// A typed override of a section holds no value: the settings it produces
  /// depend on the overrides that came before it.
  final Object? value;

  /// Creates an override of one scenario key.
  ///
  /// The [key] parameter is the top-level key of the scenario JSON.
  /// The [value] parameter is the JSON value the run sets.
  const MockOverride(this.key, this.value);

  /// Creates the override of the latency profile, by its enum name.
  MockOverride.latency(MockLatencyProfile profile)
    : this(MockScenario.latencyKey, profile.name);

  /// Creates the override of the latency jitter seed.
  MockOverride.latencySeed(int seed) : this(MockScenario.latencySeedKey, seed);

  /// Creates the override of the failed paths: path to failure JSON.
  MockOverride.failures(Map<String, Object?> failures)
    : this(MockScenario.failuresKey, failures);

  /// The [scenario] JSON after this override applied.
  ///
  /// The [scenario] parameter is the JSON the earlier overrides built.
  Map<String, Object?> applyTo(Map<String, Object?> scenario) =>
      MockScenario.mergeJson(scenario, {key: value});
}
