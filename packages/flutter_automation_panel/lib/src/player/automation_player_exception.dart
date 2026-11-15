/// {@category Utils}
///
/// The reason a step could not be played, in words for the tester.
final class AutomationPlayerException implements Exception {
  /// What stopped the step.
  final String reason;

  const AutomationPlayerException(this.reason);

  @override
  String toString() => reason;
}
