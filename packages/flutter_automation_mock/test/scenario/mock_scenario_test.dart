import 'package:flutter_automation_mock/mock_section.dart';
import 'package:flutter_test/flutter_test.dart';

final _catalog = MockSection<_CatalogSettings>(
  name: 'catalog',
  fromJson: _CatalogSettings.fromJson,
  profiles: {'empty': (settings) => settings.copyWith(itemCount: 0)},
);
final _profile = MockSection<_ProfileSettings>(
  name: 'profile',
  fromJson: _ProfileSettings.fromJson,
  profiles: {'signedOut': (settings) => settings.copyWith(isSignedIn: false)},
);

void main() {
  group('MockScenario Tests', () {
    _mockScenario_should_giveASparseMapOfTheOverridesOnly();
    _mockScenario_should_keepKeysInFirstUseOrder();
    _mockScenario_should_mergeNestedObjectsKeyByKey();
    _mockScenario_should_replaceAScalarWithTheLaterValue();
    _mockScenario_should_clearAValueTheEarlierOverrideSet();
    _mockScenario_should_dropAKeyThatEqualsItsDefault();
    _mockScenario_should_dropACollectionThatEqualsItsDefault();
    _mockScenario_should_readTheSettingsBuiltSoFar();
    _mockScenario_should_keepTheOrderOfTheOverrides();
    _mockScenario_should_roundTripThroughJson();
    _mockScenario_should_applyTheTransportOverrides();
    _mockScenario_should_mergeAnotherScenarioAfterItsOwn();
    _mockScenario_should_readTheSettingsOfASection();
  });
}

void _mockScenario_should_giveASparseMapOfTheOverridesOnly() {
  test('MockScenario should give a sparse map of the overrides only', () {
    final scenario = MockScenario([_catalog.profile('empty')]);

    expect(scenario.toJson(), {
      'catalog': {'itemCount': 0},
    });
  });
}

void _mockScenario_should_keepKeysInFirstUseOrder() {
  test('MockScenario should keep keys in first use order', () {
    final scenario = MockScenario([
      _profile.profile('signedOut'),
      _catalog.profile('empty'),
      _profile.override((settings) => settings.copyWith(name: 'Sample')),
    ]);

    expect(scenario.toJson().keys.toList(), ['profile', 'catalog']);
    expect(
      (scenario.toJson()['profile'] as Map<String, Object?>).keys.toList(),
      ['isSignedIn', 'name'],
    );
  });
}

void _mockScenario_should_mergeNestedObjectsKeyByKey() {
  test('MockScenario should merge untyped nested objects key by key', () {
    final scenario = MockScenario([
      MockOverride.failures({
        '/items': {'statusCode': 500, 'message': 'down'},
      }),
      MockOverride.failures({
        '/items': {'statusCode': 503},
      }),
    ]);

    expect(scenario.toJson(), {
      'failures': {
        '/items': {'statusCode': 503, 'message': 'down'},
      },
    });
  });
}

void _mockScenario_should_replaceAScalarWithTheLaterValue() {
  test('MockScenario should replace a scalar with the later value', () {
    final scenario = MockScenario([
      _catalog.override((settings) => settings.copyWith(itemCount: 1)),
      _catalog.override((settings) => settings.copyWith(itemCount: 5)),
    ]);

    expect(scenario.toJson(), {
      'catalog': {'itemCount': 5},
    });
  });
}

void _mockScenario_should_clearAValueTheEarlierOverrideSet() {
  test('MockScenario should clear a value the earlier override set', () {
    final scenario = MockScenario([
      _catalog.override((settings) => settings.copyWith(label: 'Shelf')),
      _catalog.override((settings) => settings.withoutLabel()),
    ]);

    expect(scenario.toJson(), {'catalog': <String, Object?>{}});
  });
}

void _mockScenario_should_dropAKeyThatEqualsItsDefault() {
  test('MockScenario should drop a key that equals its default', () {
    final scenario = MockScenario([
      _catalog.override(
        (settings) => settings.copyWith(itemCount: 3, label: 'Shelf'),
      ),
    ]);

    expect(scenario.toJson(), {
      'catalog': {'label': 'Shelf'},
    });
  });
}

void _mockScenario_should_dropACollectionThatEqualsItsDefault() {
  test('MockScenario should drop a collection that equals its default', () {
    final scenario = MockScenario([
      _catalog.override((settings) => settings.copyWith(tags: ['a', 'b'])),
      _catalog.override((settings) => settings.copyWith(tags: ['x'])),
      _catalog.override((settings) => settings.copyWith(tags: ['a', 'b'])),
    ]);

    expect(scenario.toJson(), {'catalog': <String, Object?>{}});
  });
}

