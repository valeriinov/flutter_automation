import 'package:flutter_automation_mock/src/scenario/mock_field.dart';
import 'package:flutter_automation_mock/src/scenario/mock_override.dart';

/// Reads typed settings out of the settings JSON of one feature.
typedef MockSettingsReader<S> = S Function(Map<String, Object?> json);

/// {@category Utils}
///
/// Section of the mock a project configures: a backend area or a device.
///
/// A project declares one per section in a file free of Flutter imports, so
/// the flows that run on the host name its profiles by Dart symbol. [S] is the
/// settings class of the section.
final class MockFeature<S> {
  /// Key of the section in the scenario JSON.
  final String name;

  /// Builds the settings out of the section JSON; an empty object gives the
  /// defaults.
  final MockSettingsReader<S> fromJson;

  /// Named partial settings that flows and tools apply by name.
  ///
  /// A profile holds only the keys it changes, so it merges over whatever the
  /// scenario already set.
  final Map<String, Map<String, Object?>> profiles;

  /// Description of the settings fields, for a generic editor.
  final List<MockField> fields;

  /// Creates a section of the mock.
  ///
  /// The [name] parameter is the key of the section in the scenario JSON.
  /// The [fromJson] parameter builds the settings out of the section JSON.
  /// The [profiles] parameter holds the named partial settings.
  /// The [fields] parameter describes the settings fields.
  const MockFeature({
    required this.name,
    required this.fromJson,
    this.profiles = const {},
    this.fields = const [],
  });

  /// Settings of the section with nothing overridden.
  S get defaults => fromJson(const {});

  /// Override that applies the profile [profileName].
  ///
  /// Throws an [ArgumentError] when the section declares no such profile.
  MockOverride profile(String profileName) {
    final values = profiles[profileName];

    if (values == null) {
      throw ArgumentError.value(
        profileName,
        'profileName',
        'Mock feature "$name" declares no such profile',
      );
    }

    return MockOverride(name, values);
  }

  /// Override that sets the [values] keys of the section.
  MockOverride override(Map<String, Object?> values) =>
      MockOverride(name, values);

  /// Settings of the section that [scenarioJson] describes.
  S read(Map<String, Object?> scenarioJson) {
    final section = scenarioJson[name];

    return fromJson(
      section is Map<String, Object?> ? section : const <String, Object?>{},
    );
  }
}
