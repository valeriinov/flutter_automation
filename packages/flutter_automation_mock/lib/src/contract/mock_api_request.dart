import 'dart:typed_data';

/// {@category Utils}
///
/// Request the mock backend is about to answer.
///
/// Built by a transport adapter out of what the HTTP client hands to it. The
/// path is already resolved against the base url. The whole interceptor chain
/// has run before the mock sees it: auth headers, token refresh, logging.
class MockApiRequest {
  static const String _getMethod = 'GET';

  /// Endpoint path the request addresses, relative to the base url.
  final String path;

  /// Http method of the request, as the client sends it: `GET`, `PUT` and so
  /// on.
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

  /// Creates the request a transport adapter read off the wire.
  ///
  /// The [path] parameter is the endpoint path, relative to the base url.
  /// The [body] parameter is the decoded body.
  /// The [method] parameter is the http method.
  /// The [queryParameters] parameter holds the query of the url.
  /// The [pathId] parameter is the trailing segment read as an id.
  /// The [pathSegment] parameter is the trailing segment as written.
  /// The [bytes] parameter is the binary body.
  /// The [acceptLanguage] parameter is the language the request asks for.
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
}
