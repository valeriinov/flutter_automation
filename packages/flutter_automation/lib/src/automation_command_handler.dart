/// {@category Utils}
///
/// Answers one command that an agent sent to the app.
///
/// The [payload] parameter is the decoded message, the `command` key that
/// selected this handler included. What it returns is what the driver reads
/// back.
typedef AutomationCommandHandler =
    Future<String> Function(Map<String, Object?> payload);
