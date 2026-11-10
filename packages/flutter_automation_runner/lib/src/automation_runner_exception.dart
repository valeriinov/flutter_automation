/// {@category Utils}
///
/// Represents a recoverable automation runner failure.
final class AutomationRunnerException implements Exception {
  /// Exit code of a process that stopped on a recoverable failure.
  static const errorExitCode = 64;

  final String message;

  const AutomationRunnerException(this.message);

  @override
  String toString() => message;
}
