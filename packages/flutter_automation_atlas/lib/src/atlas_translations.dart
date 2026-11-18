import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';

/// {@category Utils}
///
/// The translations the app renders a capture in, each value addressed by the
/// hash a stage stores for the key it showed.
final class AtlasTranslations {
  final Map<String, Object?> _values;

  const AtlasTranslations(this._values);

  /// Reads the translations of [locale] from the project of [paths].
  factory AtlasTranslations.read(AtlasLocations paths, String locale) {
    return AtlasTranslations(paths.project.translations(locale));
  }

  /// The value of every key, as the translations file holds it.
  Map<String, Object?> get values => _values;

  /// Each of [keys] the translations hold, mapped to the hash of its value.
  Map<String, String> hashKeys(Iterable<String> keys) {
    return {
      for (final key in keys)
        if (_values.containsKey(key))
          key: AtlasContentHash.hashJson(_values[key]),
    };
  }

  /// The hash of the value of [key], `null` when the translations hold no
  /// such key.
  String? tryHashValue(String key) {
    if (!_values.containsKey(key)) {
      return null;
    }

    return AtlasContentHash.hashJson(_values[key]);
  }
}
