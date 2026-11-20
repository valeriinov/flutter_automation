import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_atlas/headless.dart';
import 'package:flutter_automation_driver/driver_extension.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/example_app.dart';

import 'example_atlas_project.dart';

export 'package:flutter_automation_atlas/headless.dart'
    show AtlasHeadlessLaunch;

/// Runs the example app in the headless walk of the atlas.
///
/// `ExampleAtlasProject.headlessSettings` copies `lib/main.dart` into the
/// entry of the walk. It renames `main`. It replaces three calls: the install
/// of the automation seams and the capture of the mock with members of this
/// class, and `runApp` with `AtlasHeadlessLaunch.runApp`.
abstract final class ExampleHeadless {
  static const _pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  static Widget? _root;
  static AutomationMock? _mock;
  static Future<void> Function()? _runMain;

  /// Stands in for `AutomationInstaller.maybeInstall` in the entry. The walk
  /// has no Flutter Driver, so only the commands that the walk sends exist.
  static void install({
    required AutomationScreenReader screenReader,
    AutomationLocaleApplier? localeApplier,
  }) {
    AutomationDeviceCommands.register(
      screenReader: screenReader,
      localeApplier: localeApplier,
    );
  }

  /// Keeps the mock that the entry builds, so that the walk reads its journal.
  static void captureMock(AutomationMock mock) {
    _mock = mock;
  }

  /// The body of the entry. It walks the inputs and starts the app through
  /// [runMain], the `main` of the app.
  static void runSuite(Future<void> Function() runMain) {
    _runMain = runMain;

    runAtlasHeadlessSuite(
      AtlasHeadlessApp(
        schema: const ExampleAtlasProject().journalSchema,
        device: const AtlasHeadlessDevice(
          size: Size(390, 844),
          pixelRatio: 3,
          topInset: 47,
          bottomInset: 34,
          keyboardHeight: 336,
          platform: TargetPlatform.iOS,
        ),
        launch: _launch,
        mock: _readMock,
        readScreenName: _readScreenName,
        textEntryPause: (_) => Duration.zero,
        close: _reset,
      ),
    );
  }

  static Future<Widget> _launch(
    WidgetTester tester,
    AtlasHeadlessLaunch launch,
  ) async {
    final directory = Directory.systemTemp.createTempSync('example-headless-');

    addTearDown(() => directory.deleteSync(recursive: true));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (_) async => directory.path,
    );
    _reset();

    final root = await launch.runMain(
      tester,
      _runMain ?? () async {},
      afterMain: () => AutomationCommandRegistry.handle(
        jsonEncode({
          'command': MockCommands.scenarioApply,
          'scenario': launch.scenario,
        }),
      ),
    );

    _root = root;

    return root;
  }

  static AutomationMock _readMock() {
    final mock = _mock;

    if (mock == null) {
      throw StateError('The main() of the app built no mock.');
    }

    return mock;
  }

  static String? _readScreenName() {
    final root = _root;

    return root is ExampleApp ? root.screenNameObserver.screenName : null;
  }

  static void _reset() {
    _root = null;
    _mock = null;
  }
}
