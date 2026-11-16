import 'package:flutter_automation_mock/src/contract/mock_api_failure.dart';
import 'package:flutter_automation_mock/src/scenario/mock_scenario.dart';
import 'package:flutter_automation_mock/src/transport/mock_latency.dart';
import 'package:flutter_automation_mock/src/transport/mock_latency_profile.dart';

/// Reads the transport keys of a [MockScenario]: latency and failures.
abstract final class MockScenarioReader {
  static const _defaultLatencySeed = 0;

  /// Latency profile of the `latency` key, `realistic` when the key is absent
  /// or names no profile.
  static MockLatencyProfile readLatencyProfile(MockScenario scenario) {
    final profileName = scenario.toJson()[MockScenario.latencyKey];

    return MockLatencyProfile.values.asNameMap()[profileName] ??
        MockLatencyProfile.realistic;
  }

  /// Latency of the `latency` and `latencySeed` keys, seed 0 when absent.
  static MockLatency readLatency(MockScenario scenario) {
    final seed = scenario.toJson()[MockScenario.latencySeedKey];

    return MockLatency(
      profile: readLatencyProfile(scenario),
      seed: seed is int ? seed : _defaultLatencySeed,
    );
  }

  /// Failed paths of the `failures` key: path to failure.
  static Map<String, MockApiFailure> readFailures(MockScenario scenario) {
    final failures = scenario.toJson()[MockScenario.failuresKey];

    if (failures is! Map<String, Object?>) {
      return const {};
    }

    return {
      for (final MapEntry(:key, :value) in failures.entries)
        if (value is Map<String, Object?>) key: MockApiFailure.fromJson(value),
    };
  }

  /// Latency profiles of single paths of the `latencies` key of [scenario]:
  /// path to profile. A value that names no profile is skipped.
  static Map<String, MockLatencyProfile> readLatencies(MockScenario scenario) {
    final latencies = scenario.toJson()[MockScenario.latenciesKey];

    if (latencies is! Map<String, Object?>) {
      return const {};
    }

    final profiles = MockLatencyProfile.values.asNameMap();

    return {
      for (final MapEntry(:key, :value) in latencies.entries)
        key: ?profiles[value],
    };
  }
}
