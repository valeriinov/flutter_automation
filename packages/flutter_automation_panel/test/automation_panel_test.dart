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
    _automationPanel_should_nameAChangedMockWithNoOutcomeCustom();
    _automationSectionsPage_should_describeTheDelayOfTheLatency();
    _automationResponseSheet_should_applyALatencyWithTheMockAnswer();
    _automationResponseSheet_should_clearBothOverridesOnUseMockResponse();
    _automationResponseSheet_should_dropTheErrorOnASecondTapOfItsCode();
    _automationResponseSheet_should_followEveryRequestOnATapOfItsLatency();
    _automationResponseSheet_should_keepALatencyEqualToEveryRequest();
    _automationResponseSheet_should_keepTheMessageKeyOfTheInitialFailure();
    _automationResponseSheet_should_keepTheMessageKeyOnAStatusChange();
    _automationResponseSheet_should_dropTheMessageKeyOnAnotherErrorCode();
    _automationResponseSheet_should_dropTheMessageKeyOnATypedMessage();
    _automationResponseSheet_should_takeTheStatusOfAChosenBackendErrorCode();
    _automationResponseSheet_should_offerOnlyTheStatusesOfAChosenCode();
    _automationResponseSheet_should_leaveOutCodesAChosenStatusDoesNotComeWith();
    _automationResponseSheet_should_dropACodeAStatusDoesNotComeWith();
    _automationResponseSheet_should_keepTheStatusOfACodeWithTheStatusCleared();
    _automationResponseSheet_should_answer500ForACodeWithoutStatuses();
    _automationResponseSheet_should_openASavedErrorOutsideItsStatuses();
    _automationPanelLauncher_should_sendTheBackButtonToThePanel();
    _automationPresetsSheet_should_rejectABadName();
    _automationAutorunPage_should_narrowTheFlowsBySearch();
    _automationSectionsPage_should_narrowTheSectionsBySearch();
    _automationJournalPage_should_narrowTheRequestsBySearch();
    _matchesSearchQuery_should_ignoreCaseAndMatchAnEmptyQuery();
    _automationJournalPage_should_tellAnAnswerGivenByAnOverride();
    _automationJournalPage_should_clearTheJournal();
    _automationChangesPage_should_listAndRemoveTheChanges();
    _automationChangesPage_should_resetAll();
    _automationChangesPage_should_keepTheChangesOnCancel();
    _automationSectionsPage_should_describeTheProfiles();
    _automationSectionsPage_should_narrowTheProfilesBySearch();
    _automationPanel_should_openTheChangesFromTheStatusRow();
    _automationWalkStrip_should_exitAfterADragFarDown();
    _automationWalkStrip_should_bringTheControlsBackAfterAnAutorunFailure();
    _automationMockModeTile_should_switchTheModeOnAPanelTile();
    _automationSectionsPage_should_askBeforeAProfileThatRestarts();
    _automationPresetsSheet_should_askBeforeAPresetThatRestarts();
    _automationChangesPage_should_askBeforeARemovalThatRestarts();
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

      expect(
        find.textContaining(sampleStrings.restartsTheApp),
        findsNWidgets(2),
      );
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
      until: () => _isShown(find.text(sampleStrings.finish)),
    );

    expect(sample.mock.walk?.variant, 'accountExists');

    await tester.tap(find.text(sampleStrings.finish));
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
      await _settle(tester, until: () => sample.isRestartRequired.value);

      expect(sample.mock.walk?.mode, AutomationWalkMode.autorun);
      expect(sample.mock.walk?.flow, 'login');
      expect(sample.mock.walk?.shouldShowTouches, isFalse);
      expect(sample.isRestartRequired.value, isTrue);
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
      final isRestartRequired = ValueNotifier(false);

      addTearDown(isRestartRequired.dispose);

      final controller = AutomationModeController(
        store: store,
        mode: AutomationMode.server,
        isRestartRequired: isRestartRequired,
      );

      await store.write(const AutomationState(scenario: {'latency': 'fast'}));
      await controller.switchTo(AutomationMode.mock);

      final saved =
          jsonDecode(File('${directory.path}/state.json').readAsStringSync())
              as Map<String, Object?>;

      directory.deleteSync(recursive: true);
      expect(saved['mode'], 'mock');
      expect(saved['scenario'], {'latency': 'fast'});
      expect(isRestartRequired.value, isTrue);
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
      await _settle(tester, until: () => sample.isRestartRequired.value);

      expect(sample.mock.walk?.flow, 'login');
      expect(sample.mock.walk?.mode, AutomationWalkMode.manual);
      expect(sample.isRestartRequired.value, isTrue);
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
      await tester.pumpAndSettle();
      await tester.tap(find.text(sampleStrings.apply));
      await _settle(tester);
      await tester.tap(find.text('Profile').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Slow code'));
      await _settle(tester);

      expect(find.text(sampleStrings.restartQuestion), findsNothing);
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

void _automationPanel_should_nameAChangedMockWithNoOutcomeCustom() {
  testWidgets(
    'AutomationPanel should name a changed mock with no outcome custom',
    (tester) async {
      await _pumpSections(tester);

      expect(find.text(sampleStrings.defaultMock), findsOneWidget);

      await tester.tap(find.text(sampleStrings.latencySlow));
      await _settle(tester);

      expect(find.text(sampleStrings.defaultMock), findsNothing);
      expect(
        find.text('${sampleStrings.customMock} · 1 change', findRichText: true),
        findsOneWidget,
      );
    },
  );
}

void _automationSectionsPage_should_describeTheDelayOfTheLatency() {
  testWidgets(
    'AutomationSectionsPage should describe the delay of the latency',
    (tester) async {
      await _pumpSections(tester);

      expect(find.text(sampleStrings.delayOf(150, 400)), findsOneWidget);

      await tester.tap(find.text(sampleStrings.latencySlow));
      await _settle(tester);

      expect(find.text(sampleStrings.delayOf(1000, 3000)), findsOneWidget);

      await tester.tap(find.text(sampleStrings.latencyFast));
      await _settle(tester);

      expect(find.text(sampleStrings.noDelay), findsOneWidget);
    },
  );
}

void _automationResponseSheet_should_applyALatencyWithTheMockAnswer() {
  testWidgets(
    'AutomationResponseSheet should apply a latency with the mock answer',
    (tester) async {
      final applied = <(MockApiFailure?, MockLatencyProfile?)>[];

      await _pumpResponseSheet(tester, applied);
      await tester.tap(find.text(sampleStrings.latencySlow));
      await tester.pump();

      expect(find.text(sampleStrings.delayOf(1000, 3000)), findsOne);

      await tester.tap(find.text(sampleStrings.apply));
      await tester.pump();

      expect(applied, [(null, MockLatencyProfile.slow)]);
    },
  );
}

void _automationResponseSheet_should_clearBothOverridesOnUseMockResponse() {
  testWidgets(
    'AutomationResponseSheet should clear both overrides on use mock response',
    (tester) async {
      final applied = <(MockApiFailure?, MockLatencyProfile?)>[];

      await _pumpResponseSheet(
        tester,
        applied,
        initial: const MockApiFailure(statusCode: 429),
        initialLatency: MockLatencyProfile.slow,
      );

      expect(find.text(sampleStrings.delayOf(1000, 3000)), findsOne);

      await tester.tap(find.text(sampleStrings.useMockResponse));
      await tester.pump();

      expect(applied, [(null, null)]);
    },
  );
}

void _automationResponseSheet_should_dropTheErrorOnASecondTapOfItsCode() {
  testWidgets(
    'AutomationResponseSheet should drop the error on a second tap of its code',
    (tester) async {
      final applied = <(MockApiFailure?, MockLatencyProfile?)>[];

      await _pumpResponseSheet(
        tester,
        applied,
        initial: const MockApiFailure(statusCode: 429),
        initialLatency: MockLatencyProfile.slow,
      );
      await tester.tap(find.text('429'));
      await tester.pump();
      await tester.tap(find.text(sampleStrings.apply));
      await tester.pump();

      expect(applied, [(null, MockLatencyProfile.slow)]);
    },
  );
}

void _automationResponseSheet_should_followEveryRequestOnATapOfItsLatency() {
  testWidgets(
    'AutomationResponseSheet should follow every request on a tap of its '
    'latency',
    (tester) async {
      final applied = <(MockApiFailure?, MockLatencyProfile?)>[];

      await _pumpResponseSheet(
        tester,
        applied,
        initialLatency: MockLatencyProfile.slow,
      );
      await tester.tap(find.text(sampleStrings.latencyRealistic));
      await tester.pump();

      expect(
        find.text(
          sampleStrings.asEveryRequest(sampleStrings.delayOf(150, 400)),
        ),
        findsOne,
      );

      await tester.tap(find.text(sampleStrings.apply));
      await tester.pump();

      expect(applied, [(null, null)]);
    },
  );
}

void _automationResponseSheet_should_keepALatencyEqualToEveryRequest() {
  testWidgets(
    'AutomationResponseSheet should keep a latency equal to every request',
    (tester) async {
      final applied = <(MockApiFailure?, MockLatencyProfile?)>[];

      await _pumpResponseSheet(
        tester,
        applied,
        initialLatency: MockLatencyProfile.realistic,
      );
      await tester.tap(find.text('429'));
      await tester.pump();
      await tester.tap(find.text(sampleStrings.apply));
      await tester.pump();

      expect(applied, [
        (const MockApiFailure(statusCode: 429), MockLatencyProfile.realistic),
      ]);
    },
  );
}

void _automationResponseSheet_should_keepTheMessageKeyOfTheInitialFailure() {
  testWidgets(
    'AutomationResponseSheet should keep the message key of the initial '
    'failure',
    (tester) async {
      final applied = <(MockApiFailure?, MockLatencyProfile?)>[];

      await _pumpResponseSheet(
        tester,
        applied,
        initial: const MockApiFailure(
          statusCode: 429,
          messageKey: 'rateLimited',
        ),
      );
      await tester.tap(find.text(sampleStrings.apply));
      await tester.pump();

      expect(applied, [
        (
          const MockApiFailure(statusCode: 429, messageKey: 'rateLimited'),
          null,
        ),
      ]);
    },
  );
}

void _automationResponseSheet_should_keepTheMessageKeyOnAStatusChange() {
  testWidgets(
    'AutomationResponseSheet should keep the message key on a status change',
    (tester) async {
      final applied = <(MockApiFailure?, MockLatencyProfile?)>[];

      await _pumpResponseSheet(
        tester,
        applied,
        initial: const MockApiFailure(
          statusCode: 429,
          messageKey: 'rateLimited',
        ),
      );
      await tester.tap(find.text('503'));
      await tester.pump();
      await tester.tap(find.text(sampleStrings.apply));
      await tester.pump();

      expect(applied, [
        (
          const MockApiFailure(statusCode: 503, messageKey: 'rateLimited'),
          null,
        ),
      ]);
    },
  );
}

void _automationResponseSheet_should_dropTheMessageKeyOnAnotherErrorCode() {
  testWidgets(
    'AutomationResponseSheet should drop the message key on another error '
    'code',
    (tester) async {
      final applied = <(MockApiFailure?, MockLatencyProfile?)>[];

      await _pumpResponseSheet(
        tester,
        applied,
        initial: const MockApiFailure(
          statusCode: 429,
          messageKey: 'rateLimited',
        ),
        hasErrorStatuses: true,
      );
      await tester.tap(find.text('invalidPhone'));
      await tester.pump();
      await tester.tap(find.text(sampleStrings.apply));
      await tester.pump();

      expect(applied, [
        (
          const MockApiFailure(statusCode: 429, errorCode: 'invalidPhone'),
          null,
        ),
      ]);
    },
  );
}

void _automationResponseSheet_should_dropTheMessageKeyOnATypedMessage() {
  testWidgets(
    'AutomationResponseSheet should drop the message key on a typed message',
    (tester) async {
      final applied = <(MockApiFailure?, MockLatencyProfile?)>[];

      await _pumpResponseSheet(
        tester,
        applied,
        initial: const MockApiFailure(
          statusCode: 429,
          messageKey: 'rateLimited',
        ),
      );
      await tester.enterText(find.byType(TextField), 'Try again later');
      await tester.pump();
      await tester.tap(find.text(sampleStrings.apply));
      await tester.pump();

      expect(applied, [
        (
          const MockApiFailure(statusCode: 429, message: 'Try again later'),
          null,
        ),
      ]);
    },
  );
}

void _automationResponseSheet_should_takeTheStatusOfAChosenBackendErrorCode() {
  testWidgets(
    'AutomationResponseSheet should take the status of a chosen backend error '
    'code',
    (tester) async {
      final applied = <(MockApiFailure?, MockLatencyProfile?)>[];

      await _pumpResponseSheet(tester, applied, hasErrorStatuses: true);
      await tester.tap(find.text('tokenExpired'));
      await tester.pump();
      await tester.tap(find.text(sampleStrings.apply));
      await tester.pump();

      expect(applied, [
        (
          const MockApiFailure(statusCode: 401, errorCode: 'tokenExpired'),
          null,
        ),
      ]);
    },
  );
}

void _automationResponseSheet_should_offerOnlyTheStatusesOfAChosenCode() {
  testWidgets(
    'AutomationResponseSheet should offer only the statuses of a chosen code',
    (tester) async {
      await _pumpResponseSheet(tester, [], hasErrorStatuses: true);
      await tester.tap(find.text('tokenExpired'));
      await tester.pump();

      expect(find.text('401'), findsOne);
      expect(find.text('500'), findsNothing);
    },
  );
}

void
_automationResponseSheet_should_leaveOutCodesAChosenStatusDoesNotComeWith() {
  testWidgets(
    'AutomationResponseSheet should leave out codes a chosen status does not '
    'come with',
    (tester) async {
      await _pumpResponseSheet(tester, [], hasErrorStatuses: true);
      await tester.tap(find.text('500'));
      await tester.pump();

      expect(find.text('tokenExpired'), findsNothing);
      expect(find.text('invalidPhone'), findsOne);
    },
  );
}

void _automationResponseSheet_should_dropACodeAStatusDoesNotComeWith() {
  testWidgets(
    'AutomationResponseSheet should drop a code a status does not come with',
    (tester) async {
      final applied = <(MockApiFailure?, MockLatencyProfile?)>[];

      await _pumpResponseSheet(
        tester,
        applied,
        initial: const MockApiFailure(
          statusCode: 401,
          errorCode: 'tokenExpired',
        ),
        hasErrorStatuses: true,
      );
      await tester.tap(find.text(sampleStrings.custom).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '500');
      await tester.tap(find.text(sampleStrings.ok));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sampleStrings.apply));
      await tester.pump();

      expect(applied, [(const MockApiFailure(), null)]);
    },
  );
}

