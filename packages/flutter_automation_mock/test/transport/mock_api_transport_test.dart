import 'dart:io';

import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/test_mock_api.dart';

const _ownedPath = '/items/list';
const _failingPath = '/items/create';
const _unownedPath = '/records/list';

final _journal = MockJournal();
final _endpointResolver = MockApiEndpointResolver([
  TestMockApi(
    feature: TestSection.alpha,
    endpoints: [
      MockApiEndpoint(path: _ownedPath, respond: _respondOk),
      MockApiEndpoint(path: _failingPath, respond: _respondOk),
    ],
  ),
]);
final _transport = MockApiTransport(
  runtime: _TestRuntime(
    endpointResolver: _endpointResolver,
    failures: {
      _failingPath: const MockApiFailure(
        statusCode: HttpStatus.serviceUnavailable,
      ),
    },
  ),
  journal: _journal,
);
final _disconnectedTransport = MockApiTransport(
  runtime: _TestRuntime(
    endpointResolver: _endpointResolver,
    failures: {_ownedPath: const MockApiFailure(isConnectionError: true)},
  ),
  journal: _journal,
);

void main() {
  _setup();
  group('MockApiTransport Tests', () {
    _mockApiTransport_should_ownThePathsOfItsEndpoints();
    _mockApiTransport_should_answerWithThePayloadOfTheEndpoint();
    _mockApiTransport_should_answerADeclaredFailure();
    _mockApiTransport_should_throwAConnectionFailure();
    _mockApiTransport_should_recordTheRequestWithItsStatus();
    _mockApiTransport_should_recordAConnectionFailureAsAnswered();
    _mockApiTransport_should_throwForAPathNoEndpointOwns();
  });
}

void _setup() {
  tearDown(() {
    _journal.clear();
  });
}

void _mockApiTransport_should_ownThePathsOfItsEndpoints() {
  test('MockApiTransport should own the paths of its endpoints', () {
    expect(_transport.ownsPath(_ownedPath), isTrue);
    expect(_transport.ownsPath(_unownedPath), isFalse);
  });
}

void _mockApiTransport_should_answerWithThePayloadOfTheEndpoint() {
  test(
    'MockApiTransport should answer with the payload of the endpoint',
    () async {
      final response = await _transport.answer(
        const MockApiRequest(path: _ownedPath, body: {}),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body, {'ok': true});
    },
  );
}

void _mockApiTransport_should_answerADeclaredFailure() {
  test('MockApiTransport should answer a declared failure', () async {
    final response = await _transport.answer(
      const MockApiRequest(path: _failingPath, body: {}),
    );

    expect(response.statusCode, HttpStatus.serviceUnavailable);
    expect(response.body, {'failed': true});
  });
}

void _mockApiTransport_should_throwAConnectionFailure() {
  test('MockApiTransport should throw a connection failure', () {
    final answer = _disconnectedTransport.answer(
      const MockApiRequest(path: _ownedPath, body: {}),
    );

    expect(answer, throwsA(isA<MockConnectionFailure>()));
  });
}

void _mockApiTransport_should_recordTheRequestWithItsStatus() {
  test('MockApiTransport should record the request with its status', () async {
    await _transport.answer(
      const MockApiRequest(
        path: _ownedPath,
        method: 'POST',
        body: {'page': 1},
        acceptLanguage: 'en',
      ),
    );

    expect(_journal.readAndClear(), [
      {
        'seq': 0,
        'kind': 'request',
        'method': 'POST',
        'path': _ownedPath,
        'body': {'page': 1},
        'acceptLanguage': 'en',
        'status': HttpStatus.ok,
        'response': {'ok': true},
      },
    ]);
  });
}

void _mockApiTransport_should_recordAConnectionFailureAsAnswered() {
  test(
    'MockApiTransport should record a connection failure as answered',
    () async {
      await expectLater(
        _disconnectedTransport.answer(
          const MockApiRequest(path: _ownedPath, body: {}),
        ),
        throwsA(isA<MockConnectionFailure>()),
      );

      final record = _journal.readAndClear().single;

      expect(_journal.requestsAwaitingResponse, isEmpty);
      expect(record, containsPair('status', 0));
      expect(record.containsKey('response'), isFalse);
    },
  );
}

void _mockApiTransport_should_throwForAPathNoEndpointOwns() {
  test('MockApiTransport should throw for a path no endpoint owns', () {
    final answer = _transport.answer(
      const MockApiRequest(path: _unownedPath, body: {}),
    );

    expect(answer, throwsStateError);
  });
}

MockApiResponse _respondOk(MockApiRequest _) =>
    const MockApiResponse(body: {'ok': true});

final class _TestRuntime implements MockTransportRuntime {
  @override
  final MockApiEndpointResolver endpointResolver;

  @override
  final Map<String, MockApiFailure> failures;

  @override
  final MockLatency latency = MockLatency(
    profile: MockLatencyProfile.fast,
    seed: 1,
  );

  _TestRuntime({required this.endpointResolver, this.failures = const {}});

  @override
  Map<String, Object?> buildFailureBody(MockApiFailure failure) {
    return {'failed': true};
  }
}
