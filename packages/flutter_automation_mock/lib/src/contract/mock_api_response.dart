import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_automation_mock/src/contract/mock_api_request.dart';

/// {@category Utils}
///
/// Answer the mock backend hands back to the app.
///
/// The body is the wire payload that the real backend would send. To reproduce
/// a backend that fails, name a [statusCode] other than `200` or fill the error
/// field that the payload already carries.
class MockApiResponse {
  static const String _jsonContentType = 'application/json';

  /// Http status code the app receives.
  final int statusCode;

  /// Response body, serialized as JSON; empty for an answer that carries
  /// [bytes].
  final Map<String, Object?> body;

  /// Content type of the answer.
  final String contentType;

  /// Binary response body sent in place of [body], null for a JSON answer.
  final Uint8List? bytes;

  const MockApiResponse({required this.body, this.statusCode = HttpStatus.ok})
    : bytes = null,
      contentType = _jsonContentType;

  /// Answers with the binary [bytes] of a file sent as [contentType].
  const MockApiResponse.fromBytes(
    Uint8List this.bytes, {
    required this.contentType,
    this.statusCode = HttpStatus.ok,
  }) : body = const {};

  /// Answers the empty body that the backend replies to a command with.
  ///
  /// Declared as a responder, so an endpoint whose only job is to accept the
  /// request names it directly. It does not repeat a body of its own.
  static MockApiResponse accept(MockApiRequest _) =>
      const MockApiResponse(body: {});
}
