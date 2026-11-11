import 'package:flutter_automation_mock/mock_feature.dart';

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
}

/// {@category Utils}
///
/// The catalog section. The file imports no Flutter code, so a flow on the host
/// names its profiles by Dart symbol.
const catalogMockFeature = MockFeature<CatalogMockSettings>(
  name: 'catalogSection',
  fromJson: CatalogMockSettings.fromJson,
  profiles: {
    'emptyShelf': {'itemCount': 0},
    'fullShelf': {'itemCount': 5},
  },
  fields: [MockField(name: 'itemCount', type: MockFieldType.integer)],
);
