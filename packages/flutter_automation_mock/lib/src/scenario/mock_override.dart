/// {@category Utils}
///
/// One key of a scenario and the value a run sets it to.
///
/// A [MockScenario] merges its overrides in order. A nested object merges key
/// by key, so an override states only the leaves it changes.
final class MockOverride {
  /// Top-level key of the scenario JSON: a feature name or a transport key.
  final String key;

  /// Value of the key: a JSON object for a feature, a JSON value otherwise.
  final Object? value;

  /// Creates an override of one scenario key.
  ///
  /// The [key] parameter is the top-level key of the scenario JSON.
  /// The [value] parameter is the JSON value the run sets.
  const MockOverride(this.key, this.value);
}
