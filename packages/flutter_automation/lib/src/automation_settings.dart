import 'package:flutter/foundation.dart';

/// Build-time name of the UI automation switch passed as `--dart-define`.
const String _flutterDriverFlag = 'ENABLE_FLUTTER_DRIVER';

/// Build-time name of the semantics switch passed as `--dart-define`.
const String _semanticsFlag = 'ENABLE_AUTOMATION_SEMANTICS';

/// Build-time name of the frame-attribution switch passed as `--dart-define`.
const String _frameProfilingFlag = 'ENABLE_AUTOMATION_FRAME_PROFILING';

const String _markLocaleKeysFlag = 'MARK_LOCALE_KEYS';

/// Settings of the agent-driven UI automation.
///
/// The switch turns on Flutter Driver and the automation targets an agent uses
/// to address widgets while it runs the app on a simulator. Run it with:
///
/// ```shell
/// fvm flutter run --dart-define=ENABLE_FLUTTER_DRIVER=true
/// ```
abstract final class AutomationSettings {
  /// Whether the app accepts UI automation commands from an agent.
  ///
  /// A release build can never enable it: the flag is `kReleaseMode`-gated.
  /// The value is a compile-time constant, so a release build drops every
  /// branch guarded by it together with the automation code it reaches.
  static const bool isEnabled =
      !kReleaseMode && bool.fromEnvironment(_flutterDriverFlag);

  /// Whether an automation run raises the semantics tree.
  ///
  /// The semantics tree is what the native automation layer reads identifiers
  /// from: AXe on iOS and `uiautomator dump` on Android both resolve an
  /// accessibility identifier or a `resource-id` out of it. A run that drops it
  /// keeps only the Flutter Driver finders: `ByValueKey`, `byText` and
  /// `byType`.
  ///
  /// An automation run raises it unless the define is false. A
  /// frame-statistics run sets the define to false. The semantics pass then
  /// costs the traced frames nothing, as in production.
  ///
  /// ```shell
  /// fvm flutter run --dart-define=ENABLE_FLUTTER_DRIVER=true \
  ///   --dart-define=ENABLE_AUTOMATION_SEMANTICS=false
  /// ```
  static const bool isSemanticsEnabled =
      isEnabled && bool.fromEnvironment(_semanticsFlag, defaultValue: true);

  /// Whether a traced frame names the widgets every build stood in and the
  /// render objects every paint stood in.
  ///
  /// A frame summary reads phases off the timeline. The engine's own `BUILD`
  /// and `PAINT` spans are one row each for the whole tree. A frame that spends
  /// 40 ms in build states that much and no more.
  /// Under this switch the framework opens a span per element it rebuilds,
  /// named after its widget type. It also opens a span per render object it
  /// paints, named after its type. The same summary then answers which parts
  /// the time stood in. On the paint side, it also answers which render object
  /// recorded each `saveLayer` that the raster thread then pays for.
  ///
  /// The switch leaves the framework's layout spans off. They open before a
  /// render object answers out of its cached layout. They count the render
  /// objects that a pass visits, not the ones it lays out. A row read off them
  /// names the widest subtree, not the slowest.
  ///
  /// The spans add their own cost to the frame. Read a window walked under
  /// this switch for the shares between its rows, not for their sizes. Take
  /// baselines and gates with this switch off.
  ///
  /// ```shell
  /// fvm flutter run --dart-define=ENABLE_FLUTTER_DRIVER=true \
  ///   --dart-define=ENABLE_AUTOMATION_FRAME_PROFILING=true
  /// ```
  static const bool isFrameProfilingEnabled =
      isEnabled && bool.fromEnvironment(_frameProfilingFlag);

  /// Whether every translation string carries the invisible mark of its locale
  /// key, read back from the rendered text by a screen flows capture.
  ///
  /// Set only by the capture launch, on top of [isEnabled]:
  ///
  /// ```shell
  /// fvm flutter run --dart-define=ENABLE_FLUTTER_DRIVER=true \
  ///   --dart-define=MARK_LOCALE_KEYS=true
  /// ```
  static const bool isLocaleKeyMarkingEnabled =
      isEnabled && bool.fromEnvironment(_markLocaleKeysFlag);
}