void _mockScenario_should_readTheSettingsBuiltSoFar() {
  test('MockScenario should read the settings built so far', () {
    final scenario = MockScenario([
      _catalog.override((settings) => settings.copyWith(itemCount: 4)),
      _catalog.override(
        (settings) => settings.copyWith(itemCount: settings.itemCount + 1),
      ),
    ]);

    expect(scenario.toJson(), {
      'catalog': {'itemCount': 5},
    });
  });
}

void _mockScenario_should_roundTripThroughJson() {
  test('MockScenario should round trip through json', () {
    const json = <String, Object?>{
      'latency': 'fast',
      'catalog': {'itemCount': 0},
    };

    expect(MockScenario.fromJson(json).toJson(), json);
  });
}

void _mockScenario_should_applyTheTransportOverrides() {
  test('MockScenario should apply the transport overrides', () {
    final scenario = MockScenario([
      MockOverride.latency(MockLatencyProfile.fast),
      MockOverride.latencySeed(4),
      MockOverride.failures({
        '/items': {'statusCode': 500},
      }),
    ]);

    expect(scenario.toJson(), {
      'latency': 'fast',
      'latencySeed': 4,
      'failures': {
        '/items': {'statusCode': 500},
      },
    });
  });
}

void _mockScenario_should_mergeAnotherScenarioAfterItsOwn() {
  test('MockScenario should merge another scenario after its own', () {
    final scenario = MockScenario([
      _catalog.override((settings) => settings.copyWith(itemCount: 1)),
    ]).merge(MockScenario([_catalog.profile('empty')]));

    expect(scenario.toJson(), {
      'catalog': {'itemCount': 0},
    });
  });
}

void _mockScenario_should_readTheSettingsOfASection() {
  test('MockScenario should read the settings of a section', () {
    final scenario = MockScenario([_catalog.profile('empty')]);

    expect(scenario.settingsOf(_catalog).itemCount, 0);
    expect(scenario.settingsOf(_profile).isSignedIn, isTrue);
  });
}

void _mockScenario_should_keepTheOrderOfTheOverrides() {
  test('MockScenario should keep the order of the overrides', () {
    final scenario = MockScenario([
      MockOverride.latency(MockLatencyProfile.fast),
      _catalog.override((settings) => settings.copyWith(itemCount: 2)),
      MockOverride.latency(MockLatencyProfile.realistic),
    ]);

    expect(scenario.toJson(), {
      'latency': 'realistic',
      'catalog': {'itemCount': 2},
    });
  });
}

final class _CatalogSettings {
  final int itemCount;
  final String? label;
  final List<String> tags;

  const _CatalogSettings({
    required this.itemCount,
    required this.label,
    required this.tags,
  });

  factory _CatalogSettings.fromJson(Map<String, Object?> json) {
    final itemCount = json['itemCount'];
    final label = json['label'];
    final tags = json['tags'];

    return _CatalogSettings(
      itemCount: itemCount is int ? itemCount : 3,
      label: label is String ? label : null,
      tags: tags is List<Object?> ? tags.cast<String>() : const ['a', 'b'],
    );
  }

  _CatalogSettings copyWith({
    int? itemCount,
    String? label,
    List<String>? tags,
  }) {
    return _CatalogSettings(
      itemCount: itemCount ?? this.itemCount,
      label: label ?? this.label,
      tags: tags ?? this.tags,
    );
  }

  _CatalogSettings withoutLabel() {
    return _CatalogSettings(itemCount: itemCount, label: null, tags: tags);
  }

  Map<String, Object?> toJson() => {
    'itemCount': itemCount,
    'label': ?label,
    'tags': tags,
  };
}

final class _ProfileSettings {
  final bool isSignedIn;
  final String? name;

  const _ProfileSettings({required this.isSignedIn, required this.name});

  factory _ProfileSettings.fromJson(Map<String, Object?> json) {
    final isSignedIn = json['isSignedIn'];
    final name = json['name'];

    return _ProfileSettings(
      isSignedIn: isSignedIn is bool ? isSignedIn : true,
      name: name is String ? name : null,
    );
  }

  _ProfileSettings copyWith({bool? isSignedIn, String? name}) {
    return _ProfileSettings(
      isSignedIn: isSignedIn ?? this.isSignedIn,
      name: name ?? this.name,
    );
  }

  Map<String, Object?> toJson() => {'isSignedIn': isSignedIn, 'name': ?name};
}
