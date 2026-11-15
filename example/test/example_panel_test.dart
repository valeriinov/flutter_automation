import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/automation/screen_name_observer.dart';
import 'package:example/catalog/catalog_api.dart';
import 'package:example/example_app.dart';
import 'package:example/mock/catalog_mock_section.dart';
import 'package:example/panel/example_panel.dart';
import 'package:dio/dio.dart';

void main() {
  group('Example Panel Widget Tests', () {
    _examplePanel_should_buildThePanelWithoutProjectCode();
  });
}

void _examplePanel_should_buildThePanelWithoutProjectCode() {
  testWidgets('Example panel should build the panel without project code', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('example_panel');

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
      () => buildExamplePanel(mock: mock, onRestartRequired: () {}),
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
        panelController: controller,
      ),
    );
    await tester.tap(find.text('QA'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in and read the catalog'), findsOneWidget);
    expect(find.text('CATALOG'), findsOneWidget);
  });
}