void
_automationResponseSheet_should_keepTheStatusOfACodeWithTheStatusCleared() {
  testWidgets(
    'AutomationResponseSheet should keep the status of a code with the status '
    'cleared',
    (tester) async {
      final applied = <(MockApiFailure?, MockLatencyProfile?)>[];

      await _pumpResponseSheet(
        tester,
        applied,
        initial: const MockApiFailure(
          statusCode: 401,
          errorCode: 'tokenExpired',
        ),
        hasErrorStatuses: true,
      );
      await tester.tap(find.text('401'));
      await tester.pump();
      await tester.tap(find.text(sampleStrings.apply));
      await tester.pump();

      expect(applied, [
        (
          const MockApiFailure(statusCode: 401, errorCode: 'tokenExpired'),
          null,
        ),
      ]);
    },
  );
}

void _automationResponseSheet_should_answer500ForACodeWithoutStatuses() {
  testWidgets(
    'AutomationResponseSheet should answer 500 for a code without statuses',
    (tester) async {
      final applied = <(MockApiFailure?, MockLatencyProfile?)>[];

      await _pumpResponseSheet(tester, applied, hasErrorStatuses: true);
      await tester.tap(find.text('invalidPhone'));
      await tester.pump();
      await tester.tap(find.text(sampleStrings.apply));
      await tester.pump();

      expect(applied, [
        (const MockApiFailure(errorCode: 'invalidPhone'), null),
      ]);
    },
  );
}

