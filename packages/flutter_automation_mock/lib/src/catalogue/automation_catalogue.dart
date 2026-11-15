import 'package:flutter_automation_mock/src/catalogue/automation_catalogue_flow.dart';
import 'package:flutter_automation_mock/src/catalogue/catalogue_json.dart';

/// {@category Utils}
///
/// A group of flows with its caption, by locale.
final class AutomationCatalogueGroup {
  static const _nameKey = 'name';
  static const _titleKey = 'title';

  /// Name the flows refer to.
  final String name;

  /// Caption by locale.
  final Map<String, String> title;

  const AutomationCatalogueGroup({required this.name, required this.title});

  /// Reads the group out of [json].
  factory AutomationCatalogueGroup.fromJson(Map<String, Object?> json) {
    return AutomationCatalogueGroup(
      name: CatalogueJson.tryString(json, _nameKey) ?? '',
      title: CatalogueJson.tryText(json, _titleKey) ?? const {},
    );
  }

  /// The group as JSON.
  Map<String, Object?> toJson() => {_nameKey: name, _titleKey: title};
}

/// {@category Utils}
///
/// The flows a tester can walk, the groups that sort them, the requests each
/// step sends, and the date settings a date finder of a step needs.
///
/// The runner writes the catalogue as a JSON file out of the flows and the
/// recordings of their runs. The panel and the player read it. The library
/// imports no Flutter code, so the runner reads it on the host.
final class AutomationCatalogue {
  static const _groupsKey = 'groups';
  static const _flowsKey = 'flows';
  static const _dateFormatsKey = 'dateFormats';
  static const _dateValueKeysKey = 'dateValueKeys';

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
    this.groups = const [],
    this.flows = const [],
    this.dateFormats = const {},
    this.dateValueKeys = const {},
  });

  /// Reads the catalogue out of [json].
  factory AutomationCatalogue.fromJson(Map<String, Object?> json) {
    return AutomationCatalogue(
      groups: CatalogueJson.objects(
        json,
        _groupsKey,
      ).map(AutomationCatalogueGroup.fromJson).toList(growable: false),
      flows: CatalogueJson.objects(
        json,
        _flowsKey,
      ).map(AutomationCatalogueFlow.fromJson).toList(growable: false),
      dateFormats: CatalogueJson.tryText(json, _dateFormatsKey) ?? const {},
      dateValueKeys: CatalogueJson.tryText(json, _dateValueKeysKey) ?? const {},
    );
  }

  /// The catalogue as JSON.
  Map<String, Object?> toJson() {
    return {
      _groupsKey: groups.map((group) => group.toJson()).toList(),
      _flowsKey: flows.map((flow) => flow.toJson()).toList(),
      if (dateFormats.isNotEmpty) _dateFormatsKey: dateFormats,
      if (dateValueKeys.isNotEmpty) _dateValueKeysKey: dateValueKeys,
    };
  }
}
