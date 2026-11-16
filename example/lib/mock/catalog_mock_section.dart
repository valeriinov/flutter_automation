import 'package:flutter_automation_mock/mock_section.dart';

/// {@category Utils}
///
/// Settings of the catalog section of the mock.
final class CatalogMockSettings {
  static const _defaultItemCount = 3;

  /// Number of items the catalog answers with.
  final int itemCount;

  const CatalogMockSettings({this.itemCount = _defaultItemCount});

  /// Reads the settings out of the section JSON.
  factory CatalogMockSettings.fromJson(Map<String, Object?> json) {
    final itemCount = json['itemCount'];

    return CatalogMockSettings(
      itemCount: itemCount is int ? itemCount : _defaultItemCount,
    );
  }

  /// Settings with the given values replaced.
  CatalogMockSettings copyWith({int? itemCount}) {
    return CatalogMockSettings(itemCount: itemCount ?? this.itemCount);
  }

  /// Section JSON of the settings.
  Map<String, Object?> toJson() => {'itemCount': itemCount};
}

/// {@category Utils}
///
/// The catalog section. The file imports no Flutter code, so a flow on the host
/// names its profiles by Dart symbol.
final catalogMockSection = MockSection<CatalogMockSettings>(
  name: 'catalogSection',
  title: AutomationLocalizedText({'en': 'Catalog'}),
  fromJson: CatalogMockSettings.fromJson,
  profiles: {
    'emptyShelf': MockProfile(
      (settings) => settings.copyWith(itemCount: 0),
      title: AutomationLocalizedText({'en': 'Empty shelf'}),
    ),
    'fullShelf': MockProfile(
      (settings) => settings.copyWith(itemCount: 5),
      title: AutomationLocalizedText({'en': 'Full shelf'}),
    ),
  },
);
