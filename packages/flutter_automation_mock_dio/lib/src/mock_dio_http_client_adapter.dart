import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock_dio/src/mock_dio_request_reader.dart';

/// {@category Utils}
///
/// Answers a Dio request from the mock and does not send it to the network.
///
/// Replaces the transport of a Dio, the lowest point where the app can use a
/// fake. The request still runs through each interceptor: auth headers, token
/// refresh, logging, error translation. Only the socket is fake.
///
/// A path that no endpoint owns goes to the network adapter that the Dio held
/// before, so a scenario that leaves a section out still uses the remote
/// environment for it. A failed connection raises
/// `DioException.connectionError`, as a device without a connection does.
class MockDioHttpClientAdapter implements HttpClientAdapter {
  final MockApiTransport _transport;
  final HttpClientAdapter _networkAdapter;

  /// Creates an adapter over [transport] that passes unowned paths to
  /// [networkAdapter].
  ///
  /// The [transport] parameter answers the requests that an endpoint owns.
  /// The [networkAdapter] parameter receives the other requests.
  MockDioHttpClientAdapter({
    required MockApiTransport transport,
    required HttpClientAdapter networkAdapter,
  }) : _transport = transport,
       _networkAdapter = networkAdapter;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!_transport.ownsPath(MockDioRequestReader.readPath(options))) {
      return _networkAdapter.fetch(options, requestStream, cancelFuture);
    }

    final request = MockDioRequestReader.read(
      options,
      bytes: await _tryReadBytes(options, requestStream),
    );

    return _toResponseBody(await _answer(options, request));
  }

  @override
  void close({bool force = false}) => _networkAdapter.close(force: force);

  Future<MockApiResponse> _answer(
    RequestOptions options,
    MockApiRequest request,
  ) async {
    try {
      return await _transport.answer(request);
    } on MockConnectionException catch (failure) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: failure.reason,
        error: SocketException(failure.reason),
      );
    }
  }

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
