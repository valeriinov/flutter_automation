import 'package:flutter_driver/flutter_driver.dart';

/// {@category Utils}
///
/// Driver command addressed by its wire name instead of by a typed call.
///
/// The driver extension dispatches on the `command` key and reads the rest of
/// the map as the arguments of the command. A flow therefore reaches each
/// command that the app registers, not only the few that `flutter_driver`
/// exposes as methods. `set_frame_sync` and `set_text_entry_emulation` are why
/// it exists. A probe series reads endpoints until frame sync is off. The
/// software keyboard never rises until text entry emulation is off.
final class AutomationDriverCommand extends Command {
  /// Wire name of the command, the `command` key the extension dispatches on.
  final String name;

  /// Arguments sent beside the name, stringified as the wire carries them.
  final Map<String, String> arguments;

  const AutomationDriverCommand({
    required this.name,
    required this.arguments,
    super.timeout,
  });

  @override
  String get kind => name;

  @override
  Map<String, String> serialize() => {...super.serialize(), ...arguments};
}