void _automationResponseSheet_should_openASavedErrorOutsideItsStatuses() {
  testWidgets(
    'AutomationResponseSheet should open a saved error outside its statuses',
    (tester) async {
      final applied = <(MockApiFailure?, MockLatencyProfile?)>[];
      const saved = MockApiFailure(errorCode: 'tokenExpired');

      await _pumpResponseSheet(
        tester,
        applied,
        initial: saved,
        hasErrorStatuses: true,
      );

      expect(find.text('500'), findsOne);
      expect(find.text('tokenExpired'), findsOne);

      await tester.tap(find.text(sampleStrings.apply));
      await tester.pump();

      expect(applied, [(saved, null)]);
    },
  );
}

Future<void> _pumpResponseSheet(
  WidgetTester tester,
  List<(MockApiFailure?, MockLatencyProfile?)> applied, {
  MockApiFailure? initial,
  MockLatencyProfile? initialLatency,
  bool hasErrorStatuses = false,
}) async {
  tester.view.physicalSize = const Size(800, 3200);

  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    hostApp(
      child: AutomationResponseSheet(
        method: 'GET',
        path: '/profile/me',
        mockDescription: 'the profile',
        initial: initial,
        initialLatency: initialLatency,
        backendErrorCodes: hasErrorStatuses
            ? const ['tokenExpired', 'invalidPhone']
            : const [],
        backendErrorStatusCodes: hasErrorStatuses
            ? const {
                'tokenExpired': {401},
              }
            : const {},
        onApply: (failure, latency) => applied.add((failure, latency)),
        onClose: () {},
      ),
    ),
  );
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
    await tester.enterText(
      find.descendant(
        of: find.byType(AutomationPresetsSheet),
        matching: find.byType(TextField),
      ),
      '..',
    );
    await tester.tap(find.text('Save current state'));
    await _settle(tester);

    expect(find.text('Use a name without a slash.'), findsOneWidget);
  });
}

