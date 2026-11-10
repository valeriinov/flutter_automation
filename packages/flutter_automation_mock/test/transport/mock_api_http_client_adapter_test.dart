import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_endpoint.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_failure.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_request.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_response.dart';
import 'package:flutter_automation_mock/src/state/mock_journal.dart';

import 'package:flutter_automation_mock/src/transport/mock_api_endpoint_resolver.dart';
import 'package:flutter_automation_mock/src/transport/mock_api_http_client_adapter.dart';
import 'package:flutter_automation_mock/src/transport/mock_latency.dart';
import 'package:flutter_automation_mock/src/transport/mock_latency_profile.dart';
import 'package:flutter_automation_mock/src/transport/mock_transport_runtime.dart';
import '../test_utils/test_http_client_adapter.dart';
import '../test_utils/test_mock_api.dart';

const _baseUrl = 'https://example.test/app';
const _ownedPath = '/items/list/by-owner';
const _idPath = '/items/details';
const _unownedPath = '/records/list/by-viewer';
const _failingPath = '/items/create';
const _filePath = '/files/echo';
const _unownedFilePath = '/files/unowned';
const _imageContentType = 'image/jpeg';
const _fileLength = 2500;
const _byteValueCount = 256;
const _itemId = 42;
const _payloadKey = 'echoedPathId';
const _latencySeed = 1;
const _failureCodeKey = 'code';
const _failureTextKey = 'text';
const _requestQuery = {'page': 1};
const _acceptLanguage = 'en';
const _requestBody = {'itemId': _itemId, 'description': 'Sample'};
const _failure = MockApiFailure(
  statusCode: HttpStatus.serviceUnavailable,
  errorCode: 'denied',
  message: 'Items are unavailable.',
);

final _fileBytes = Uint8List.fromList(
  List.generate(_fileLength, (index) => index % _byteValueCount),
);
final _networkAdapter = TestHttpClientAdapter(onFetch: _respondEmpty);
final _journal = MockJournal();
final _endpointResolver = MockApiEndpointResolver([
  TestMockApi(
    feature: TestSection.alpha,
    endpoints: [
      MockApiEndpoint(path: _ownedPath, respond: _respondPathId),
      MockApiEndpoint(path: _idPath, respond: _respondPathId, hasPathId: true),
      MockApiEndpoint(path: _failingPath, respond: _respondServerError),
      MockApiEndpoint(path: _filePath, respond: _respondBytes),
    ],
  ),
]);
final _dio = Dio(BaseOptions(baseUrl: _baseUrl))
  ..httpClientAdapter = MockApiHttpClientAdapter(
    runtime: _TestMockRuntime(endpointResolver: _endpointResolver),
    networkAdapter: _networkAdapter,
    journal: _journal,
  );

final _failingDio = Dio(BaseOptions(baseUrl: _baseUrl))
  ..httpClientAdapter = MockApiHttpClientAdapter(
    runtime: _TestMockRuntime(
      failures: {_ownedPath: _failure},
      endpointResolver: _endpointResolver,
    ),
    networkAdapter: _networkAdapter,
    journal: _journal,
  );

final _idFailingDio = Dio(BaseOptions(baseUrl: _baseUrl))
  ..httpClientAdapter = MockApiHttpClientAdapter(
    runtime: _TestMockRuntime(
      failures: {_idPath: _failure},
      endpointResolver: _endpointResolver,
    ),
    networkAdapter: _networkAdapter,
    journal: _journal,
  );

final _disconnectedDio = Dio(BaseOptions(baseUrl: _baseUrl))
  ..httpClientAdapter = MockApiHttpClientAdapter(
    runtime: _TestMockRuntime(
      failures: {_ownedPath: MockApiFailure(isConnectionError: true)},
      endpointResolver: _endpointResolver,
    ),
    networkAdapter: _networkAdapter,
    journal: _journal,
  );

final _delayedAdapter = MockApiHttpClientAdapter(
  runtime: _TestMockRuntime(
    latencyProfile: MockLatencyProfile.realistic,
    endpointResolver: _endpointResolver,
  ),
  networkAdapter: _networkAdapter,
  journal: _journal,
);

