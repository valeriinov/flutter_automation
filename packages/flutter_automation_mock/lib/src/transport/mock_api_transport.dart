import 'package:flutter_automation_mock/src/contract/mock_api_endpoint.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_failure.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_request.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_response.dart';
import 'package:flutter_automation_mock/src/state/mock_journal.dart';
import 'package:flutter_automation_mock/src/transport/mock_connection_exception.dart';
import 'package:flutter_automation_mock/src/transport/mock_backend.dart';

/// {@category Utils}
///
/// Answers a [MockApiRequest] from the mock and never touches a network.
///
/// The transport knows no HTTP client. An adapter package builds the request
/// out of what its client hands to the socket layer and turns the answer back
/// into the client's response. Everything above the socket, from the service
/// that built the request to the widget that shows the result, runs unchanged.
///
/// Each answer waits out the delay of the latency profile of the run. A loader,
/// a disabled button and a race of the app are then as visible as they are
/// against a real backend. When the backend names a failure for a path, the
/// transport answers with that failure. It can also throw the
/// [MockConnectionException] that a device without a connection raises. This is
/// how a flow reaches the error branch of the app.
///
/// The transport writes each request it answers to the journal before its
/// delay. The record holds the language that the `Accept-Language` header asks
/// for. The status and the decoded body of the answer join the same record
/// afterwards. The body joins only when it carries a key. The record holds a
/// binary body, in either direction, by its length alone.
class MockApiTransport {
  static const _methodKey = 'method';
  static const _pathKey = 'path';
  static const _queryKey = 'query';
  static const _bodyKey = 'body';
  static const _bytesKey = 'bytes';
  static const _acceptLanguageKey = 'acceptLanguage';
  static const _connectionErrorReason = 'Failed host lookup';
  static const _connectionErrorStatusCode = 0;

  final MockBackend _backend;
  final MockJournal _journal;

  /// Creates a transport over [backend] that records into [journal].
  ///
  /// The [backend] parameter holds the endpoints, latency and failures the
  /// transport reads on each request.
  /// The [journal] parameter receives a record of each answered request.
  MockApiTransport({required MockBackend backend, required MockJournal journal})
    : _backend = backend,
      _journal = journal;

  /// Whether an endpoint of the mock answers [path].
  ///
  /// A path that no endpoint owns goes on to the network.
  bool ownsPath(String path) => _tryResolveEndpoint(path) != null;

  /// Answers [request] with the payload of its endpoint, or with the failure
  /// the backend names for it.
  ///
  /// Throws a [StateError] when no endpoint owns the path; check [ownsPath]
  /// first. Throws a [MockConnectionException] when the backend names a
  /// connection error for the path.
  Future<MockApiResponse> answer(MockApiRequest request) async {
    final endpoint = _tryResolveEndpoint(request.path);

    if (endpoint == null) {
      throw StateError('No mock endpoint owns "${request.path}".');
    }

    final record = _journal.addRequest(_toRecordFields(request));

    await _backend.latency.waitOut();

    final failure = _tryResolveFailure(endpoint, request);

    if (failure != null && failure.isConnectionError) {
      _journal.attachResponse(
        record,
        statusCode: _connectionErrorStatusCode,
        body: const {},
      );

      throw const MockConnectionException(_connectionErrorReason);
    }

    final response = await _resolveResponse(endpoint, request, failure);

    _journal.attachResponse(
      record,
      statusCode: response.statusCode,
      body: _toRecordBody(response),
    );

    return response;
  }

  MockApiEndpoint? _tryResolveEndpoint(String path) {
    return _backend.endpointResolver.tryResolve(path);
  }

  Map<String, Object?> _toRecordFields(MockApiRequest request) {
    return {
      _methodKey: request.method,
      _pathKey: request.path,
      if (request.queryParameters.isNotEmpty)
        _queryKey: request.queryParameters,
      if (request.body.isNotEmpty) _bodyKey: request.body,
      _bytesKey: ?request.bytes?.length,
      _acceptLanguageKey: ?request.acceptLanguage,
    };
  }

  /// The failure the backend names for this request, if it names one.
  ///
  /// Matched on the path the request carries and on the path the endpoint owns,
  /// so a backend naming `/items` also fails `/items/1`.
  MockApiFailure? _tryResolveFailure(
    MockApiEndpoint endpoint,
    MockApiRequest request,
  ) {
    final failures = _backend.failures;

    return failures[request.path] ?? failures[endpoint.path];
  }

  Future<MockApiResponse> _resolveResponse(
    MockApiEndpoint endpoint,
    MockApiRequest request,
    MockApiFailure? failure,
  ) async {
    if (failure == null) {
      return endpoint.respond(request);
    }

    return MockApiResponse(
      statusCode: failure.statusCode,
      body: _backend.buildFailureBody(failure),
    );
  }

  Map<String, Object?> _toRecordBody(MockApiResponse response) {
    final bytes = response.bytes;

    if (bytes == null) {
      return response.body;
    }

    return {_bytesKey: bytes.length};
  }
}
