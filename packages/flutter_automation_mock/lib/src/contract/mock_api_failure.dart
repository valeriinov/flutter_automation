import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:flutter_automation_mock/src/contract/mock_api_request.dart';

part 'mock_api_failure.freezed.dart';

part 'mock_api_failure.g.dart';

/// {@category Utils}
///
/// Error the mock answers a path with instead of its payload.
///
/// Keyed by path in the configuration. A run reaches the error path of the app
/// for any mocked endpoint without a line of code in the api that owns it. The
/// error is an answer with an error status, or a connection that fails.
@freezed
sealed class MockApiFailure with _$MockApiFailure {
  const MockApiFailure._();

  const factory MockApiFailure({
    /// Status the answer carries.
    @Default(HttpStatus.internalServerError) int statusCode,

    /// Code that the app reads out of the payload to map the error.
    String? errorCode,

    /// Message the payload carries next to [errorCode].
    String? message,

    /// Key of a message that the project keeps in each app language.
    ///
    /// The package stores the key, and [resolveMessage] reads it into the
    /// text that `MockBackend.buildFailureBody` puts in the body.
    String? messageKey,

    /// Whether the request never reaches the backend, the way a device without
    /// a connection fails it.
    ///
    /// Turned on, the request fails with the connection error that the HTTP
    /// client raises for a socket that cannot connect. The request does not
    /// read [statusCode], [errorCode], [message] and [messageKey].
    @Default(false) bool isConnectionError,
  }) = _MockApiFailure;

  factory MockApiFailure.fromJson(Map<String, Object?> json) =>
      _$MockApiFailureFromJson(json);

  /// Text of the failure for [request], in this order:
  ///
  /// 1. [message];
  /// 2. the text of [messageKey] in `MockApiRequest.languageCode`;
  /// 3. the text of [messageKey] in [defaultLanguageCode];
  /// 4. [errorCode];
  /// 5. [messageKey] itself.
  ///
  /// A failure with neither [message] nor [messageKey] answers null.
  ///
  /// The [request] parameter is the request the failure answers.
  /// The [readText] parameter answers the text of a key in a language code,
  /// or null when the project keeps none.
  /// The [defaultLanguageCode] parameter is the language of the app when the
  /// request carries none or the project keeps no text in it.
  String? resolveMessage(
    MockApiRequest request, {
    required String? Function(String key, String languageCode) readText,
    required String defaultLanguageCode,
  }) {
    final key = messageKey;

    if (message != null || key == null) {
      return message;
    }

    final languageCode = request.languageCode;
    final requestText = languageCode == null
        ? null
        : readText(key, languageCode);

    return requestText ??
        readText(key, defaultLanguageCode) ??
        errorCode ??
        key;
  }
}