void main() {
  _setup();
  group('MockApiHttpClientAdapter Tests', () {
    _mockApiHttpClientAdapter_should_answerAnOwnedPathWithoutTheNetwork();
    _mockApiHttpClientAdapter_should_readThePathIdOfTheRequest();
    _mockApiHttpClientAdapter_should_passAnUnownedPathToTheNetwork();
    _mockApiHttpClientAdapter_should_keepTheStatusCodeOfTheResponse();
    _mockApiHttpClientAdapter_should_recordAnOwnedRequestWithItsStatus();
    _mockApiHttpClientAdapter_should_recordTheAcceptLanguageOfTheRequest();
    _mockApiHttpClientAdapter_should_recordTheDecodedBodyOfTheAnswer();
    _mockApiHttpClientAdapter_should_recordTheAnswerOfADeclaredFailure();
    _mockApiHttpClientAdapter_should_failAnIdPathByItsEndpointFailure();
    _mockApiHttpClientAdapter_should_recordTheRequestBeforeItsDelay();
    _mockApiHttpClientAdapter_should_leaveAnUnownedRequestOutOfTheJournal();
    _mockApiHttpClientAdapter_should_readABinaryBodyOffTheRequestStream();
    _mockApiHttpClientAdapter_should_answerBytesWithTheirContentType();
    _mockApiHttpClientAdapter_should_recordTheLengthOfABinaryBody();
    _mockApiHttpClientAdapter_should_passAnUnreadStreamToTheNetwork();
    _mockApiHttpClientAdapter_should_failAConnectionErrorAsDioDoes();
    _mockApiHttpClientAdapter_should_recordAConnectionErrorAsAnswered();
  });
}

void _setup() {
  tearDown(() {
    _networkAdapter.requestOptions.clear();
    _networkAdapter.requestStreams.clear();
    _journal.clear();
  });
}

void _mockApiHttpClientAdapter_should_answerAnOwnedPathWithoutTheNetwork() {
  test(
    'MockApiHttpClientAdapter should answer an owned path without the network',
    () async {
      final response = await _dio.get<Map<String, Object?>>(_ownedPath);

      expect(response.statusCode, HttpStatus.ok);
      expect(_networkAdapter.requestOptions, isEmpty);
    },
  );
}

void _mockApiHttpClientAdapter_should_readThePathIdOfTheRequest() {
  test(
    'MockApiHttpClientAdapter should read the path id of the request',
    () async {
      final response = await _dio.get<Map<String, Object?>>(
        '$_idPath/$_itemId',
      );

      expect(response.data?[_payloadKey], _itemId);
    },
  );
}

void _mockApiHttpClientAdapter_should_passAnUnownedPathToTheNetwork() {
  test(
    'MockApiHttpClientAdapter should pass an unowned path to the network',
    () async {
      await _dio.get<Map<String, Object?>>(_unownedPath);

      expect(_networkAdapter.requestOptions.map((options) => options.path), [
        _unownedPath,
      ]);
    },
  );
}

void _mockApiHttpClientAdapter_should_keepTheStatusCodeOfTheResponse() {
  test(
    'MockApiHttpClientAdapter should keep the status code of the response',
    () async {
      final response = await _dio.get<Map<String, Object?>>(
        _failingPath,
        options: Options(validateStatus: (_) => true),
      );

      expect(response.statusCode, HttpStatus.internalServerError);
    },
  );
}

void _mockApiHttpClientAdapter_should_recordAnOwnedRequestWithItsStatus() {
  test(
    'MockApiHttpClientAdapter should record an owned request with its status',
    () async {
      await _dio.post<Map<String, Object?>>(
        _failingPath,
        data: _requestBody,
        queryParameters: _requestQuery,
        options: Options(validateStatus: (_) => true),
      );

      expect(_journal.readAndClear(), [
        {
          'seq': 0,
          'kind': 'request',
          'method': 'POST',
          'path': _failingPath,
          'query': _requestQuery,
          'body': _requestBody,
          'status': HttpStatus.internalServerError,
        },
      ]);
    },
  );
}

