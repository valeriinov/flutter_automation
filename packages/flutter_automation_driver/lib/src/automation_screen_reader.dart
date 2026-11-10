import 'package:flutter_automation_driver/src/automation_protocol.dart';

/// Describes the screen the app shows, or null when it shows none yet.
///
/// The description holds the screen name under
/// [AutomationProtocol.screenNameKey]. The `screen.read` command encodes the
/// result as JSON.
typedef AutomationScreenReader = Map<String, Object?>? Function();
