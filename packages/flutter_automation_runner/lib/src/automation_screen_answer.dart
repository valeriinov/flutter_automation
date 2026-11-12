import 'package:flutter_automation_driver/flutter_automation_driver.dart';

/// {@category Utils}
///
/// One answer of the app's `screen.read` command. It holds the screen the app
/// shows, the size of its view, the height of its keyboard and the platform of
/// the app.
final class AutomationScreenAnswer {
  /// Name of the platform the app runs on, such as `iOS` or `android`.
  final String platform;

  /// Height of the keyboard in physical pixels.
  final int keyboardInset;

  /// What the screen reader of the project describes the shown screen by,
  /// missing before the first screen.
  final Map<String, Object?>? screen;

  /// Size of the view, missing when the answer names none of a positive size.
  final AutomationViewSize? view;

  /// Texts the frame shows, in tree order; empty unless the read asked for
  /// them.
  final List<String> texts;

  /// Widget types the frame shows, sorted; empty unless the read asked for
  /// them.
  final List<String> widgets;

  const AutomationScreenAnswer({
    required this.screen,
    required this.view,
    required this.platform,
    required this.keyboardInset,
    this.texts = const [],
    this.widgets = const [],
  });

  /// Reads the decoded answer [json].
  ///
  /// Throws a [StateError] when [json] is not an object with a `platform` and
  /// an `inset`.
  factory AutomationScreenAnswer.fromJson(Object? json) {
    if (json case {
      AutomationProtocol.platformKey: final String platform,
      AutomationProtocol.keyboardInsetKey: final num inset,
    }) {
      return AutomationScreenAnswer(
        screen: _tryReadScreen(json),
        view: _tryReadView(json),
        platform: platform,
        keyboardInset: inset.round(),
        texts: _readStrings(json, AutomationProtocol.textsKey),
        widgets: _readStrings(json, AutomationProtocol.widgetsKey),
      );
    }

    throw StateError(
      'The screen answer is not a {"platform", "inset"} object.',
    );
  }

  /// Whether the app shows a screen other than [splashScreen], which is where
  /// a launch hands the walk its first screen.
  bool isPastSplash(String? splashScreen) {
    final screenName = screen?[AutomationProtocol.screenNameKey];

    return screenName is String && screenName != splashScreen;
  }

  static List<String> _readStrings(Map<Object?, Object?> json, String key) {
    if (json[key] case final List<Object?> strings) {
      return strings.whereType<String>().toList();
    }

    return const [];
  }

  static Map<String, Object?>? _tryReadScreen(Object? json) {
    if (json case {
      AutomationProtocol.screenKey: final Map<String, Object?> screen,
    }) {
      return screen;
    }

    return null;
  }

  static AutomationViewSize? _tryReadView(Object? json) {
    if (json case {
      AutomationProtocol.viewKey: {
        AutomationProtocol.widthKey: final num width,
        AutomationProtocol.heightKey: final num height,
      },
    } when width > 0 && height > 0) {
      return (width: width.toDouble(), height: height.toDouble());
    }

    return null;
  }
}

/// {@category Utils}
///
/// The size of the app's view in logical pixels.
typedef AutomationViewSize = ({double width, double height});
