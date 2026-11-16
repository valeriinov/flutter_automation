import 'package:flutter_automation_mock/mock_section.dart';
import 'package:flutter_test/flutter_test.dart';

final _section = MockSection<_CatalogSettings>(
  name: 'catalog',
  title: AutomationLocalizedText({'en': 'Catalog'}),
  fromJson: _CatalogSettings.fromJson,
  profiles: {
    'empty': MockProfile(
      (settings) => settings.copyWith(itemCount: 0),
      title: AutomationLocalizedText({'en': 'Empty'}),
      description: AutomationLocalizedText({'en': 'No items'}),
    ),
  },
);

void main() {
  group('MockSection Tests', () {
    _mockSection_should_buildDefaultsFromAnEmptyObject();
    _mockSection_should_listProfileNamesThroughAnObjectSection();
    _mockSection_should_overrideTheSectionByProfileName();
    _mockSection_should_keepTheTextsOfAProfile();
    _mockSection_should_applyAProfileThroughAnObjectSection();
    _mockSection_should_throwForAnUnknownProfile();
    _mockSection_should_overrideTheSectionByAFunction();
    _mockSection_should_readItsSectionOutOfTheScenarioJson();
    _mockSection_should_readDefaultsWhenTheSectionIsMissing();
    _mockSection_should_flagAChangeOfARestartKey();
    _mockSection_should_ignoreAChangeOfAKeyThatNeedsNoRestart();
    _mockSection_should_treatAnAbsentKeyAndItsDefaultAsEqual();
    _mockSection_should_listAKeyThatOnlyAProfileWrites();
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

void _mockSection_should_keepTheTextsOfAProfile() {
  test('MockSection should keep the texts of a profile', () {
    final profile = _section.profiles['empty'];

    expect(_section.title.resolve('en'), 'Catalog');
    expect(profile?.title.resolve('en'), 'Empty');
    expect(profile?.description?.resolve('en'), 'No items');
  });
}

void _mockSection_should_applyAProfileThroughAnObjectSection() {
  test('MockSection should apply a profile through an object section', () {
    final MockSection<Object?> section = _section;
    final profile = section.profiles['empty'];
    final settings = profile?.update(section.defaults);

    expect((settings as _CatalogSettings?)?.itemCount, 0);
  });
}

void _mockSection_should_listAKeyThatOnlyAProfileWrites() {
  test('MockSection should list a key that only a profile writes', () {
    final section = MockSection<Map<String, Object?>>(
      name: 'flags',
      title: AutomationLocalizedText({'en': 'Flags'}),
      fromJson: (json) => json,
      profiles: {
        'blocked': MockProfile(
          (settings) => {...settings, 'isBlocked': true},
          title: AutomationLocalizedText({'en': 'Blocked'}),
        ),
      },
    );

    expect(section.settingsKeys, {'isBlocked'});
    expect(_section.settingsKeys, {'itemCount'});
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

void _mockSection_should_flagAChangeOfARestartKey() {
  test('MockSection should flag a change of a restart key', () {
    final changed = _restartSection.changesRestartKey(const {}, {
      'catalog': {'itemCount': 0},
    });

    expect(changed, isTrue);
  });
}

void _mockSection_should_ignoreAChangeOfAKeyThatNeedsNoRestart() {
  test('MockSection should ignore a change of a key that needs no restart', () {
    final changed = _section.changesRestartKey(const {}, {
      'catalog': {'itemCount': 0},
    });

    expect(changed, isFalse);
  });
}

void _mockSection_should_treatAnAbsentKeyAndItsDefaultAsEqual() {
  test('MockSection should treat an absent key and its default as equal', () {
    final changed = _restartSection.changesRestartKey(const {}, {
      'catalog': {'itemCount': 3},
    });

    expect(changed, isFalse);
  });
}

final _restartSection = MockSection<_CatalogSettings>(
  name: 'catalog',
  title: AutomationLocalizedText({'en': 'Catalog'}),
  fromJson: _CatalogSettings.fromJson,
  restartKeys: {'itemCount'},
);

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
