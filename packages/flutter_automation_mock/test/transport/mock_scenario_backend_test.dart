import 'package:fake_async/fake_async.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/test_mock_api.dart';

const _firstPath = '/first';
const _secondPath = '/second';
const _drawCount = 12;
const _beyondEveryDelay = Duration(seconds: 10);

void main() {
  group('MockScenarioBackend Tests', () {
    _mockScenarioBackend_should_buildItsEndpointsOnCreation();
    _mockScenarioBackend_should_changeItsEndpointsOnRebuild();
    _mockScenarioBackend_should_readTheFailuresFromTheScenarioOnEachRequest();
    _mockScenarioBackend_should_holdOneLatencyBetweenRebuilds();
    _mockScenarioBackend_should_giveTwoRequestsInARowDifferentDelays();
    _mockScenarioBackend_should_readTheLatencyOfTheScenarioOnRebuild();
    _mockScenarioBackend_should_buildTheFailureBodyWithTheProject();
  });
}

void _mockScenarioBackend_should_buildItsEndpointsOnCreation() {
  test('MockScenarioBackend should build its endpoints on creation', () {
    final sut = _createBackend(
      readScenario: () => const MockScenario([]),
      buildApis: () => [_apiOf(_firstPath)],
    );

    expect(sut.endpointResolver.tryResolve(_firstPath), isNotNull);
    expect(sut.endpointResolver.tryResolve(_secondPath), isNull);
  });
}

void _mockScenarioBackend_should_changeItsEndpointsOnRebuild() {
  test('MockScenarioBackend should change its endpoints on rebuild', () {
    String path = _firstPath;
    final sut = _createBackend(
      readScenario: () => const MockScenario([]),
      buildApis: () => [_apiOf(path)],
    );

    path = _secondPath;

    expect(sut.endpointResolver.tryResolve(_secondPath), isNull);
    sut.rebuild();
    expect(sut.endpointResolver.tryResolve(_secondPath), isNotNull);
    expect(sut.endpointResolver.tryResolve(_firstPath), isNull);
  });
}

void _mockScenarioBackend_should_readTheFailuresFromTheScenarioOnEachRequest() {
  test('MockScenarioBackend should read the failures on each request', () {
    MockScenario scenario = const MockScenario([]);
    final sut = _createBackend(
      readScenario: () => scenario,
      buildApis: () => const [],
    );

    expect(sut.failures, isEmpty);

    scenario = MockScenario([
      MockOverride.failures({
        _firstPath: {'statusCode': 503},
      }),
    ]);

    expect(sut.failures.keys, [_firstPath]);
    expect(sut.failures[_firstPath]?.statusCode, 503);
  });
}

void _mockScenarioBackend_should_holdOneLatencyBetweenRebuilds() {
  test('MockScenarioBackend should hold one latency between rebuilds', () {
    final sut = _createBackend(
      readScenario: () => const MockScenario([]),
      buildApis: () => const [],
    );
    final latency = sut.latency;

    expect(identical(sut.latency, latency), isTrue);
    sut.rebuild();
    expect(identical(sut.latency, latency), isFalse);
  });
}

void _mockScenarioBackend_should_giveTwoRequestsInARowDifferentDelays() {
  test('MockScenarioBackend should give two requests different delays', () {
    fakeAsync((async) {
      final sut = _createBackend(
        readScenario: () => const MockScenario([]),
        buildApis: () => const [],
      );
      final delays = <Duration>[];

      for (int index = 0; index < _drawCount; index++) {
        delays.add(_measure(async, sut.latency));
      }

      expect(delays.toSet().length, greaterThan(1));
    });
  });
}

void _mockScenarioBackend_should_readTheLatencyOfTheScenarioOnRebuild() {
  test('MockScenarioBackend should read the latency on rebuild', () {
    fakeAsync((async) {
      MockScenario scenario = const MockScenario([]);
      final sut = _createBackend(
        readScenario: () => scenario,
        buildApis: () => const [],
      );

      expect(sut.latency.profile, MockLatencyProfile.realistic);

      scenario = MockScenario([MockOverride.latency(MockLatencyProfile.fast)]);

      sut.rebuild();
      expect(sut.latency.profile, MockLatencyProfile.fast);
      expect(_measure(async, sut.latency), Duration.zero);
    });
  });
}

void _mockScenarioBackend_should_buildTheFailureBodyWithTheProject() {
  test(
    'MockScenarioBackend should build the failure body with the project',
    () {
      final sut = _createBackend(
        readScenario: () => const MockScenario([]),
        buildApis: () => const [],
      );

      expect(sut.buildFailureBody(const MockApiFailure(statusCode: 418)), {
        'status': 418,
      });
    },
  );
}

MockScenarioBackend _createBackend({
  required MockScenario Function() readScenario,
  required List<MockApi> Function() buildApis,
}) {
  return MockScenarioBackend(
    readScenario: readScenario,
    buildApis: buildApis,
    buildFailureBody: (failure) => {'status': failure.statusCode},
  );
}

MockApi _apiOf(String path) {
  return TestMockApi(
    endpoints: [
      MockApiEndpoint(
        path: path,
        respond: (request) => const MockApiResponse(body: {}),
      ),
    ],
  );
}

Duration _measure(FakeAsync async, MockLatency latency) {
  final start = async.getClock(DateTime(2026)).now();
  late DateTime end;

  latency.waitOut().then((_) => end = async.getClock(DateTime(2026)).now());
  async.elapse(_beyondEveryDelay);

  return end.difference(start);
}