void _mockApiHttpClientAdapter_should_recordTheAcceptLanguageOfTheRequest() {
  test(
    'MockApiHttpClientAdapter should record the accept language of the request',
    () async {
      await _dio.get<Map<String, Object?>>(
        _ownedPath,
        options: Options(headers: {'Accept-Language': _acceptLanguage}),
      );

      expect(
        _journal.readAndClear().single,
        containsPair('acceptLanguage', _acceptLanguage),
      );
    },
  );
}

void _mockApiHttpClientAdapter_should_recordTheDecodedBodyOfTheAnswer() {
  test(
    'MockApiHttpClientAdapter should record the decoded body of the answer',
    () async {
      await _dio.get<Map<String, Object?>>('$_idPath/$_itemId');

      final record = _journal.readAndClear().single;

      expect(record, containsPair('status', HttpStatus.ok));
      expect(record, containsPair('response', {_payloadKey: _itemId}));
    },
  );
}

void _mockApiHttpClientAdapter_should_recordTheAnswerOfADeclaredFailure() {
  test(
    'MockApiHttpClientAdapter should record the answer of a declared failure',
    () async {
      await _failingDio.get<Map<String, Object?>>(
        _ownedPath,
        options: Options(validateStatus: (_) => true),
      );

      final record = _journal.readAndClear().single;

      expect(record, containsPair('status', _failure.statusCode));
      expect(
        record,
        containsPair('response', {
          _failureCodeKey: _failure.errorCode,
          _failureTextKey: _failure.message,
        }),
      );
    },
  );
}

void _mockApiHttpClientAdapter_should_failAnIdPathByItsEndpointFailure() {
  test(
    'MockApiHttpClientAdapter should fail an id path by its endpoint failure',
    () async {
      final response = await _idFailingDio.get<Map<String, Object?>>(
        '$_idPath/$_itemId',
        options: Options(validateStatus: (_) => true),
      );

      expect(response.statusCode, _failure.statusCode);
    },
  );
}

void _mockApiHttpClientAdapter_should_recordTheRequestBeforeItsDelay() {
  test(
    'MockApiHttpClientAdapter should record the request before its delay',
    () {
      fakeAsync((async) {
        _delayedAdapter.fetch(
          RequestOptions(path: _ownedPath, baseUrl: _baseUrl),
          null,
          null,
        );
        async.flushMicrotasks();

        final awaitingBeforeDelay = _journal.requestsAwaitingResponse;
        final record = _journal.readAndClear().single;
        final hasStatusBeforeDelay = record.containsKey('status');
        final hasResponseBeforeDelay = record.containsKey('response');

        async.elapse(MockLatencyProfile.realistic.maxDelay);

        final statusAfterDelay = record['status'];
        final hasResponseAfterDelay = record.containsKey('response');
        final awaitingAfterDelay = _journal.requestsAwaitingResponse;

        expect(record, containsPair('path', _ownedPath));
        expect(hasStatusBeforeDelay, isFalse);
        expect(hasResponseBeforeDelay, isFalse);
        expect(statusAfterDelay, HttpStatus.ok);
        expect(hasResponseAfterDelay, isTrue);
        expect(awaitingBeforeDelay, [record]);
        expect(awaitingAfterDelay, isEmpty);
      });
    },
  );
}

void _mockApiHttpClientAdapter_should_leaveAnUnownedRequestOutOfTheJournal() {
  test('MockApiHttpClientAdapter should leave an unowned request '
      'out of the journal', () async {
    await _dio.get<Map<String, Object?>>(_unownedPath);

    expect(_journal.readAndClear(), isEmpty);
  });
}

void _mockApiHttpClientAdapter_should_readABinaryBodyOffTheRequestStream() {
  test(
    'MockApiHttpClientAdapter should read a binary body off the request stream',
    () async {
      final response = await _putFile(_filePath);

      expect(response.data, _fileBytes);
      expect(_networkAdapter.requestOptions, isEmpty);
    },
  );
}

