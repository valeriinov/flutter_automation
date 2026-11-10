import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// {@category Utils}
///
/// Request the mock backend is about to answer.
///
/// Built from what Dio hands to its transport. The path is already resolved
/// against the base url. The whole interceptor chain has run before the mock
/// sees it: auth headers, token refresh, logging.
class MockApiRequest {
  static const String _getMethod = 'GET';

  /// Endpoint path the request addresses, relative to the base url.
  final String path;

  /// Http method of the request, as Dio sends it: `GET`, `PUT` and so on.
  final String method;

  /// Decoded request body, empty when the request carries none.
  ///
  /// The mock reads a multipart request by its text fields, so a form that
  /// travels as `FormData` reaches a responder the way a JSON body does.
  final Map<String, Object?> body;

  /// Query parameters of the url, empty when the request carries none.
  ///
  /// A `GET` endpoint passes its request DTO here, not in [body]. A responder
  /// that reads its parameters reads them off this map. This map also holds a
  /// query that the url string itself carries.
  final Map<String, Object?> queryParameters;

  /// Trailing path segment read as an id, null when the path carries none.
  final int? pathId;

  /// Trailing path segment as the url carries it, null when the path is empty.
  ///
  /// Reaches an id the backend issues as a string, which [pathId] reads as
  /// null.
  final String? pathSegment;

  /// Binary request body as it goes over the wire, null for any other body.
  final Uint8List? bytes;

  /// Language the request asks its answer in, as its `Accept-Language` header
  /// carries it, null when the request carries none.
  final String? acceptLanguage;

  const MockApiRequest({
    required this.path,
    required this.body,
    this.method = _getMethod,
    this.queryParameters = const {},
    this.pathId,
    this.pathSegment,
    this.bytes,
    this.acceptLanguage,
  });

  /// Reads the request Dio is about to send to the network.
  ///
  /// The [bytes] parameter is the binary body read off the request stream,
  /// which only the transport holds.
  factory MockApiRequest.fromOptions(
    RequestOptions options, {
    Uint8List? bytes,
  }) {
    final path = _resolvePath(options);
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

  static String _resolvePath(RequestOptions options) {
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
