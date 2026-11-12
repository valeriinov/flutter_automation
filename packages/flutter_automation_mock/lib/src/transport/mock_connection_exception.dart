/// {@category Utils}
///
/// Failure of a connection that the mock reproduces.
///
/// [MockApiTransport] throws it for a path whose failure is a connection
/// error. A transport adapter translates it into the error that its HTTP
/// client raises for a device without a connection.
final class MockConnectionException implements Exception {
  /// Why the connection failed, in the words of the socket layer.
  final String reason;

  /// Creates a connection failure.
  ///
  /// The [reason] parameter says why the connection failed.
  const MockConnectionException(this.reason);

  @override
  String toString() => 'MockConnectionException: $reason';
}
