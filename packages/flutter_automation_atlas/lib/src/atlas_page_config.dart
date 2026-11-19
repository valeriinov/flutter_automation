import 'dart:io';

import 'package:yaml/yaml.dart';

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_page_part.dart';

/// {@category Utils}
///
/// What the page of the atlas takes from the `flutter_automation: atlas:`
/// section of the `pubspec.yaml` of the project.
///
/// ```yaml
/// flutter_automation:
///   atlas:
///     maxBundleBytes: 15728640
///     maxBundleImages: 254
///     editions:
///       lite: [flowStages, screenDescriptions, designLinks]
/// ```
final class AtlasPageConfig {
  static const _sectionKey = 'flutter_automation';
  static const _atlasKey = 'atlas';
  static const _editionsKey = 'editions';
  static const _maxBytesKey = 'maxBundleBytes';
  static const _maxImagesKey = 'maxBundleImages';
  static const _keyPath = '$_sectionKey: $_atlasKey:';

  final Map<String, Set<AtlasPagePart>> _editions;
  final int? _maxBundleBytes;
  final int? _maxBundleImages;

  const AtlasPageConfig._(
    this._editions,
    this._maxBundleBytes,
    this._maxBundleImages,
  );

  /// Reads the `pubspec.yaml` at [pubspecPath].
  ///
  /// Throws an [AtlasException] when the section is malformed.
  factory AtlasPageConfig.read(String pubspecPath) {
    final file = File(pubspecPath);

    if (!file.existsSync()) {
      throw AtlasException('No $pubspecPath here.');
    }

    return AtlasPageConfig.fromPubspec(file.readAsStringSync());
  }

  /// Reads the text of a `pubspec.yaml`.
  factory AtlasPageConfig.fromPubspec(String pubspec) {
    final root = loadYaml(pubspec);
    final section = root is YamlMap ? root[_sectionKey] : null;
    final atlas = section is YamlMap ? section[_atlasKey] : null;

    if (atlas == null) {
      return const AtlasPageConfig._({}, null, null);
    }

    if (atlas is! YamlMap) {
      throw const AtlasException('$_keyPath is not a map.');
    }

    return AtlasPageConfig._(
      _readEditions(atlas[_editionsKey]),
      _readLimit(atlas, _maxBytesKey),
      _readLimit(atlas, _maxImagesKey),
    );
  }

  /// The most bytes the bundle page may take.
  ///
  /// Throws an [AtlasException] naming the key when the project sets none.
  int get maxBundleBytes => _requireLimit(_maxBundleBytes, _maxBytesKey);

  /// The most images a bundle may hold, inline or as sheet files.
  ///
  /// Throws an [AtlasException] naming the key when the project sets none.
  int get maxBundleImages => _requireLimit(_maxBundleImages, _maxImagesKey);

  /// The edition named [name]: the one the project lists, else `full` or
  /// `lite`.
  ///
  /// Throws an [AtlasException] naming the editions there are when [name]
  /// is none of them.
  AtlasEdition resolveEdition(String name) {
    final parts = _editions[name] ?? _builtInEditions[name];

    if (parts == null) {
      throw AtlasException(
        'No edition "$name"; the editions are '
        '${editionNames.join(', ')}.',
      );
    }

    return AtlasEdition(name, parts);
  }

  /// The names of every edition, the built-in ones first.
  List<String> get editionNames {
    return {..._builtInEditions.keys, ..._editions.keys}.toList();
  }

  static final Map<String, Set<AtlasPagePart>> _builtInEditions = {
    AtlasEdition.fullName: AtlasPagePart.values.toSet(),
    AtlasEdition.liteName: {
      AtlasPagePart.flowStages,
      AtlasPagePart.screenDescriptions,
    },
  };

  static Map<String, Set<AtlasPagePart>> _readEditions(Object? editions) {
    if (editions == null) {
      return {};
    }

    if (editions is! YamlMap) {
      throw const AtlasException('$_keyPath $_editionsKey: is not a map.');
    }

    return {
      for (final MapEntry(:key, :value) in editions.entries)
        '$key': _readParts('$key', value),
    };
  }

  static Set<AtlasPagePart> _readParts(String edition, Object? names) {
    final subject = '$_keyPath $_editionsKey: $edition:';

    if (names is! YamlList) {
      throw AtlasException('$subject is not a list of part names.');
    }

    return {
      for (final name in names)
        AtlasPagePart.tryRead('$name') ??
            (throw AtlasException(
              '$subject names no part "$name"; the parts are '
              '${AtlasPagePart.values.map((part) => part.name).join(', ')}.',
            )),
    };
  }

  static int? _readLimit(YamlMap atlas, String key) {
    final value = atlas[key];

    if (value == null) {
      return null;
    }

    if (value is int && value > 0) {
      return value;
    }

    throw AtlasException('$_keyPath $key: is not a positive integer.');
  }

  static int _requireLimit(int? limit, String key) {
    if (limit == null) {
      throw AtlasException('The pubspec.yaml sets no $_keyPath $key:.');
    }

    return limit;
  }
}
