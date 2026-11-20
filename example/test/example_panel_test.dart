import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/automation/screen_name_observer.dart';
import 'package:example/catalog/catalog_api.dart';
import 'package:example/example_app.dart';
import 'package:example/mock/catalog_mock_section.dart';
import 'package:example/panel/example_panel.dart';
import 'package:dio/dio.dart';

const _strings = AutomationPanelStrings();

void main() {
  group('Example Panel Widget Tests', () {
    _examplePanel_should_buildThePanelWithoutProjectCode();
    _exampleApp_should_showTheRestartScreenAfterAModeSwitch();
  });
}

void _examplePanel_should_buildThePanelWithoutProjectCode() {
  testWidgets('Example panel should build the panel without project code', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('example_panel');
    final isRestartRequired = ValueNotifier(false);

    addTearDown(isRestartRequired.dispose);
    addTearDown(() => directory.deleteSync(recursive: true));

    final mock = await tester.runAsync(
      () => AutomationMock.init(
        isEnabled: true,
        scenarioDirectory: directory.path,
        stateStore: AutomationStateStore(directory.path),
        sections: [catalogMockSection],
      ),
    );

    if (mock == null) {
      fail('runAsync returned no mock');
    }

    final controller = await tester.runAsync(
      () => buildExamplePanel(mock: mock, isRestartRequired: isRestartRequired),
    );

    if (controller == null) {
      fail('runAsync returned no panel controller');
    }

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ExampleApp(
        catalogApi: CatalogApi(Dio()),
        screenNameObserver: ScreenNameObserver(),
        locale: ValueNotifier(const Locale('en')),
        isRestartRequired: isRestartRequired,
        panelController: controller,
      ),
    );
    await tester.tap(find.text('QA'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in and read the catalog'), findsOneWidget);
    expect(find.text('CATALOG'), findsOneWidget);
  });
}

void _exampleApp_should_showTheRestartScreenAfterAModeSwitch() {
  testWidgets(
    'Example app should show the restart screen after a mode switch',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('example_mode');

      addTearDown(() => directory.deleteSync(recursive: true));

      final bootstrap = await tester.runAsync(
        () => AutomationModeBootstrap.restore(
          directory: directory.path,
          isSwitchable: true,
        ),
      );

      if (bootstrap == null) {
        fail('runAsync returned no bootstrap');
      }

      addTearDown(bootstrap.isRestartRequired.dispose);

      final modeController = bootstrap.createModeController();

      if (modeController == null) {
        fail('the bootstrap is switchable but gave no mode controller');
      }

      addTearDown(modeController.dispose);

      await tester.pumpWidget(
        ExampleApp(
          catalogApi: CatalogApi(Dio()),
          screenNameObserver: ScreenNameObserver(),
          locale: ValueNotifier(const Locale('en')),
          isRestartRequired: bootstrap.isRestartRequired,
          modeController: modeController,
        ),
      );
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_strings.apply));
      await _settle(tester, until: () => bootstrap.isRestartRequired.value);

      expect(find.text(_strings.restartScreenTitle), findsOneWidget);
    },
  );
}

Future<void> _settle(
  WidgetTester tester, {
  required bool Function() until,
}) async {
  for (int round = 0; round < 200; round += 1) {
    if (until()) {
      break;
    }

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }

  await tester.pump();
}
