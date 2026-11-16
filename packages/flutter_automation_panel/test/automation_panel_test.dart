import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils/sample_panel.dart';

void main() {
  group('Automation Panel Widget Tests', () {
    _automationFlowMapPage_should_setAFailureFromTheResponseSheet();
    _automationFlowMapPage_should_removeAnOverrideWithItsCross();
    _automationFlowMapPage_should_showTheRestartNoteForALaunchKey();
    _automationSectionsPage_should_markProfilesThatNeedARestart();
    _automationPanelLauncher_should_drawItsOwnColorsInAForeignTheme();
    _automationPanelLauncher_should_showTheButtonOnlyWhenVisible();
    _automationPanelLauncher_should_wrapOnlyTheButton();
    _automationPanelLauncher_should_placeTheButtonAtTheStartPosition();
    _automationWalkStrip_should_leadTheWalkActionByAction();
    _automationWalkStrip_should_exitTheWalk();
    _automationAutorunPage_should_saveAnAutorunAndAskForARestart();
    _automationPanelLauncher_should_blockTheFingerWhileAWalkRuns();
    _automationPanelLauncher_should_keepTheBackButtonOnTheFirstScreen();
    _automationPanelLauncher_should_showOnlyTheTouchCircleInAnAutorun();
    _automationFlowMapPage_should_offerTheBranchesThatNeedARestart();
    _automationModeController_should_saveTheModeAndAskForARestart();
    _automationFlowMapPage_should_saveTheWalkAndAskForARestartOnStart();
    _automationSectionsPage_should_replaceTheProfileOfASection();
    _automationSectionsPage_should_offerTheDefaultProfile();
    _automationSectionsPage_should_nameAnUnknownSettingCustom();
    _automationPanelLauncher_should_sendTheBackButtonToThePanel();
    _automationPresetsSheet_should_rejectABadName();
    _automationWalkStrip_should_exitAfterADragFarDown();
    _automationWalkStrip_should_bringTheControlsBackAfterAnAutorunFailure();
    _automationMockModeTile_should_switchTheModeOnAPanelTile();
  });
}

