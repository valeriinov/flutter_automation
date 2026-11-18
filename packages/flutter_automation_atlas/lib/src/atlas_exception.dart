/// {@category Utils}
///
/// Represents a recoverable atlas failure.
final class AtlasException implements Exception {
  /// The exit code of a process that stops on an [AtlasException].
  static const errorExitCode = 64;

  /// What went wrong, in words for the person who runs the command.
  final String message;

  const AtlasException(this.message);

  @override
  String toString() => message;
}
