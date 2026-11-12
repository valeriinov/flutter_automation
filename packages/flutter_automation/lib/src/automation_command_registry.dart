import 'dart:convert';

import 'package:flutter_automation/src/automation_command_handler.dart';

/// {@category Utils}
///
/// Commands an agent sends to the app through the Flutter Driver channel.
///
/// A driver taps widgets and reads the tree. A run must also put the app into
/// the state it will walk. A subsystem registers what it answers here. This
/// layer stays unaware of each subsystem, and the app keeps one channel instead
/// of one per subsystem.
abstract final class AutomationCommandRegistry {
  static const _commandKey = 'command';

  static final Map<String, AutomationCommandHandler> _handlers = {};

  /// Registers [handler] under [name].
  ///
  /// A later call with the same [name] replaces it.
  static void register(String name, AutomationCommandHandler handler) {
    _handlers[name] = handler;
  }

  /// Answers [message], as the handler of the Flutter Driver extension.
  ///
  /// Throws when the message names a command that this build does not answer. A
  /// run that asks for a state the build cannot reach then fails before its
  /// first step. It does not walk a flow against the wrong state.
  static Future<String> handle(String? message) {
    final payload = _readPayload(message);
    final name = payload[_commandKey];
    final handler = name is String ? _handlers[name] : null;

    if (handler == null) {
      throw StateError(
        'No automation command "$name". This build answers '
        '${_handlers.keys.toList()}.',
      );
    }

    return handler(payload);
  }

  static Map<String, Object?> _readPayload(String? message) {
    if (message == null) {
      throw StateError('An automation command needs a JSON message.');
    }

    final payload = jsonDecode(message);

    if (payload is! Map<String, Object?>) {
      throw StateError('An automation command message is not a JSON object.');
    }

    return payload;
  }
}
