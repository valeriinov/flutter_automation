import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock_dio/flutter_automation_mock_dio.dart';

import 'test_utils/test_http_client_adapter.dart';
import 'test_utils/test_mock_api.dart';

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
    endpoints: [
      MockApiEndpoint(path: _ownedPath, respond: _respondPathId),
      MockApiEndpoint(path: _idPath, respond: _respondPathId, hasPathId: true),
      MockApiEndpoint(path: _failingPath, respond: _respondServerError),
      MockApiEndpoint(path: _filePath, respond: _respondBytes),
    ],
  ),
]);
final _dio = Dio(BaseOptions(baseUrl: _baseUrl))
  ..httpClientAdapter = MockDioHttpClientAdapter(
    transport: MockApiTransport(
      backend: _TestMockBackend(endpointResolver: _endpointResolver),
      journal: _journal,
    ),
    networkAdapter: _networkAdapter,
  );

final _failingDio = Dio(BaseOptions(baseUrl: _baseUrl))
  ..httpClientAdapter = MockDioHttpClientAdapter(
    transport: MockApiTransport(
      backend: _TestMockBackend(
        failures: {_ownedPath: _failure},
        endpointResolver: _endpointResolver,
      ),
      journal: _journal,
    ),
    networkAdapter: _networkAdapter,
  );

final _idFailingDio = Dio(BaseOptions(baseUrl: _baseUrl))
  ..httpClientAdapter = MockDioHttpClientAdapter(
    transport: MockApiTransport(
      backend: _TestMockBackend(
        failures: {_idPath: _failure},
        endpointResolver: _endpointResolver,
      ),
      journal: _journal,
    ),
    networkAdapter: _networkAdapter,
  );

final _disconnectedDio = Dio(BaseOptions(baseUrl: _baseUrl))
  ..httpClientAdapter = MockDioHttpClientAdapter(
    transport: MockApiTransport(
      backend: _TestMockBackend(
        failures: {_ownedPath: MockApiFailure(isConnectionError: true)},
        endpointResolver: _endpointResolver,
      ),
      journal: _journal,
    ),
    networkAdapter: _networkAdapter,
  );

final _delayedAdapter = MockDioHttpClientAdapter(
  transport: MockApiTransport(
    backend: _TestMockBackend(
      latencyProfile: MockLatencyProfile.realistic,
      endpointResolver: _endpointResolver,
    ),
    journal: _journal,
  ),
  networkAdapter: _networkAdapter,
);

void main() {
  _setup();
  group('MockDioHttpClientAdapter Tests', () {
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
    'MockDioHttpClientAdapter should answer an owned path without the network',
    () async {
      final response = await _dio.get<Map<String, Object?>>(_ownedPath);

      expect(response.statusCode, HttpStatus.ok);
      expect(_networkAdapter.requestOptions, isEmpty);
    },
  );
}

void _mockApiHttpClientAdapter_should_readThePathIdOfTheRequest() {
  test(
    'MockDioHttpClientAdapter should read the path id of the request',
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
    'MockDioHttpClientAdapter should pass an unowned path to the network',
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
    'MockDioHttpClientAdapter should keep the status code of the response',
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
    'MockDioHttpClientAdapter should record an owned request with its status',
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
    'MockDioHttpClientAdapter should record the accept language of the request',
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
    'MockDioHttpClientAdapter should record the decoded body of the answer',
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
    'MockDioHttpClientAdapter should record the answer of a declared failure',
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
    'MockDioHttpClientAdapter should fail an id path by its endpoint failure',
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
    'MockDioHttpClientAdapter should record the request before its delay',
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
  test('MockDioHttpClientAdapter should leave an unowned request '
      'out of the journal', () async {
    await _dio.get<Map<String, Object?>>(_unownedPath);

    expect(_journal.readAndClear(), isEmpty);
  });
}

void _mockApiHttpClientAdapter_should_readABinaryBodyOffTheRequestStream() {
  test(
    'MockDioHttpClientAdapter should read a binary body off the request stream',
    () async {
      final response = await _putFile(_filePath);

      expect(response.data, _fileBytes);
      expect(_networkAdapter.requestOptions, isEmpty);
    },
  );
}

void _mockApiHttpClientAdapter_should_answerBytesWithTheirContentType() {
  test(
    'MockDioHttpClientAdapter should answer bytes with their content type',
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
    'MockDioHttpClientAdapter should record the length of a binary body',
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
    'MockDioHttpClientAdapter should pass an unread stream to the network',
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
    'MockDioHttpClientAdapter should fail a connection error as Dio does',
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
    'MockDioHttpClientAdapter should record a connection error as answered',
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

// Test utility backend over the endpoints a test declares, so the transport can
// be exercised without the state of a project behind it.
final class _TestMockBackend implements MockBackend {
  @override
  final MockApiEndpointResolver endpointResolver;

  @override
  final Map<String, MockApiFailure> failures;

  @override
  final MockLatency latency;

  _TestMockBackend({
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
