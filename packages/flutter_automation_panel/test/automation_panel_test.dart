import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
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
    _automationWalkStrip_should_offerTheNextResponse();
    _automationModeController_should_saveTheModeAndAskForARestart();
    _automationFlowMapPage_should_notStartWhenTheOutcomeNeedsARestart();
    _automationSectionsPage_should_replaceTheProfileOfASection();
    _automationSectionsPage_should_offerTheDefaultProfile();
    _automationSectionsPage_should_nameAnUnknownSettingCustom();
    _automationPanelLauncher_should_sendTheBackButtonToThePanel();
    _automationPresetsSheet_should_rejectABadName();
  });
}

Future<SamplePanel> _pumpPage(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(780, 1688);

  addTearDown(tester.view.reset);

  final sample = await createSamplePanel(tester);

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

      await tester.tap(find.text('sign-up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('429'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(sample.mock.failures[signUpPath]?.statusCode, 429);
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
        () => sample.controller.setFailure(signUpPath, const MockApiFailure()),
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

void _automationWalkStrip_should_offerTheNextResponse() {
  testWidgets('AutomationWalkStrip should offer the next response', (
    tester,
  ) async {
    final sample = await _pumpPage(tester, const SizedBox());

    await tester.runAsync(() async {
      await sample.controller.startWalk('login', 'signUpNeeded');
      await sample.controller.moveWalk(2);
    });

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

    expect(find.textContaining('step 3 of 4'), findsOneWidget);
    expect(find.text('Mock response'), findsOneWidget);
    expect(find.text('No network'), findsOneWidget);
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

void _automationFlowMapPage_should_notStartWhenTheOutcomeNeedsARestart() {
  testWidgets(
    'AutomationFlowMapPage should not start when the outcome needs a restart',
    (tester) async {
      final sample = await _pumpPage(
        tester,
        AutomationFlowMapPage(flow: sampleCatalogue.flows.first),
      );

      sample.controller.openPanel();

      await tester.tap(find.text('Apply and start'));
      await _settle(tester, until: () => sample.events.isNotEmpty);

      expect(sample.mock.walk?.flow, 'login');
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
