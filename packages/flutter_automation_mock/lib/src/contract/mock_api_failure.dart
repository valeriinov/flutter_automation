import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';

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
  const factory MockApiFailure({
    /// Status the answer carries.
    @Default(HttpStatus.internalServerError) int statusCode,

    /// Code that the app reads out of the payload to map the error.
    String? errorCode,

    /// Message the payload carries next to [errorCode].
    String? message,

    /// Key of a message the project keeps in each app language, for a failure
    /// whose backend answer carries a message and no [errorCode].
    ///
    /// The project reads it in `MockBackend.buildFailureBody` and answers the
    /// message in the language of the request. A [message] wins over it.
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
}
