import 'package:flutter_automation_mock/src/scenario/mock_section.dart';
import 'package:flutter_automation_mock/src/scenario/mock_override.dart';

/// {@category Utils}
///
/// State a run starts the mock from: the overrides of its sections.
///
/// The JSON form is what the runner sends with `scenario.apply` and what the
/// app saves to read at the next launch.
final class MockScenario {
  /// Key of the latency profile in the scenario JSON.
  static const latencyKey = 'latency';

  /// Key of the latency jitter seed in the scenario JSON.
  static const latencySeedKey = 'latencySeed';

  /// Key of the failed paths in the scenario JSON.
  static const failuresKey = 'failures';

  /// Overrides in the order they apply.
  final List<MockOverride> overrides;

  /// Creates a scenario out of [overrides], applied in order.
  const MockScenario(this.overrides);

  /// Scenario that [json] describes, kept as one override per key.
  factory MockScenario.fromJson(Map<String, Object?> json) => MockScenario(
    json.entries
        .map((entry) => MockOverride(entry.key, entry.value))
        .toList(growable: false),
  );

  /// Scenario JSON: the overrides applied in order, keys in first-use order.
  Map<String, Object?> toJson() => overrides.fold(
    <String, Object?>{},
    (json, override) => override.applyTo(json),
  );

  /// Scenario with the overrides of [other] applied after these.
  MockScenario merge(MockScenario other) =>
      MockScenario([...overrides, ...other.overrides]);

  /// Settings of [section] in this scenario.
  S settingsOf<S>(MockSection<S> section) => section.read(toJson());

  /// Merges [over] into [base]: nested objects merge key by key, any other
  /// value of [over] replaces the one of [base].
  static Map<String, Object?> mergeJson(
    Map<String, Object?> base,
    Map<String, Object?> over,
  ) => {
    ...base,
    for (final MapEntry(:key, :value) in over.entries)
      key: _mergeValue(base[key], value),
  };

  static Object? _mergeValue(Object? base, Object? over) {
    if (base is Map<String, Object?> && over is Map<String, Object?>) {
      return mergeJson(base, over);
    }

    return over;
  }
}
