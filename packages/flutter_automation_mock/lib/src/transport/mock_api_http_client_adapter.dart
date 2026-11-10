import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_endpoint.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_failure.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_request.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_response.dart';
import 'package:flutter_automation_mock/src/state/mock_journal.dart';
import 'package:flutter_automation_mock/src/transport/mock_transport_runtime.dart';

/// {@category Utils}
///
/// Answers a request from the mock and does not send it to the network.
///
/// Replaces the transport of a Dio, the lowest point where the app can use a
/// fake. The request still runs through each interceptor: auth headers, token
/// refresh, logging, error translation. Only the socket is fake. Everything
/// above it, from the service that built the request to the widget that shows
/// the result, runs unchanged.
///
/// Each answer waits out the delay of the latency profile of the run. A loader,
/// a disabled button and a race of the app are then as visible as they are
/// against a real backend. When the configuration names a failure for a path,
/// the adapter answers with that failure. It can also fail with the connection
/// error that a device without a connection raises. This is how a flow reaches
/// the error branch of the app.
///
/// [networkAdapter] receives a path that no api owns, so a scenario that leaves
/// a section out still uses the remote environment for it.
///
/// The adapter writes each request that the mock answers to [journal] before
/// its delay. The record holds the language that the `Accept-Language` header
/// asks for. The status and the decoded body of the answer join the same record
/// afterwards. The body joins only when it carries a key. The record holds a
/// binary body, in either direction, by its length alone.
class MockApiHttpClientAdapter implements HttpClientAdapter {
  static const _methodKey = 'method';
  static const _pathKey = 'path';
  static const _queryKey = 'query';
  static const _bodyKey = 'body';
  static const _bytesKey = 'bytes';
  static const _acceptLanguageKey = 'acceptLanguage';
  static const _connectionErrorReason = 'Failed host lookup';

  final MockTransportRuntime _runtime;
  final HttpClientAdapter _networkAdapter;
  final MockJournal _journal;

  MockApiHttpClientAdapter({
    required MockTransportRuntime runtime,
    required HttpClientAdapter networkAdapter,
    required MockJournal journal,
  }) : _runtime = runtime,
       _networkAdapter = networkAdapter,
       _journal = journal;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final endpoint = _runtime.endpointResolver.tryResolve(
      MockApiRequest.fromOptions(options).path,
    );

    if (endpoint == null) {
      return _networkAdapter.fetch(options, requestStream, cancelFuture);
    }

    final request = MockApiRequest.fromOptions(
      options,
      bytes: await _tryReadBytes(options, requestStream),
    );
    final record = _journal.addRequest(_toRecordFields(request));

    await _runtime.latency.waitOut();

    final failure = _tryResolveFailure(endpoint, request);

    if (failure != null && failure.isConnectionError) {
      _journal.attachResponse(record, statusCode: 0, body: const {});

      throw DioException.connectionError(
        requestOptions: options,
        reason: _connectionErrorReason,
        error: const SocketException(_connectionErrorReason),
      );
    }

    final response = await _resolveResponse(endpoint, request, failure);

    _journal.attachResponse(
      record,
      statusCode: response.statusCode,
      body: _toRecordBody(response),
    );

    return _toResponseBody(response);
  }

  @override
  void close({bool force = false}) => _networkAdapter.close(force: force);

  /// Dio sends a `Uint8List` body as it is and skips its transformer, so the
  /// request stream carries exactly those bytes. Any other body stays unread.
  Future<Uint8List?> _tryReadBytes(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) async {
    if (options.data is! Uint8List || requestStream == null) {
      return null;
    }

    final builder = BytesBuilder(copy: false);

    await requestStream.forEach(builder.add);

    return builder.takeBytes();
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

  /// The failure the configuration names for this request, if it names one.
  ///
  /// Matched on the path the request carries and on the path the endpoint owns,
  /// so a configuration naming `/items` also fails `/items/1`.
  MockApiFailure? _tryResolveFailure(
    MockApiEndpoint endpoint,
    MockApiRequest request,
  ) {
    final failures = _runtime.failures;

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
      body: _runtime.buildFailureBody(failure),
    );
  }

  Map<String, Object?> _toRecordBody(MockApiResponse response) {
    final bytes = response.bytes;

    if (bytes == null) {
      return response.body;
    }

    return {_bytesKey: bytes.length};
  }

  ResponseBody _toResponseBody(MockApiResponse response) {
    final headers = {
      Headers.contentTypeHeader: [response.contentType],
    };
    final bytes = response.bytes;

    if (bytes == null) {
      return ResponseBody.fromString(
        jsonEncode(response.body),
        response.statusCode,
        headers: headers,
      );
    }

    return ResponseBody.fromBytes(bytes, response.statusCode, headers: headers);
  }
}
