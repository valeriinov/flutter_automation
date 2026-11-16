import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils/sample_panel.dart';

const _launchKeyScenario = {
  'auth': {'isSignedInOnLaunch': false},
};

void main() {
  group('Automation Restart Overlay Widget Tests', () {
    _automationRestartOverlay_should_showTheScreenOnlyWhileTheFlagIsTrue();
    _automationRestartOverlay_should_showTheScreenAtTheStartOfAWalk();
    _automationRestartOverlay_should_showTheScreenOnAChangeOfARestartKey();
    _automationRestartOverlay_should_showTheScreenOnASwitchOfTheMode();
  });
}

Widget _overlay(ValueNotifier<bool> isRestartRequired) {
  return MaterialApp(
    home: AutomationRestartOverlay(
      isRestartRequired: isRestartRequired,
      theme: sampleTheme,
      child: const Scaffold(body: Text('App content')),
    ),
  );
}

void _automationRestartOverlay_should_showTheScreenOnlyWhileTheFlagIsTrue() {
  testWidgets('AutomationRestartOverlay should show the screen only while the '
      'flag is true', (tester) async {
    final isRestartRequired = ValueNotifier(false);

    addTearDown(isRestartRequired.dispose);

    await tester.pumpWidget(_overlay(isRestartRequired));

    expect(find.text(sampleStrings.restartScreenTitle), findsNothing);
    expect(find.text('App content'), findsOneWidget);

    isRestartRequired.value = true;

    await tester.pump();

    expect(find.text(sampleStrings.restartScreenTitle), findsOneWidget);
  });
}

void _automationRestartOverlay_should_showTheScreenAtTheStartOfAWalk() {
  testWidgets('AutomationRestartOverlay should show the screen at the start '
      'of a walk', (tester) async {
    final sample = await createSamplePanel(tester);

    await tester.pumpWidget(_overlay(sample.isRestartRequired));
    await tester.runAsync(
      () => sample.controller.startWalk('login', 'signUpNeeded'),
    );
    await tester.pump();

    expect(find.text(sampleStrings.restartScreenTitle), findsOneWidget);
  });
}

void _automationRestartOverlay_should_showTheScreenOnAChangeOfARestartKey() {
  testWidgets('AutomationRestartOverlay should show the screen on a change of '
      'a restart key', (tester) async {
    final sample = await createSamplePanel(tester);

    await tester.pumpWidget(_overlay(sample.isRestartRequired));
    await tester.runAsync(
      () => sample.controller.applyOutcome(_launchKeyScenario),
    );
    await tester.pump();

    expect(find.text(sampleStrings.restartScreenTitle), findsOneWidget);
  });
}

void _automationRestartOverlay_should_showTheScreenOnASwitchOfTheMode() {
  testWidgets('AutomationRestartOverlay should show the screen on a switch of '
      'the mode with no panel controller', (tester) async {
    final directory = Directory.systemTemp.createTempSync('restart_overlay');

    addTearDown(() => directory.deleteSync(recursive: true));

    final isRestartRequired = ValueNotifier(false);
    final modeController = AutomationModeController(
      store: AutomationStateStore(directory.path),
      mode: AutomationMode.server,
      isRestartRequired: isRestartRequired,
    );

    addTearDown(isRestartRequired.dispose);
    addTearDown(modeController.dispose);

    await tester.pumpWidget(_overlay(isRestartRequired));
    await tester.runAsync(() => modeController.switchTo(AutomationMode.mock));
    await tester.pump();

    expect(find.text(sampleStrings.restartScreenTitle), findsOneWidget);
  });
}
