import 'package:flutter_automation_mock/mock_feature.dart';
import 'package:flutter_test/flutter_test.dart';

const _feature = MockFeature<_CatalogSettings>(
  name: 'catalog',
  fromJson: _CatalogSettings.fromJson,
  profiles: {
    'empty': {'itemCount': 0},
  },
  fields: [MockField(name: 'itemCount', type: MockFieldType.integer)],
);

void main() {
  group('MockFeature Tests', () {
    _mockFeature_should_buildDefaultsFromAnEmptyObject();
    _mockFeature_should_overrideTheSectionByProfileName();
    _mockFeature_should_throwForAnUnknownProfile();
    _mockFeature_should_overrideTheSectionByValues();
    _mockFeature_should_readItsSectionOutOfTheScenarioJson();
    _mockFeature_should_readDefaultsWhenTheSectionIsMissing();
    _mockFeature_should_describeItsFields();
  });
}

void _mockFeature_should_buildDefaultsFromAnEmptyObject() {
  test('MockFeature should build defaults from an empty object', () {
    expect(_feature.defaults.itemCount, 3);
  });
}

void _mockFeature_should_overrideTheSectionByProfileName() {
  test('MockFeature should override the section by profile name', () {
    final override = _feature.profile('empty');

    expect(override.key, 'catalog');
    expect(override.value, {'itemCount': 0});
  });
}

void _mockFeature_should_throwForAnUnknownProfile() {
  test('MockFeature should throw for an unknown profile', () {
    expect(() => _feature.profile('missing'), throwsArgumentError);
  });
}

void _mockFeature_should_overrideTheSectionByValues() {
  test('MockFeature should override the section by values', () {
    final override = _feature.override({'itemCount': 7});

    expect(override.key, 'catalog');
    expect(override.value, {'itemCount': 7});
  });
}

void _mockFeature_should_readItsSectionOutOfTheScenarioJson() {
  test('MockFeature should read its section out of the scenario json', () {
    final settings = _feature.read({
      'catalog': {'itemCount': 9},
      'other': {'itemCount': 1},
    });

    expect(settings.itemCount, 9);
  });
}

void _mockFeature_should_readDefaultsWhenTheSectionIsMissing() {
  test('MockFeature should read defaults when the section is missing', () {
    final settings = _feature.read({
      'other': {'itemCount': 1},
    });

    expect(settings.itemCount, 3);
  });
}

void _mockFeature_should_describeItsFields() {
  test('MockFeature should describe its fields', () {
    expect(_feature.fields.single.name, 'itemCount');
    expect(_feature.fields.single.type, MockFieldType.integer);
  });
}

final class _CatalogSettings {
  final int itemCount;

  const _CatalogSettings({required this.itemCount});

  factory _CatalogSettings.fromJson(Map<String, Object?> json) {
    final itemCount = json['itemCount'];

    return _CatalogSettings(itemCount: itemCount is int ? itemCount : 3);
  }
}
