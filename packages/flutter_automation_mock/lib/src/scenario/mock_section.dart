import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_automation_mock/src/scenario/mock_override.dart';
import 'package:flutter_automation_mock/src/scenario/mock_settings_override.dart';

/// Reads typed settings out of the settings JSON of one section.
typedef MockSettingsReader<S> = S Function(Map<String, Object?> json);

/// {@category Utils}
///
/// Section of the mock a project configures: a backend area or a device.
///
/// A project declares one per section in a file free of Flutter imports.
/// The flows that run on the host then name its profiles by Dart symbol. [S]
/// is the settings class of the section. Its `toJson` output is the section
/// JSON of the scenario and [fromJson] reads it back.
final class MockSection<S> {
  static const _equality = DeepCollectionEquality();

  /// Key of the section in the scenario JSON.
  final String name;

  /// Builds the settings out of the section JSON; an empty object gives the
  /// defaults.
  final MockSettingsReader<S> fromJson;

  /// Keys of the settings that the app reads once at launch or seeds into its
  /// storage.
  ///
  /// A change of such a key takes effect after a restart of the app.
  final Set<String> restartKeys;

  final Map<String, S Function(S settings)> _profiles;

  /// Creates a section of the mock.
  ///
  /// The [name] parameter is the key of the section in the scenario JSON.
  /// The [fromJson] parameter builds the settings out of the section JSON.
  /// The [profiles] parameter holds the named changes of the settings.
  /// The [restartKeys] parameter names the settings that need a restart.
  MockSection({
    required this.name,
    required this.fromJson,
    Map<String, S Function(S settings)> profiles = const {},
    this.restartKeys = const {},
  }) : _profiles = profiles;

  /// Names of the profiles that flows and tools apply by name.
  ///
  /// A profile receives the settings that the earlier overrides of the scenario
  /// built and returns the settings the run needs.
  Iterable<String> get profileNames => _profiles.keys;

  /// Settings of the section with nothing overridden.
  S get defaults => fromJson(const {});

  /// Override that applies the profile [profileName].
  ///
  /// Throws an [ArgumentError] when the section declares no such profile.
  MockOverride profile(String profileName) {
    final update = _profiles[profileName];

    if (update == null) {
      throw ArgumentError.value(
        profileName,
        'profileName',
        'Mock section "$name" declares no such profile',
      );
    }

    return override(update);
  }

  /// Override that replaces the settings of the section with the result of
  /// [update].
  ///
  /// The [update] parameter receives the settings that the earlier overrides
  /// built and returns the new settings.
  MockOverride override(S Function(S settings) update) =>
      MockSettingsOverride(this, update);

  /// Settings of the section that [scenarioJson] describes.
  S read(Map<String, Object?> scenarioJson) {
    final section = scenarioJson[name];

    return fromJson(
      section is Map<String, Object?> ? section : const <String, Object?>{},
    );
  }

  /// Whether [next] differs from [current] in a key of [restartKeys].
  ///
  /// The comparison reads the settings of the section out of both scenario
  /// JSON objects, so a key left out and a key set to its default are equal.
  ///
  /// The [current] parameter is the scenario JSON the app runs on.
  /// The [next] parameter is the scenario JSON that the app would run on.
  bool changesRestartKey(
    Map<String, Object?> current,
    Map<String, Object?> next,
  ) {
    final before = _encode(read(current));
    final after = _encode(read(next));

    return restartKeys.any((key) => !_equality.equals(before[key], after[key]));
  }

  Map<String, Object?> _encode(S settings) {
    final json = jsonDecode(jsonEncode(settings));

    return json is Map<String, Object?> ? json : const {};
  }
}
