import 'dart:typed_data';

import 'package:dio/dio.dart';

// Test utility adapter for capturing request options and returning canned
// responses without a full mock.
final class TestHttpClientAdapter implements HttpClientAdapter {
  final requestOptions = <RequestOptions>[];
  final requestStreams = <Stream<Uint8List>?>[];
  final Future<ResponseBody> Function(RequestOptions options) _onFetch;

  TestHttpClientAdapter({
    required Future<ResponseBody> Function(RequestOptions options) onFetch,
  }) : _onFetch = onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requestOptions.add(options);
    requestStreams.add(requestStream);

    return _onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}
