import 'package:flutter_automation_mock/mock_section.dart';
import 'package:flutter_test/flutter_test.dart';

final _section = MockSection<_CatalogSettings>(
  name: 'catalog',
  fromJson: _CatalogSettings.fromJson,
  profiles: {'empty': (settings) => settings.copyWith(itemCount: 0)},
);

void main() {
  group('MockSection Tests', () {
    _mockSection_should_buildDefaultsFromAnEmptyObject();
    _mockSection_should_listProfileNamesThroughAnObjectSection();
    _mockSection_should_overrideTheSectionByProfileName();
    _mockSection_should_throwForAnUnknownProfile();
    _mockSection_should_overrideTheSectionByAFunction();
    _mockSection_should_readItsSectionOutOfTheScenarioJson();
    _mockSection_should_readDefaultsWhenTheSectionIsMissing();
  });
}

void _mockSection_should_buildDefaultsFromAnEmptyObject() {
  test('MockSection should build defaults from an empty object', () {
    expect(_section.defaults.itemCount, 3);
  });
}

void _mockSection_should_listProfileNamesThroughAnObjectSection() {
  test('MockSection should list profile names through an object section', () {
    final MockSection<Object?> section = _section;

    expect(section.profileNames, ['empty']);
  });
}

void _mockSection_should_overrideTheSectionByProfileName() {
  test('MockSection should override the section by profile name', () {
    final override = _section.profile('empty');

    expect(override.key, 'catalog');
    expect(MockScenario([override]).toJson(), {
      'catalog': {'itemCount': 0},
    });
  });
}

void _mockSection_should_throwForAnUnknownProfile() {
  test('MockSection should throw for an unknown profile', () {
    expect(() => _section.profile('missing'), throwsArgumentError);
  });
}

void _mockSection_should_overrideTheSectionByAFunction() {
  test('MockSection should override the section by a function', () {
    final override = _section.override(
      (settings) => settings.copyWith(itemCount: 7),
    );

    expect(override.key, 'catalog');
    expect(MockScenario([override]).toJson(), {
      'catalog': {'itemCount': 7},
    });
  });
}

void _mockSection_should_readItsSectionOutOfTheScenarioJson() {
  test('MockSection should read its section out of the scenario json', () {
    final settings = _section.read({
      'catalog': {'itemCount': 9},
      'other': {'itemCount': 1},
    });

    expect(settings.itemCount, 9);
  });
}

void _mockSection_should_readDefaultsWhenTheSectionIsMissing() {
  test('MockSection should read defaults when the section is missing', () {
    final settings = _section.read({
      'other': {'itemCount': 1},
    });

    expect(settings.itemCount, 3);
  });
}

final class _CatalogSettings {
  final int itemCount;

  const _CatalogSettings({required this.itemCount});

  factory _CatalogSettings.fromJson(Map<String, Object?> json) {
    final itemCount = json['itemCount'];

    return _CatalogSettings(itemCount: itemCount is int ? itemCount : 3);
  }

  _CatalogSettings copyWith({int? itemCount}) =>
      _CatalogSettings(itemCount: itemCount ?? this.itemCount);

  Map<String, Object?> toJson() => {'itemCount': itemCount};
}