void _automationAutorunPage_should_narrowTheFlowsBySearch() {
  testWidgets('AutomationAutorunPage should narrow the flows by search', (
    tester,
  ) async {
    await _pumpPage(tester, const AutomationAutorunPage());
    await tester.enterText(find.byType(TextField), 'item');
    await tester.pump();

    expect(find.text('Sign-in and sign-up'), findsNothing);
    expect(find.text('Create an item'), findsOneWidget);
    expect(
      tester
          .widget<AutomationPanelRadioTile>(
            find.widgetWithText(AutomationPanelRadioTile, 'Create an item'),
          )
          .isSelected,
      isTrue,
    );
  });
}

void _automationSectionsPage_should_narrowTheSectionsBySearch() {
  testWidgets('AutomationSectionsPage should narrow the sections by search', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      AutomationSectionsPage(
        sections: [
          AutomationSectionPanel.fromSection(authSection),
          AutomationSectionPanel.fromSection(itemsSection),
        ],
      ),
    );
    await tester.enterText(find.byType(TextField), 'ite');
    await tester.pump();

    expect(find.text('Auth'), findsNothing);
    expect(find.text('Items'), findsOneWidget);
  });
}

void _automationJournalPage_should_narrowTheRequestsBySearch() {
  testWidgets('AutomationJournalPage should narrow the requests by search', (
    tester,
  ) async {
    final sample = await _pumpPage(tester, const AutomationJournalPage());

    sample.mock.journal
      ..add(MockRequestRecordKind.request, {
        'method': 'GET',
        'path': '/profile/me',
        'status': 200,
      })
      ..add(MockRequestRecordKind.request, {
        'method': 'POST',
        'path': '/auth/otp',
        'status': 500,
      });

    await tester.pump();
    await tester.enterText(find.byType(TextField), '500');
    await tester.pump();

    expect(find.text('me'), findsNothing);
    expect(find.text('otp'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nothing');
    await tester.pump();

    expect(find.text(sampleStrings.noMatches), findsOneWidget);
  });
}

void _automationJournalPage_should_tellAnAnswerGivenByAnOverride() {
  testWidgets(
    'AutomationJournalPage should tell an answer given by an override',
    (tester) async {
      final sample = await _pumpPage(tester, const AutomationJournalPage());

      final record = sample.mock.journal.addRequest({
        'method': 'GET',
        'path': '/profile/me',
      });

      sample.mock.journal.attachResponse(
        record,
        statusCode: 500,
        body: const {},
        override: const {'failure': true, 'latency': 'slow'},
      );

      await tester.pump();

      expect(find.text('500'), findsOneWidget);
      expect(
        find.text(
          sampleStrings.answeredByOverride(
            'error · ${sampleStrings.latencyOverrideOf('Slow')}',
          ),
        ),
        findsOneWidget,
      );
    },
  );
}

void _automationJournalPage_should_clearTheJournal() {
  testWidgets('AutomationJournalPage should clear the journal', (tester) async {
    final sample = await _pumpPage(tester, const AutomationJournalPage());

    sample.mock.journal.add(MockRequestRecordKind.request, {
      'method': 'GET',
      'path': '/profile/me',
      'status': 200,
    });

    await tester.pump();
    await tester.tap(find.text(sampleStrings.clearLog));
    await tester.pumpAndSettle();
    await tester.tap(find.text(sampleStrings.clearLog).last);
    await tester.pumpAndSettle();

    expect(sample.mock.journal.records, isEmpty);
    expect(find.text(sampleStrings.noRequests), findsOneWidget);
  });
}

void _automationChangesPage_should_listAndRemoveTheChanges() {
  testWidgets('AutomationChangesPage should list and remove the changes', (
    tester,
  ) async {
    final sample = await _pumpPage(tester, const AutomationChangesPage());

    final controller = sample.controller;

    await tester.runAsync(() async {
      await controller.updateScenario(
        MockScenario([
          MockOverride.latency(MockLatencyProfile.slow),
          authSection.profile('slowCode'),
        ]),
      );
      await controller.setLatency('/auth/otp', MockLatencyProfile.fast);
    });
    await tester.pump();

    expect(find.text(sampleStrings.responseLatency), findsOneWidget);
    expect(find.text('Slow code'), findsOneWidget);
    expect(find.text('otp'), findsOneWidget);

    await tester.runAsync(() => controller.clearOverride('/auth/otp'));
    await tester.pump();

    expect(find.text('otp'), findsNothing);
    expect(find.text('Slow code'), findsOneWidget);
  });
}

void _automationChangesPage_should_resetAll() {
  testWidgets('AutomationChangesPage should reset all', (tester) async {
    final sample = await _pumpPage(tester, const AutomationChangesPage());

    await tester.runAsync(
      () => sample.controller.updateScenario(
        MockScenario([MockOverride.latency(MockLatencyProfile.slow)]),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(sampleStrings.resetAll));
    await tester.pumpAndSettle();

    expect(find.text('Reset 1 change?'), findsOneWidget);

    await tester.tap(find.text(sampleStrings.reset));
    await _settle(tester, until: () => !sample.controller.isChanged);

    expect(sample.controller.isChanged, isFalse);
  });
}

void _automationChangesPage_should_keepTheChangesOnCancel() {
  testWidgets('AutomationChangesPage should keep the changes on cancel', (
    tester,
  ) async {
    final sample = await _pumpPage(tester, const AutomationChangesPage());

    await tester.runAsync(
      () => sample.controller.updateScenario(
        MockScenario([MockOverride.latency(MockLatencyProfile.slow)]),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(sampleStrings.resetAll));
    await tester.pumpAndSettle();
    await tester.tap(find.text(sampleStrings.cancel));
    await tester.pumpAndSettle();

    expect(sample.controller.isChanged, isTrue);
    expect(find.text(sampleStrings.resetAll), findsOneWidget);
  });
}

void _automationSectionsPage_should_describeTheProfiles() {
  testWidgets('AutomationSectionsPage should describe the profiles', (
    tester,
  ) async {
    await _pumpSections(tester);

    expect(find.text('The sign-in screens and the session.'), findsOneWidget);

    await tester.tap(find.text('Profile').first);
    await tester.pumpAndSettle();

    expect(find.text('Signed in'), findsWidgets);
    expect(find.text('signedIn'), findsOneWidget);
    expect(find.text('The app starts with a signed-in user.'), findsOneWidget);
    expect(find.text(sampleStrings.restartsTheApp), findsNWidgets(2));
    expect(find.text(sampleStrings.defaultProfileDescription), findsOneWidget);
  });
}

void _automationSectionsPage_should_narrowTheProfilesBySearch() {
  testWidgets('AutomationSectionsPage should narrow the profiles by search', (
    tester,
  ) async {
    await _pumpPage(tester, AutomationSectionsPage(sections: [_manyProfiles]));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, sampleStrings.profileSearchHint),
      'seven',
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile seven'), findsOneWidget);
    expect(find.text('Profile one'), findsNothing);
    expect(find.text(sampleStrings.defaultProfileDescription), findsNothing);
  });
}

void _automationPanel_should_openTheChangesFromTheStatusRow() {
  testWidgets('AutomationPanel should open the changes from the status row', (
    tester,
  ) async {
    final sample = await _pumpPage(tester, const SizedBox());

    await tester.pumpWidget(
      hostApp(
        child: panelHost(
          sample,
          Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const AutomationPanel(),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(sampleStrings.defaultMock));
    await tester.pumpAndSettle();

    expect(find.text(sampleStrings.nothingChanged), findsOneWidget);
  });
}

void _matchesSearchQuery_should_ignoreCaseAndMatchAnEmptyQuery() {
  test('matchesSearchQuery should ignore case and match an empty query', () {
    const words = ['Sign-in', '/auth/otp'];

    expect(matchesSearchQuery('  ', words), isTrue);
    expect(matchesSearchQuery(' SIGN ', words), isTrue);
    expect(matchesSearchQuery('OTP', words), isTrue);
    expect(matchesSearchQuery('items', words), isFalse);
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
    final isRestartRequired = ValueNotifier(false);

    addTearDown(isRestartRequired.dispose);

    final controller = AutomationModeController(
      store: AutomationStateStore(directory.path),
      mode: AutomationMode.server,
      isRestartRequired: isRestartRequired,
    );

    addTearDown(() => directory.deleteSync(recursive: true));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      hostApp(child: AutomationMockModeTile(controller: controller)),
    );

    expect(find.byType(AutomationPanelSwitchTile), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text(sampleStrings.restartQuestion), findsOneWidget);
    expect(isRestartRequired.value, isFalse);

    await tester.tap(find.text(sampleStrings.apply));
    await _settle(tester, until: () => isRestartRequired.value);

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

const _profileWords = [
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
];

final _manyProfiles = AutomationSectionPanel.fromSection(
  MockSection<Map<String, Object?>>(
    name: 'many',
    title: const AutomationLocalizedText({'en': 'Many'}),
    fromJson: (json) => json,
    profiles: {
      for (final word in _profileWords)
        word: MockProfile(
          (settings) => {'word': word},
          title: AutomationLocalizedText({'en': 'Profile $word'}),
        ),
    },
  ),
);

void _automationSectionsPage_should_askBeforeAProfileThatRestarts() {
  testWidgets(
    'AutomationSectionsPage should ask before a profile that restarts',
    (tester) async {
      final sample = await _pumpSections(tester);

      await tester.tap(find.text('Profile').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign-up needed'));
      await tester.pumpAndSettle();

      expect(find.text(sampleStrings.restartQuestion), findsOneWidget);

      await tester.tap(find.text(sampleStrings.cancel));
      await tester.pumpAndSettle();

      expect(_authSettings(sample), isNull);
      expect(sample.isRestartRequired.value, isFalse);
      expect(find.text('Sign-up needed'), findsOneWidget);

      await tester.tap(find.text('Sign-up needed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sampleStrings.apply));
      await _settle(tester, until: () => sample.isRestartRequired.value);

      expect(_authSettings(sample), {'isSignedInOnLaunch': false});
      expect(sample.isRestartRequired.value, isTrue);
    },
  );
}

void _automationPresetsSheet_should_askBeforeAPresetThatRestarts() {
  testWidgets(
    'AutomationPresetsSheet should ask before a preset that restarts',
    (tester) async {
      final sample = await _pumpSections(tester);

      await tester.runAsync(
        () async => sample.mock.stateStore?.savePreset('Signed out', {
          'auth': {'isSignedInOnLaunch': false},
        }),
      );
      await tester.tap(find.text('Presets'));
      await _settle(tester);
      await tester.tap(find.text('Signed out'));
      await _settle(tester);

      expect(find.text('Apply "Signed out"?'), findsOneWidget);
      expect(find.text(sampleStrings.appRestarts), findsOneWidget);
      expect(_authSettings(sample), isNull);
    },
  );
}

void _automationChangesPage_should_askBeforeARemovalThatRestarts() {
  testWidgets(
    'AutomationChangesPage should ask before a removal that restarts',
    (tester) async {
      final sample = await tester.runAsync(() async {
        final first = await SamplePanel.create(
          scenario: MockScenario([authSection.profile('signedOut')]),
        );

        return SamplePanel.create(restartOf: first);
      });

      if (sample == null) {
        fail('runAsync returned no sample panel');
      }

      addTearDown(sample.dispose);

      await tester.pumpWidget(
        hostApp(child: panelHost(sample, const AutomationChangesPage())),
      );
      await tester.tap(find.byTooltip(sampleStrings.removeOverride));
      await tester.pumpAndSettle();

      expect(find.text(sampleStrings.restartQuestion), findsOneWidget);

      await tester.tap(find.text(sampleStrings.cancel));
      await tester.pumpAndSettle();

      expect(_authSettings(sample), {'isSignedInOnLaunch': false});
      expect(sample.isRestartRequired.value, isFalse);
    },
  );
}
