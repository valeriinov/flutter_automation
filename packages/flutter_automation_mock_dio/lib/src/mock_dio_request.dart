import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';

/// {@category Utils}
///
/// Reads the [MockApiRequest] out of the options Dio hands to its transport.
///
/// The path is resolved against the base url. The whole interceptor chain has
/// run before the mock sees the request: auth headers, token refresh, logging.
abstract final class MockDioRequest {
  /// Reads the request Dio is about to send to the network.
  ///
  /// The [options] parameter is what Dio hands to its transport.
  /// The [bytes] parameter is the binary body read off the request stream,
  /// which only the transport holds.
  static MockApiRequest read(RequestOptions options, {Uint8List? bytes}) {
    final path = readPath(options);
    final pathSegment = _tryReadPathSegment(path);

    return MockApiRequest(
      path: path,
      method: options.method,
      body: _readBody(options.data),
      queryParameters: {
        ...Uri.parse(options.path).queryParameters,
        ...options.queryParameters,
      },
      pathId: pathSegment == null ? null : int.tryParse(pathSegment),
      pathSegment: pathSegment,
      bytes: bytes,
      acceptLanguage: _tryReadAcceptLanguage(options),
    );
  }

  /// Reads the path of the request relative to the base url.
  ///
  /// The [options] parameter is what Dio hands to its transport.
  static String readPath(RequestOptions options) {
    final basePath = Uri.parse(options.baseUrl).path;
    final requestPath = options.uri.path;

    if (basePath.isEmpty || !requestPath.startsWith(basePath)) {
      return requestPath;
    }

    return requestPath.substring(basePath.length);
  }

  static String? _tryReadPathSegment(String path) {
    final segment = path.split('/').last;

    return segment.isEmpty ? null : segment;
  }

  /// Dio keeps its headers in a case-insensitive map, so the lookup finds the
  /// header in whatever case the interceptor wrote it.
  static String? _tryReadAcceptLanguage(RequestOptions options) {
    final acceptLanguage = options.headers[HttpHeaders.acceptLanguageHeader];

    return acceptLanguage is String ? acceptLanguage : null;
  }

  static Map<String, Object?> _readBody(Object? data) {
    if (data is Map<String, Object?>) {
      return data;
    }

    if (data is FormData) {
      return {for (final field in data.fields) field.key: field.value};
    }

    return const {};
  }
}
