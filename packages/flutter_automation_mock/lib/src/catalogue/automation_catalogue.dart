import 'package:flutter_automation_mock/src/catalogue/automation_catalogue_flow.dart';
import 'package:flutter_automation_mock/src/catalogue/automation_catalogue_tables.dart';
import 'package:flutter_automation_mock/src/catalogue/catalogue_json.dart';

/// {@category Utils}
///
/// An area of the catalogue: the top level that holds groups, with its
/// caption, by locale.
final class AutomationCatalogueArea {
  static const _nameKey = 'name';
  static const _titleKey = 'title';

  /// Name the groups refer to.
  final String name;

  /// Caption by locale.
  final Map<String, String> title;

  const AutomationCatalogueArea({required this.name, required this.title});

  /// Reads the area out of [json].
  factory AutomationCatalogueArea.fromJson(Map<String, Object?> json) {
    return AutomationCatalogueArea(
      name: CatalogueJson.tryString(json, _nameKey) ?? '',
      title: CatalogueJson.tryText(json, _titleKey) ?? const {},
    );
  }

  /// The area as JSON.
  Map<String, Object?> toJson() => {_nameKey: name, _titleKey: title};
}

/// {@category Utils}
///
/// A group of flows with its caption, by locale.
final class AutomationCatalogueGroup {
  static const _nameKey = 'name';
  static const _titleKey = 'title';
  static const _areaKey = 'area';

  /// Name the flows refer to.
  final String name;

  /// Caption by locale.
  final Map<String, String> title;

  /// Name of the area the group belongs to, missing when it has none.
  final String? area;

  const AutomationCatalogueGroup({
    required this.name,
    required this.title,
    this.area,
  });

  /// Reads the group out of [json].
  factory AutomationCatalogueGroup.fromJson(Map<String, Object?> json) {
    return AutomationCatalogueGroup(
      name: CatalogueJson.tryString(json, _nameKey) ?? '',
      title: CatalogueJson.tryText(json, _titleKey) ?? const {},
      area: CatalogueJson.tryString(json, _areaKey),
    );
  }

  /// The group as JSON.
  Map<String, Object?> toJson() {
    return {_nameKey: name, _titleKey: title, _areaKey: ?area};
  }
}

/// {@category Utils}
///
/// Thrown when a catalogue file has a version this build does not read.
final class AutomationCatalogueVersionException implements Exception {
  /// The `version` the file holds, `null` when it holds none.
  final Object? version;

  const AutomationCatalogueVersionException(this.version);

  /// The found version, the version this build reads and the regenerate
  /// command.
  String get message {
    final found = version == null ? 'no version' : 'version $version';

    return 'The catalogue has $found, and this build reads version '
        '${AutomationCatalogue.currentVersion}. Regenerate the catalogue '
        'with the runner option `--qa-catalogue`.';
  }

  @override
  String toString() => 'AutomationCatalogueVersionException: $message';
}

/// {@category Utils}
///
/// The flows a tester can walk, the areas and groups that sort them, the
/// requests each step sends, and the date settings a date finder of a step
/// needs.
///
/// The JSON holds `version: 2`. It stores each distinct response of the mock
/// once in `responses`, and each repeated string of 1024 characters or more
/// once in `blobs`. A step refers to its response by hash.
///
/// The runner writes the catalogue as a JSON file out of the flows and the
/// recordings of their runs. The panel and the player read it. The library
/// imports no Flutter code, so the runner reads it on the host.
final class AutomationCatalogue {
  /// The version of the JSON this library writes and reads.
  static const currentVersion = 2;

  static const _versionKey = 'version';
  static const _areasKey = 'areas';
  static const _groupsKey = 'groups';
  static const _flowsKey = 'flows';
  static const _dateFormatsKey = 'dateFormats';
  static const _dateValueKeysKey = 'dateValueKeys';

  /// Areas in display order.
  final List<AutomationCatalogueArea> areas;

  /// Groups in display order.
  final List<AutomationCatalogueGroup> groups;

  /// Flows in display order.
  final List<AutomationCatalogueFlow> flows;

  /// Pattern that a `dateText` finder writes a date in, by locale code. The
  /// tokens are `yyyy`, `MM` and `dd`.
  final Map<String, String> dateFormats;

  /// Value key template of each declared date finder, by the name of the
  /// finder, such as `day.tile.{yyyyMMdd}`.
  final Map<String, String> dateValueKeys;

  const AutomationCatalogue({
    this.areas = const [],
    this.groups = const [],
    this.flows = const [],
    this.dateFormats = const {},
    this.dateValueKeys = const {},
  });

  /// Reads the catalogue out of [json].
  ///
  /// Throws an [AutomationCatalogueVersionException] when the `version` of
  /// [json] is missing or is not [currentVersion].
  factory AutomationCatalogue.fromJson(Map<String, Object?> json) {
    final version = json[_versionKey];

    if (version != currentVersion) {
      throw AutomationCatalogueVersionException(version);
    }

    final unpacked = AutomationCatalogueTables.unpack(json);

    return AutomationCatalogue(
      areas: CatalogueJson.objects(
        unpacked,
        _areasKey,
      ).map(AutomationCatalogueArea.fromJson).toList(growable: false),
      groups: CatalogueJson.objects(
        unpacked,
        _groupsKey,
      ).map(AutomationCatalogueGroup.fromJson).toList(growable: false),
      flows: CatalogueJson.objects(
        unpacked,
        _flowsKey,
      ).map(AutomationCatalogueFlow.fromJson).toList(growable: false),
      dateFormats: CatalogueJson.tryText(unpacked, _dateFormatsKey) ?? const {},
      dateValueKeys:
          CatalogueJson.tryText(unpacked, _dateValueKeysKey) ?? const {},
    );
  }

  /// The catalogue as JSON, with its responses and long strings stored once.
  Map<String, Object?> toJson() {
    return AutomationCatalogueTables.pack({
      _versionKey: currentVersion,
      if (areas.isNotEmpty)
        _areasKey: areas.map((area) => area.toJson()).toList(),
      _groupsKey: groups.map((group) => group.toJson()).toList(),
      _flowsKey: flows.map((flow) => flow.toJson()).toList(),
      if (dateFormats.isNotEmpty) _dateFormatsKey: dateFormats,
      if (dateValueKeys.isNotEmpty) _dateValueKeysKey: dateValueKeys,
    });
  }
}
