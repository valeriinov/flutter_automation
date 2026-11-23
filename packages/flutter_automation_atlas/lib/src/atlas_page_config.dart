import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_page_part.dart';

typedef _EditionSettings = ({
  Set<AtlasPagePart>? parts,
  Map<String, String> title,
  String? iconPath,
});

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
///     icon: tool/atlas/icon.png
///     editions:
///       design: [flowStages, designLinks]
///       lite:
///         parts: [flowStages, screenDescriptions]
///         title: {en: Product flows, uk: Флоу продукту}
///         icon: tool/atlas/icon_lite.png
///       full:
///         title: {en: Team atlas, uk: Атлас команди}
/// ```
///
/// An edition is a list of part names, or a map of `parts`, `title` and
/// `icon`. A map for `full` or `lite` without `parts` keeps the parts of the
/// built-in edition. The `title` maps a page language to the title of the
/// page. The `icon` of an edition replaces the `icon` of the section. An
/// icon is the path of a `.png` or `.ico` file, relative to the root of the
/// project.
final class AtlasPageConfig {
  static const _sectionKey = 'flutter_automation';
  static const _atlasKey = 'atlas';
  static const _editionsKey = 'editions';
  static const _maxBytesKey = 'maxBundleBytes';
  static const _maxImagesKey = 'maxBundleImages';
  static const _iconKey = 'icon';
  static const _partsKey = 'parts';
  static const _titleKey = 'title';
  static const _keyPath = '$_sectionKey: $_atlasKey:';
  static const _editionKeys = [_partsKey, _titleKey, _iconKey];
  static const _pageLanguages = ['en', 'uk'];
  static const _iconExtensions = ['.png', '.ico'];

  final Map<String, _EditionSettings> _editions;
  final int? _maxBundleBytes;
  final int? _maxBundleImages;
  final String? _iconPath;

  const AtlasPageConfig._(
    this._editions,
    this._maxBundleBytes,
    this._maxBundleImages,
    this._iconPath,
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
      return const AtlasPageConfig._({}, null, null, null);
    }

    if (atlas is! YamlMap) {
      throw const AtlasException('$_keyPath is not a map.');
    }

    return AtlasPageConfig._(
      _readEditions(atlas[_editionsKey]),
      _readLimit(atlas, _maxBytesKey),
      _readLimit(atlas, _maxImagesKey),
      _readIcon(_keyPath, atlas[_iconKey]),
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
  /// `lite`. Its icon is the one of the edition, else the one of the section.
  ///
  /// Throws an [AtlasException] naming the editions there are when [name]
  /// is none of them.
  AtlasEdition resolveEdition(String name) {
    final settings = _editions[name];
    final parts = settings?.parts ?? _builtInEditions[name];

    if (parts == null) {
      throw AtlasException(
        'No edition "$name"; the editions are '
        '${editionNames.join(', ')}.',
      );
    }

    return AtlasEdition(
      name,
      parts,
      title: settings?.title ?? const {},
      iconPath: settings?.iconPath ?? _iconPath,
    );
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

  static Map<String, _EditionSettings> _readEditions(Object? editions) {
    if (editions == null) {
      return {};
    }

    if (editions is! YamlMap) {
      throw const AtlasException('$_keyPath $_editionsKey: is not a map.');
    }

    return {
      for (final MapEntry(:key, :value) in editions.entries)
        '$key': _readEdition('$key', value),
    };
  }

  static _EditionSettings _readEdition(String edition, Object? value) {
    final subject = '$_keyPath $_editionsKey: $edition:';

    if (value is YamlList) {
      return (parts: _readParts(subject, value), title: {}, iconPath: null);
    }

    if (value is! YamlMap) {
      throw AtlasException(
        '$subject is not a list of part names or a map of '
        '${_editionKeys.join(', ')}.',
      );
    }

    _rejectUnknownKeys(subject, value);

    final parts = value[_partsKey];

    if (parts == null && !_builtInEditions.containsKey(edition)) {
      throw AtlasException(
        '$subject lists no $_partsKey:; only '
        '${_builtInEditions.keys.join(' and ')} keep their own parts.',
      );
    }

    return (
      parts: parts == null ? null : _readParts('$subject $_partsKey:', parts),
      title: _readTitle(subject, value[_titleKey]),
      iconPath: _readIcon(subject, value[_iconKey]),
    );
  }

  static Set<AtlasPagePart> _readParts(String subject, Object? names) {
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

  static void _rejectUnknownKeys(String subject, YamlMap edition) {
    for (final key in edition.keys) {
      if (!_editionKeys.contains(key)) {
        throw AtlasException(
          '$subject has no key "$key"; the keys are '
          '${_editionKeys.join(', ')}.',
        );
      }
    }
  }

  static Map<String, String> _readTitle(String subject, Object? title) {
    if (title == null) {
      return {};
    }

    if (title is! YamlMap) {
      throw AtlasException(
        '$subject $_titleKey: is not a map of page languages to texts.',
      );
    }

    return {
      for (final MapEntry(:key, :value) in title.entries)
        _readTitleLanguage(subject, key): _readTitleText(subject, key, value),
    };
  }

  static String _readTitleLanguage(String subject, Object? language) {
    if (_pageLanguages.contains(language)) {
      return '$language';
    }

    throw AtlasException(
      '$subject $_titleKey: names no page language "$language"; the page '
      'languages are ${_pageLanguages.join(', ')}.',
    );
  }

  static String _readTitleText(String subject, Object? language, Object? text) {
    if (text is String && text.isNotEmpty) {
      return text;
    }

    throw AtlasException('$subject $_titleKey: $language: is not a text.');
  }

  static String? _readIcon(String subject, Object? path) {
    if (path == null) {
      return null;
    }

    if (path is! String || path.isEmpty) {
      throw AtlasException('$subject $_iconKey: is not a path.');
    }

    if (!_iconExtensions.contains(p.extension(path).toLowerCase())) {
      throw AtlasException(
        '$subject $_iconKey: is not a ${_iconExtensions.join(' or ')} file.',
      );
    }

    return path;
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
