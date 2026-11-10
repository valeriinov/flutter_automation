import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_driver/src/automation_protocol.dart';
import 'package:flutter_automation_driver/src/automation_screen_reader.dart';

/// {@category Utils}
///
/// Registers the commands every driven app answers.
///
/// `keyboard.read` answers the keyboard inset of the view. `screen.read`
/// answers the screen, the view size, the keyboard inset and the platform.
abstract final class AutomationDeviceCommands {
  /// Registers both commands in [AutomationCommandHandler].
  ///
  /// The [screenReader] parameter runs when `screen.read` arrives, not at
  /// registration. It may therefore reach objects that exist only after the app
  /// has started.
  static void register({required AutomationScreenReader screenReader}) {
    AutomationCommandHandler.register(
      AutomationProtocol.keyboardReadCommand,
      (_) async => jsonEncode(_readKeyboard()),
    );
    AutomationCommandHandler.register(
      AutomationProtocol.screenReadCommand,
      (_) async => jsonEncode(_readScreen(screenReader)),
    );
  }

  static Map<String, Object?> _readKeyboard() {
    return {AutomationProtocol.keyboardInsetKey: _readKeyboardInset()};
  }

  static Map<String, Object?> _readScreen(AutomationScreenReader screenReader) {
    final view = _readView();

    return {
      AutomationProtocol.screenKey: screenReader(),
      AutomationProtocol.viewKey: view == null ? null : _readLogicalSize(view),
      AutomationProtocol.keyboardInsetKey: _readKeyboardInset(),
      AutomationProtocol.platformKey: defaultTargetPlatform.name,
    };
  }

  static FlutterView? _readView() {
    return WidgetsBinding.instance.platformDispatcher.implicitView;
  }

  /// The inset of a `FlutterView` is in physical pixels, the unit of a device
  /// screenshot.
  static double _readKeyboardInset() {
    return _readView()?.viewInsets.bottom ?? 0.0;
  }

  /// A `FlutterView` reports its size in physical pixels. The pixel ratio
  /// converts it to the logical size of the widget offsets.
  static Map<String, double> _readLogicalSize(FlutterView view) {
    final size = view.physicalSize / view.devicePixelRatio;

    return {
      AutomationProtocol.widthKey: size.width,
      AutomationProtocol.heightKey: size.height,
    };
  }
}