Future<SamplePanel> _pumpPage(
  WidgetTester tester,
  Widget page, {
  AutomationFlowPlayer? player,
  AutomationCatalogue? catalogue,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(780, 1688);

  addTearDown(tester.view.reset);

  final sample = await createSamplePanel(
    tester,
    player: player,
    catalogue: catalogue,
  );

  await tester.pumpWidget(hostApp(child: panelHost(sample, page)));

  return sample;
}

void _automationFlowMapPage_should_setAFailureFromTheResponseSheet() {
  testWidgets(
    'AutomationFlowMapPage should set a failure from the response sheet',
    (tester) async {
      final sample = await _pumpPage(
        tester,
        AutomationFlowMapPage(flow: sampleCatalogue.flows.first),
      );

      await tester.tap(find.text('otp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('429'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(sample.mock.failures[verifyPath]?.statusCode, 429);
    },
  );
}

void _automationFlowMapPage_should_removeAnOverrideWithItsCross() {
  testWidgets(
    'AutomationFlowMapPage should remove an override with its cross',
    (tester) async {
      final sample = await _pumpPage(
        tester,
        AutomationFlowMapPage(flow: sampleCatalogue.flows.first),
      );

      await tester.runAsync(
        () => sample.controller.setFailure(verifyPath, const MockApiFailure()),
      );
      await tester.pump();

      expect(find.text('Override: 500'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pump();

      expect(sample.mock.failures, isEmpty);
    },
  );
}

void _automationFlowMapPage_should_showTheRestartNoteForALaunchKey() {
  testWidgets(
    'AutomationFlowMapPage should show the restart note for a launch key',
    (tester) async {
      await _pumpPage(
        tester,
        AutomationFlowMapPage(flow: sampleCatalogue.flows.first),
      );

      expect(find.textContaining('app restarts'), findsOneWidget);
    },
  );
}

void _automationSectionsPage_should_markProfilesThatNeedARestart() {
  testWidgets(
    'AutomationSectionsPage should mark profiles that need a restart',
    (tester) async {
      final sample = await _pumpPage(tester, const SizedBox());

      await tester.pumpWidget(
        hostApp(child: panelHost(sample, const AutomationPanel(initialTab: 1))),
      );
      await tester.tap(find.text('Profile').first);
      await tester.pumpAndSettle();

      expect(find.text('⟳ Restarts the app'), findsNWidgets(2));
    },
  );
}

void _automationPanelLauncher_should_drawItsOwnColorsInAForeignTheme() {
  testWidgets(
    'AutomationPanelLauncher should draw its own colors in a foreign theme',
    (tester) async {
      final sample = await _pumpPage(tester, const SizedBox());

      final foreign = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      );

      sample.controller.openPanel();

      await tester.pumpWidget(
        hostApp(
          theme: foreign,
          child: AutomationPanelLauncher(
            controller: sample.controller,
            isVisible: true,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final frame = tester.element(find.byType(AutomationPanelFrame));
      final tab = tester.widget<Text>(find.text('Flows').last);

      expect(Theme.of(frame).colorScheme.primary, sampleTheme.accent);
      expect(tab.style?.color, sampleTheme.accent);
    },
  );
}

void _automationPanelLauncher_should_showTheButtonOnlyWhenVisible() {
  testWidgets(
    'AutomationPanelLauncher should show the button only when visible',
    (tester) async {
      final sample = await _pumpPage(tester, const SizedBox());

      Widget launcher({required bool isVisible}) {
        return hostApp(
          child: AutomationPanelLauncher(
            controller: sample.controller,
            isVisible: isVisible,
            child: const SizedBox(),
          ),
        );
      }

      await tester.pumpWidget(launcher(isVisible: false));

      expect(find.text('QA'), findsNothing);

      await tester.pumpWidget(launcher(isVisible: true));

      expect(find.text('QA'), findsOneWidget);
    },
  );
}

void _automationPanelLauncher_should_wrapOnlyTheButton() {
  testWidgets('AutomationPanelLauncher should wrap only the button', (
    tester,
  ) async {
    final sample = await _pumpPage(tester, const SizedBox());

    await tester.pumpWidget(
      hostApp(
        child: AutomationPanelLauncher(
          controller: sample.controller,
          isVisible: true,
          wrapButton: (button) =>
              KeyedSubtree(key: const ValueKey('marked'), child: button),
          child: const SizedBox(),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('marked')),
        matching: find.text('QA'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('marked')), findsOneWidget);
  });
}

void _automationPanelLauncher_should_placeTheButtonAtTheStartPosition() {
  testWidgets(
    'AutomationPanelLauncher should place the button at the start position',
    (tester) async {
      final sample = await _pumpPage(tester, const SizedBox());

      await tester.pumpWidget(
        hostApp(
          child: AutomationPanelLauncher(
            controller: sample.controller,
            isVisible: true,
            startPosition: (size, padding) => const Offset(20, 300),
            child: const SizedBox(),
          ),
        ),
      );

      final button = find.ancestor(
        of: find.text('QA'),
        matching: find.byType(Container),
      );

      expect(tester.getTopLeft(button.first), const Offset(20, 300));
    },
  );
}

Future<SamplePanel> _pumpStrip(WidgetTester tester) async {
  final sample = await _pumpPage(
    tester,
    const SizedBox(),
    player: RecordingPlayer(),
  );

  await tester.runAsync(
    () => sample.controller.startWalk('login', 'signUpNeeded'),
  );

  sample.controller.toggleWalk();

  await tester.pumpWidget(
    hostApp(
      child: panelHost(
        sample,
        Align(
          alignment: Alignment.topCenter,
          child: AutomationWalkStrip(controller: sample.controller),
        ),
      ),
    ),
  );

  return sample;
}

void _automationWalkStrip_should_leadTheWalkActionByAction() {
  testWidgets('AutomationWalkStrip should lead the walk action by action', (
    tester,
  ) async {
    final sample = await _pumpStrip(tester);

    expect(find.textContaining('step 1 of 2'), findsOneWidget);
    expect(find.text('Type the code'), findsOneWidget);

    await tester.tap(find.text('Next step'));
    await _settle(
      tester,
      until: () => _isShown(find.text('CHOOSE THE BRANCH')),
    );
    await _settle(tester, until: () => !sample.controller.isWalkBusy);

    expect(find.text('CHOOSE THE BRANCH'), findsOneWidget);
    expect(find.text('Next step'), findsOneWidget);

    await tester.tap(find.text('Account exists'));
    await tester.pump();
    await tester.tap(find.text('Next step'));
    await _settle(
      tester,
      until: () => _isShown(find.text(AutomationPanelStrings.finish)),
    );

    expect(sample.mock.walk?.variant, 'accountExists');

    await tester.tap(find.text(AutomationPanelStrings.finish));
    await _settle(tester, until: () => sample.controller.runSummary != null);

    expect(sample.controller.runSummary?.mode, AutomationWalkMode.manual);
  });
}

void _automationWalkStrip_should_exitTheWalk() {
  testWidgets('AutomationWalkStrip should exit the walk', (tester) async {
    final sample = await _pumpStrip(tester);

    await tester.tap(find.text('Exit'));
    await _settle(tester, until: () => _isGone(find.text('Next step')));

    expect(sample.mock.walk, isNull);
    expect(find.text('Next step'), findsNothing);
  });
}

void _automationAutorunPage_should_saveAnAutorunAndAskForARestart() {
  testWidgets(
    'AutomationAutorunPage should save an autorun and ask to restart',
    (tester) async {
      final sample = await _pumpPage(
        tester,
        const AutomationAutorunPage(),
        player: RecordingPlayer(),
      );

      await tester.tap(find.byType(Switch).first);
      await tester.tap(find.text('Restart and run'));
      await _settle(tester, until: () => sample.events.isNotEmpty);

      expect(sample.mock.walk?.mode, AutomationWalkMode.autorun);
      expect(sample.mock.walk?.flow, 'login');
      expect(sample.mock.walk?.shouldShowTouches, isFalse);
      expect(sample.events, ['restart']);
    },
  );
}

Widget _launcherOver(SamplePanel sample, Widget child) {
  return hostApp(
    child: AutomationPanelLauncher(
      controller: sample.controller,
      isVisible: true,
      child: child,
    ),
  );
}

void _automationPanelLauncher_should_blockTheFingerWhileAWalkRuns() {
  testWidgets('AutomationPanelLauncher should block the finger in a walk', (
    tester,
  ) async {
    int taps = 0;

    final sample = await _pumpPage(
      tester,
      const SizedBox(),
      player: RecordingPlayer(),
    );

    await tester.pumpWidget(
      _launcherOver(
        sample,
        Center(
          child: ElevatedButton(
            onPressed: () => taps += 1,
            child: const Text('App button'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('App button'));

    expect(taps, 1);

    await tester.runAsync(
      () => sample.controller.startWalk('login', 'signUpNeeded'),
    );
    await tester.pump();
    await tester.tap(find.text('App button'), warnIfMissed: false);

    expect(taps, 1);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.runAsync(sample.controller.exitWalk);
    await tester.pump();
    await tester.tap(find.text('App button'));

    expect(taps, 2);
  });
}

void _automationPanelLauncher_should_showOnlyTheTouchCircleInAnAutorun() {
  testWidgets('AutomationPanelLauncher should show no controls in an autorun', (
    tester,
  ) async {
    final release = Completer<void>();

    final sample = await _pumpPage(
      tester,
      const SizedBox(),
      player: RecordingPlayer(hold: release.future),
    );

    await tester.pumpWidget(_launcherOver(sample, const SizedBox()));

    expect(find.text('QA'), findsOneWidget);

    await tester.runAsync(
      () => sample.controller.startWalk(
        'login',
        'signUpNeeded',
        mode: AutomationWalkMode.autorun,
        shouldSignalEnd: false,
      ),
    );

    unawaited(sample.controller.runWalk());

    await tester.pump();

    expect(find.text('QA'), findsNothing);
    expect(find.text('Exit'), findsNothing);
    expect(find.byType(AutomationTouchIndicator), findsOneWidget);
    release.complete();

    await _settle(tester, until: () => sample.controller.runSummary != null);
  });
}

void _automationFlowMapPage_should_offerTheBranchesThatNeedARestart() {
  testWidgets('AutomationFlowMapPage should offer the branches of a restart', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      AutomationFlowMapPage(flow: sessionFlow),
      catalogue: sampleCatalogueWithSession,
    );

    expect(find.text('Signed in'), findsWidgets);
    expect(find.text('Signed out'), findsOneWidget);
    expect(find.text('Set state'), findsNothing);
    expect(find.text('Apply and start'), findsNothing);
  });
}

void _automationModeController_should_saveTheModeAndAskForARestart() {
  test(
    'AutomationModeController should save the mode and ask for a restart',
    () async {
      final directory = Directory.systemTemp.createTempSync('mode_controller');
      final store = AutomationStateStore(directory.path);
      int restarts = 0;
      final controller = AutomationModeController(
        store: store,
        mode: AutomationMode.server,
        onRestartRequired: () => restarts += 1,
      );

      await store.write(const AutomationState(scenario: {'latency': 'fast'}));
      await controller.switchTo(AutomationMode.mock);

      final saved =
          jsonDecode(File('${directory.path}/state.json').readAsStringSync())
              as Map<String, Object?>;

      directory.deleteSync(recursive: true);
      expect(saved['mode'], 'mock');
      expect(saved['scenario'], {'latency': 'fast'});
      expect(restarts, 1);
      expect(controller.nextMode, AutomationMode.mock);
      expect(controller.mode, AutomationMode.server);
    },
  );
}

bool _isShown(Finder finder) => finder.evaluate().isNotEmpty;

bool _isGone(Finder finder) => finder.evaluate().isEmpty;

Future<void> _settle(WidgetTester tester, {bool Function()? until}) async {
  final rounds = until == null ? 30 : 500;

  for (int round = 0; round < rounds; round += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();

    if (until?.call() ?? false) {
      break;
    }
  }

  await tester.pumpAndSettle();
}

Future<SamplePanel> _pumpSections(WidgetTester tester) async {
  final sample = await _pumpPage(tester, const SizedBox());

  await tester.pumpWidget(
    hostApp(child: panelHost(sample, const AutomationPanel(initialTab: 1))),
  );

  return sample;
}

Object? _authSettings(SamplePanel sample) {
  return sample.mock.scenario.toJson()['auth'];
}

void _automationFlowMapPage_should_saveTheWalkAndAskForARestartOnStart() {
  testWidgets(
    'AutomationFlowMapPage should save the walk and ask for a restart',
    (tester) async {
      final sample = await _pumpPage(
        tester,
        AutomationFlowMapPage(flow: sampleCatalogue.flows.first),
      );

      sample.controller.openPanel();

      await tester.tap(find.text('Restart and begin'));
      await _settle(tester, until: () => sample.events.isNotEmpty);

      expect(sample.mock.walk?.flow, 'login');
      expect(sample.mock.walk?.mode, AutomationWalkMode.manual);
      expect(sample.events, ['restart']);
      expect(sample.controller.isPanelOpen, isTrue);
    },
  );
}

void _automationSectionsPage_should_replaceTheProfileOfASection() {
  testWidgets(
    'AutomationSectionsPage should replace the profile of a section',
    (tester) async {
      final sample = await _pumpSections(tester);

      await tester.tap(find.text('Profile').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign-up needed'));
      await _settle(tester);
      await tester.tap(find.text('Profile').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Slow code'));
      await _settle(tester);

      expect(_authSettings(sample), {'codeDelay': 3});
    },
  );
}

void _automationSectionsPage_should_offerTheDefaultProfile() {
  testWidgets('AutomationSectionsPage should offer the default profile', (
    tester,
  ) async {
    final sample = await _pumpSections(tester);

    await tester.tap(find.text('Profile').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slow code'));
    await _settle(tester);
    await tester.tap(find.text('Profile').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AutomationPanelRadioTile),
        matching: find.text('Default'),
      ),
    );
    await _settle(tester);

    expect(_authSettings(sample), isNull);
  });
}

void _automationSectionsPage_should_nameAnUnknownSettingCustom() {
  testWidgets('AutomationSectionsPage should name an unknown setting Custom', (
    tester,
  ) async {
    final sample = await _pumpPage(tester, const SizedBox());

    await tester.runAsync(
      () => sample.controller.updateScenario(
        MockScenario.fromJson(const {
          'auth': {'codeDelay': 9},
        }),
      ),
    );
    await tester.pumpWidget(
      hostApp(child: panelHost(sample, const AutomationPanel(initialTab: 1))),
    );

    expect(find.text('Custom'), findsOneWidget);
  });
}

void _automationPanelLauncher_should_sendTheBackButtonToThePanel() {
  testWidgets(
    'AutomationPanelLauncher should send the back button to the panel',
    (tester) async {
      final sample = await _pumpPage(tester, const SizedBox());

      sample.controller.openPanel();

      await tester.pumpWidget(
        hostApp(
          child: AutomationPanelLauncher(
            controller: sample.controller,
            isVisible: true,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign-in and sign-up'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Create an item'), findsOneWidget);
      expect(sample.controller.isPanelOpen, isTrue);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(sample.controller.isPanelOpen, isFalse);
    },
  );
}

void _automationPresetsSheet_should_rejectABadName() {
  testWidgets('AutomationPresetsSheet should reject a bad name', (
    tester,
  ) async {
    await _pumpSections(tester);
    await tester.tap(find.text('Presets'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '..');
    await tester.tap(find.text('Save current state'));
    await _settle(tester);

    expect(find.text('Use a name without a slash.'), findsOneWidget);
  });
}

void _automationWalkStrip_should_exitAfterADragFarDown() {
  testWidgets('AutomationWalkStrip should exit after a drag far down', (
    tester,
  ) async {
    final sample = await _pumpPage(
      tester,
      const SizedBox(),
      player: RecordingPlayer(),
    );

    await tester.runAsync(
      () => sample.controller.startWalk('login', 'signUpNeeded'),
    );
    await tester.pumpWidget(_launcherOver(sample, const SizedBox()));

    final title = find.textContaining('1/2', findRichText: true);
    final before = tester.getTopLeft(title);

    await tester.drag(title, const Offset(0, 400));
    await tester.pump();

    expect(tester.getTopLeft(title).dy - before.dy, greaterThan(300));

    await tester.tap(find.byIcon(Icons.close));
    await _settle(tester, until: () => sample.mock.walk == null);

    expect(sample.mock.walk, isNull);
  });
}

void _automationWalkStrip_should_bringTheControlsBackAfterAnAutorunFailure() {
  testWidgets('AutomationWalkStrip should retry an autorun after a failure', (
    tester,
  ) async {
    final player = RecordingPlayer(failingLabel: 'After code entry');

    final sample = await _pumpPage(tester, const SizedBox(), player: player);

    await tester.runAsync(
      () => sample.controller.startWalk(
        'login',
        'signUpNeeded',
        mode: AutomationWalkMode.autorun,
        shouldSignalEnd: false,
      ),
    );
    await tester.pumpWidget(_launcherOver(sample, const SizedBox()));
    await _settle(tester, until: () => sample.controller.walkFailure != null);

    expect(find.text('QA'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('did not appear'), findsOneWidget);

    player.failingLabel = null;

    await tester.tap(find.text('Try again'));
    await _settle(tester, until: () => sample.controller.runSummary != null);

    expect(sample.controller.runSummary, isNotNull);
  });
}

void _automationMockModeTile_should_switchTheModeOnAPanelTile() {
  testWidgets('AutomationMockModeTile should switch the mode on a panel tile', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('mode_tile');
    int restarts = 0;
    final controller = AutomationModeController(
      store: AutomationStateStore(directory.path),
      mode: AutomationMode.server,
      onRestartRequired: () => restarts += 1,
    );

    addTearDown(() => directory.deleteSync(recursive: true));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      hostApp(child: AutomationMockModeTile(controller: controller)),
    );

    expect(find.byType(AutomationPanelSwitchTile), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await _settle(tester, until: () => restarts > 0);

    expect(controller.nextMode, AutomationMode.mock);
  });
}

void _automationPanelLauncher_should_keepTheBackButtonOnTheFirstScreen() {
  testWidgets(
    'AutomationPanelLauncher should keep the back button on the first screen',
    (tester) async {
      final reports = <Object?>[];

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
            reports.add(call.arguments);
          }

          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      final sample = await _pumpPage(
        tester,
        const SizedBox(),
        player: RecordingPlayer(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: SizedBox()),
          builder: (context, child) => AutomationPanelLauncher(
            controller: sample.controller,
            isVisible: true,
            child: child ?? const SizedBox(),
          ),
        ),
      );
      await tester.runAsync(
        () => sample.controller.startWalk('login', 'signUpNeeded'),
      );
      await tester.pump();

      expect(reports.last, isTrue);

      await tester.tap(find.byIcon(Icons.close));
      await _settle(tester, until: () => reports.last == false);

      expect(reports.last, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
