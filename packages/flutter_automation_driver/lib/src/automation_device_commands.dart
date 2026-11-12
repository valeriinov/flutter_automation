import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_driver/src/automation_frame_texts.dart';
import 'package:flutter_automation_driver/src/automation_frame_widgets.dart';
import 'package:flutter_automation_driver/src/automation_launch_locale_file.dart';
import 'package:flutter_automation_driver/src/automation_locale_applier.dart';
import 'package:flutter_automation_driver/src/automation_protocol.dart';
import 'package:flutter_automation_driver/src/automation_screen_reader.dart';

/// {@category Utils}
///
/// Registers the commands every driven app answers.
///
/// `keyboard.read` answers the keyboard inset of the view. `screen.read`
/// answers the screen, the view size, the keyboard inset and the platform. It
/// adds the texts and the widget types of the frame when the request sets
/// `"texts"` and `"widgets"` to true. `locale.apply` takes
/// `{"locale": <language code>}`, runs the locale applier and answers
/// `{"locale": <language code>}`. `locale.save` takes the same request, saves
/// the language for the next launch of the app and answers the same way.
abstract final class AutomationDeviceCommands {
  /// Registers the commands in [AutomationCommandRegistry].
  ///
  /// The [screenReader] parameter runs when `screen.read` arrives, not at
  /// registration. It may therefore reach objects that exist only after the app
  /// has started.
  /// The [localeApplier] parameter runs when `locale.apply` arrives. Both
  /// locale commands stay unregistered without it.
  static void register({
    required AutomationScreenReader screenReader,
    AutomationLocaleApplier? localeApplier,
  }) {
    AutomationCommandRegistry.register(
      AutomationProtocol.keyboardReadCommand,
      (_) async => jsonEncode(_readKeyboard()),
    );
    AutomationCommandRegistry.register(
      AutomationProtocol.screenReadCommand,
      (payload) async => jsonEncode(_readScreen(screenReader, payload)),
    );

    if (localeApplier == null) {
      return;
    }

    AutomationCommandRegistry.register(
      AutomationProtocol.localeApplyCommand,
      (payload) => _applyLocale(localeApplier, payload),
    );
    AutomationCommandRegistry.register(
      AutomationProtocol.localeSaveCommand,
      _saveLocale,
    );
  }

  static Map<String, Object?> _readKeyboard() {
    return {AutomationProtocol.keyboardInsetKey: _readKeyboardInset()};
  }

  static Map<String, Object?> _readScreen(
    AutomationScreenReader screenReader,
    Map<String, Object?> payload,
  ) {
    final view = _readView();

    return {
      AutomationProtocol.screenKey: screenReader(),
      AutomationProtocol.viewKey: view == null ? null : _readLogicalSize(view),
      AutomationProtocol.keyboardInsetKey: _readKeyboardInset(),
      AutomationProtocol.platformKey: defaultTargetPlatform.name,
      if (payload[AutomationProtocol.textsKey] == true)
        AutomationProtocol.textsKey: ?_tryReadFrame(AutomationFrameTexts.read),
      if (payload[AutomationProtocol.widgetsKey] == true)
        AutomationProtocol.widgetsKey: ?_tryReadFrame(
          AutomationFrameWidgets.read,
        ),
    };
  }

  static Future<String> _applyLocale(
    AutomationLocaleApplier localeApplier,
    Map<String, Object?> payload,
  ) async {
    final languageCode = _readLanguageCode(
      AutomationProtocol.localeApplyCommand,
      payload,
    );

    await localeApplier(languageCode);

    return jsonEncode({AutomationProtocol.localeKey: languageCode});
  }

  static Future<String> _saveLocale(Map<String, Object?> payload) async {
    final languageCode = _readLanguageCode(
      AutomationProtocol.localeSaveCommand,
      payload,
    );

    await AutomationLaunchLocaleFile.save(languageCode);

    return jsonEncode({AutomationProtocol.localeKey: languageCode});
  }

  static String _readLanguageCode(
    String command,
    Map<String, Object?> payload,
  ) {
    final languageCode = payload[AutomationProtocol.localeKey];

    if (languageCode is! String) {
      throw StateError(
        'The "$command" command needs a "${AutomationProtocol.localeKey}" '
        'string.',
      );
    }

    return languageCode;
  }

  static List<String>? _tryReadFrame(
    List<String> Function(Element root, Rect window) read,
  ) {
    final view = _readView();
    final rootElement = WidgetsBinding.instance.rootElement;

    if (view == null || rootElement == null) {
      return null;
    }

    return read(rootElement, Offset.zero & _readLogicalSizeOf(view));
  }

  static FlutterView? _readView() {
    return WidgetsBinding.instance.platformDispatcher.implicitView;
  }

  /// The inset of a `FlutterView` is in physical pixels, the unit of a device
  /// screenshot.
  static double _readKeyboardInset() {
    return _readView()?.viewInsets.bottom ?? 0.0;
  }

  static Size _readLogicalSizeOf(FlutterView view) {
    return view.physicalSize / view.devicePixelRatio;
  }

  /// A `FlutterView` reports its size in physical pixels. The pixel ratio
  /// converts it to the logical size of the widget offsets.
  static Map<String, double> _readLogicalSize(FlutterView view) {
    final size = _readLogicalSizeOf(view);

    return {
      AutomationProtocol.widthKey: size.width,
      AutomationProtocol.heightKey: size.height,
    };
  }
}