void _mockApiHttpClientAdapter_should_answerBytesWithTheirContentType() {
  test(
    'MockApiHttpClientAdapter should answer bytes with their content type',
    () async {
      final response = await _putFile(_filePath);

      expect(
        response.headers.value(Headers.contentTypeHeader),
        _imageContentType,
      );
    },
  );
}

void _mockApiHttpClientAdapter_should_recordTheLengthOfABinaryBody() {
  test(
    'MockApiHttpClientAdapter should record the length of a binary body',
    () async {
      await _putFile(_filePath);

      expect(_journal.readAndClear(), [
        {
          'seq': 0,
          'kind': 'request',
          'method': 'PUT',
          'path': _filePath,
          'bytes': _fileBytes.length,
          'status': HttpStatus.ok,
          'response': {'bytes': _fileBytes.length},
        },
      ]);
    },
  );
}

void _mockApiHttpClientAdapter_should_passAnUnreadStreamToTheNetwork() {
  test(
    'MockApiHttpClientAdapter should pass an unread stream to the network',
    () async {
      await _putFile(_unownedFilePath);

      final stream = _networkAdapter.requestStreams.single;

      final sentBytes = await stream?.expand((chunk) => chunk).toList();

      expect(sentBytes, _fileBytes);
    },
  );
}

void _mockApiHttpClientAdapter_should_failAConnectionErrorAsDioDoes() {
  test(
    'MockApiHttpClientAdapter should fail a connection error as Dio does',
    () async {
      final request = _disconnectedDio.get<Map<String, Object?>>(_ownedPath);

      await expectLater(
        request,
        throwsA(
          isA<DioException>()
              .having(
                (error) => error.type,
                'type',
                DioExceptionType.connectionError,
              )
              .having((error) => error.error, 'error', isA<SocketException>())
              .having((error) => error.response, 'response', isNull),
        ),
      );

      expect(_networkAdapter.requestOptions, isEmpty);
    },
  );
}

void _mockApiHttpClientAdapter_should_recordAConnectionErrorAsAnswered() {
  test(
    'MockApiHttpClientAdapter should record a connection error as answered',
    () async {
      await expectLater(
        _disconnectedDio.get<Map<String, Object?>>(_ownedPath),
        throwsA(isA<DioException>()),
      );

      final record = _journal.readAndClear().single;

      expect(_journal.requestsAwaitingResponse, isEmpty);
      expect(record, containsPair('status', 0));
      expect(record.containsKey('response'), isFalse);
    },
  );
}

Future<Response<List<int>>> _putFile(String path) {
  return _dio.put<List<int>>(
    path,
    data: _fileBytes,
    options: Options(
      contentType: _imageContentType,
      responseType: ResponseType.bytes,
    ),
  );
}

MockApiResponse _respondPathId(MockApiRequest request) =>
    MockApiResponse(body: {_payloadKey: request.pathId});

MockApiResponse _respondServerError(MockApiRequest _) =>
    const MockApiResponse(body: {}, statusCode: HttpStatus.internalServerError);

MockApiResponse _respondBytes(MockApiRequest request) {
  final bytes = request.bytes;

  if (bytes == null) {
    return const MockApiResponse(body: {});
  }

  return MockApiResponse.fromBytes(bytes, contentType: _imageContentType);
}

Future<ResponseBody> _respondEmpty(RequestOptions _) async {
  return ResponseBody.fromString(
    jsonEncode(const <String, Object?>{}),
    HttpStatus.ok,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

// Test utility runtime over the endpoints a test declares, so the transport can
// be exercised without the state of a project behind it.
final class _TestMockRuntime implements MockTransportRuntime {
  @override
  final MockApiEndpointResolver endpointResolver;

  @override
  final Map<String, MockApiFailure> failures;

  @override
  final MockLatency latency;

  _TestMockRuntime({
    required this.endpointResolver,
    this.failures = const {},
    MockLatencyProfile latencyProfile = MockLatencyProfile.fast,
  }) : latency = MockLatency(profile: latencyProfile, seed: _latencySeed);

  @override
  Map<String, Object?> buildFailureBody(MockApiFailure failure) {
    return {
      _failureCodeKey: failure.errorCode,
      _failureTextKey: failure.message,
    };
  }
}
