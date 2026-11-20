import 'package:flutter/widgets.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_journal_schema.dart';

/// {@category Utils}
///
/// The view a headless walk renders the app on, and the keyboard it raises:
/// the physical screen of the capture device.
final class AtlasHeadlessDevice {
  /// The size of the view, in logical pixels.
  final Size size;

  /// The device pixel ratio of the view.
  final double pixelRatio;

  /// The top safe area inset, in logical pixels.
  final double topInset;

  /// The bottom safe area inset, in logical pixels, while no keyboard shows.
  final double bottomInset;

  /// The height of the keyboard, in logical pixels, while it shows.
  final double keyboardHeight;

  /// The platform a walk runs on: the platform of the captured snapshots.
  final TargetPlatform platform;

  /// Tells the app that the keyboard showed or hid, the way the platform
  /// tells it; `null` when the app listens to no such event.
  final void Function(WidgetTester tester, {required bool isShown})?
  onKeyboardVisibilityChanged;

  const AtlasHeadlessDevice({
    required this.size,
    required this.pixelRatio,
    required this.topInset,
    required this.bottomInset,
    required this.keyboardHeight,
    required this.platform,
    this.onKeyboardVisibilityChanged,
  });
}

/// {@category Utils}
///
/// What a headless walk hands to [AtlasHeadlessApp.launch].
///
/// It holds the scenario of the variant and the moments the mock runs on. It
/// holds the values that the project read out of the journal of the snapshot.
/// It starts the patched `main` of the app and captures the widget that the
/// `main` runs.
final class AtlasHeadlessLaunch {
  static Widget? _capturedRoot;

  /// The scenario of the variant, as JSON.
  final Map<String, Object?> scenario;

  /// The anchor the mock seeds its dates on and the moment the app launches
  /// at, in local time; `null` when the walk takes none.
  final ({DateTime anchor, DateTime launchedAt})? moments;

  /// The values [AtlasHeadlessSettings.tryReadRecordedValues] read, `null`
  /// when it read none.
  final Map<String, Object?>? recordedValues;

  DateTime _launchedAt = DateTime.now();

  AtlasHeadlessLaunch({
    required this.scenario,
    required this.moments,
    required this.recordedValues,
  });

  /// The moment the app launched at, which the walk uses to tell a clock text
  /// from the recorded texts.
  ///
  /// The walk sets it when it creates the launch, before [launch] runs.
  /// [runMain] sets it again right before it runs the `main` of the app, after
  /// the pre-launch work of the hook.
  DateTime get launchedAt => _launchedAt;

  /// Stands in for `runApp` in the patched `main`: keeps [app] for [runMain]
  /// to return.
  static void runApp(Widget app) {
    _capturedRoot = app;
  }

  /// Runs the patched [main] of the app through `tester.runAsync`. Returns the
  /// widget that [main] handed to [runApp].
  ///
  /// It sets [launchedAt] right before it runs [main]. It runs [afterMain]
  /// after [main], in the same real-time zone. It throws a [StateError] when
  /// [main] handed [runApp] no widget.
  Future<Widget> runMain(
    WidgetTester tester,
    Future<void> Function() main, {
    Future<void> Function()? afterMain,
  }) async {
    _capturedRoot = null;

    await tester.runAsync(() async {
      _launchedAt = DateTime.now();

      await main();
      await afterMain?.call();
    });

    final root = _capturedRoot;

    _capturedRoot = null;

    if (root == null) {
      throw StateError('The main() of the app handed runApp no widget.');
    }

    return root;
  }
}

/// {@category Utils}
///
/// The app under test.
///
/// `runAtlasHeadlessSuite` walks the steps, reads the frames and the journal,
/// applies the locale and waits. The hooks give what only the app knows.
final class AtlasHeadlessApp {
  /// The journal schema of the project, which cleans the records of the walk.
  final AtlasJournalSchema schema;

  /// The view of the walk.
  final AtlasHeadlessDevice device;

  /// Launches the app on the in-app mock and answers the root widget it runs.
  ///
  /// The walk sizes the view and clears the asset bundle first. It renders
  /// the answered widget when the hook returns. The hook stands in for the
  /// platform side that a widget test lacks, and it runs the startup of the
  /// app. It seeds the mock from [AtlasHeadlessLaunch.scenario] and
  /// [AtlasHeadlessLaunch.moments]. The patched `main` of the app calls
  /// [AtlasHeadlessLaunch.runApp] in place of `runApp`; the hook starts it
  /// with [AtlasHeadlessLaunch.runMain], which takes the real time it needs.
  ///
  /// The walk sets [AtlasHeadlessLaunch.launchedAt] before the hook runs.
  /// [AtlasHeadlessLaunch.runMain] sets it again right before it runs `main`,
  /// after the pre-launch work of the hook.
  final Future<Widget> Function(WidgetTester tester, AtlasHeadlessLaunch launch)
  launch;

  /// The mock the app runs on. The walk reads its journal and waits for its
  /// answers. The walk calls this function after [launch] returns.
  final AutomationMock Function() mock;

  /// The name of the screen the app shows while it starts; `null` when it
  /// shows none.
  final String? splashScreen;

  /// The name of the screen the app logged last, `null` before it logged
  /// one. The walk applies the locale once it names a screen other than
  /// [splashScreen].
  final String? Function() readScreenName;

  /// How long the walk waits after it typed into the focused field, whose
  /// [BuildContext] it passes: the debounce of the app.
  final Duration Function(BuildContext fieldContext) textEntryPause;

  /// Disposes what the app leaves active once the walk unmounts it; `null`
  /// when it leaves none.
  final void Function()? close;

  const AtlasHeadlessApp({
    required this.schema,
    required this.device,
    required this.launch,
    required this.mock,
    required this.readScreenName,
    required this.textEntryPause,
    this.splashScreen,
    this.close,
  });
}
