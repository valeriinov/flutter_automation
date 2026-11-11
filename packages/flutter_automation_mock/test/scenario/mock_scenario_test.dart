import 'package:flutter_automation_mock/mock_feature.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = MockFeature<Map<String, Object?>>(
  name: 'catalog',
  fromJson: _readJson,
  profiles: {
    'empty': {'itemCount': 0},
  },
);
const _profile = MockFeature<Map<String, Object?>>(
  name: 'profile',
  fromJson: _readJson,
  profiles: {
    'signedOut': {'isSignedIn': false},
  },
);

void main() {
  group('MockScenario Tests', () {
    _mockScenario_should_giveASparseMapOfTheOverridesOnly();
    _mockScenario_should_keepKeysInFirstUseOrder();
    _mockScenario_should_mergeNestedObjectsKeyByKey();
    _mockScenario_should_replaceAScalarWithTheLaterValue();
    _mockScenario_should_roundTripThroughJson();
    _mockScenario_should_applyTheTransportOverrides();
    _mockScenario_should_mergeAnotherScenarioAfterItsOwn();
    _mockScenario_should_readTheSettingsOfAFeature();
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
      _profile.override({'name': 'Sample'}),
    ]);

    expect(scenario.toJson().keys.toList(), ['profile', 'catalog']);
    expect(
      (scenario.toJson()['profile'] as Map<String, Object?>).keys.toList(),
      ['isSignedIn', 'name'],
    );
  });
}

void _mockScenario_should_mergeNestedObjectsKeyByKey() {
  test('MockScenario should merge nested objects key by key', () {
    final scenario = MockScenario([
      _catalog.override({
        'filter': {'kind': 'all', 'page': 1},
      }),
      _catalog.override({
        'filter': {'page': 2},
      }),
    ]);

    expect(scenario.toJson(), {
      'catalog': {
        'filter': {'kind': 'all', 'page': 2},
      },
    });
  });
}

void _mockScenario_should_replaceAScalarWithTheLaterValue() {
  test('MockScenario should replace a scalar with the later value', () {
    final scenario = MockScenario([
      _catalog.override({'itemCount': 1}),
      _catalog.override({'itemCount': 5}),
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
      MockScenario.latency(MockLatencyProfile.fast),
      MockScenario.latencySeed(4),
      MockScenario.failures({
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
      _catalog.override({'itemCount': 1}),
    ]).merge(MockScenario([_catalog.profile('empty')]));

    expect(scenario.toJson(), {
      'catalog': {'itemCount': 0},
    });
  });
}

void _mockScenario_should_readTheSettingsOfAFeature() {
  test('MockScenario should read the settings of a feature', () {
    final scenario = MockScenario([_catalog.profile('empty')]);

    expect(scenario.settingsOf(_catalog), {'itemCount': 0});
    expect(scenario.settingsOf(_profile), isEmpty);
  });
}

Map<String, Object?> _readJson(Map<String, Object?> json) => json;
