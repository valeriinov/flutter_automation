import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils/sample_panel.dart';

void main() {
  group('Automation Panel Block Widget Tests', () {
    _automationRequestRow_should_nameTheOverrideAndClearIt();
    _automationRequestRow_should_keepTheLastPathSegment();
    _automationPanelButtonGroup_should_shareARowOnlyForShortLabels();
    _automationWalkPlaque_should_hideOnASwipeUp();
  });
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(hostApp(child: child));
}

void _automationRequestRow_should_nameTheOverrideAndClearIt() {
  testWidgets('AutomationRequestRow should name the override and clear it', (
    tester,
  ) async {
    int cleared = 0;

    await _pump(
      tester,
      AutomationRequestRow(
        method: 'POST',
        path: signUpPath,
        failure: const MockApiFailure(errorCode: 'internalError'),
        onClearOverride: () => cleared += 1,
      ),
    );
    await tester.tap(find.byIcon(Icons.close));

    expect(find.text('Override: 500 internalError'), findsOneWidget);
    expect(cleared, 1);
  });
}

void _automationRequestRow_should_keepTheLastPathSegment() {
  testWidgets('AutomationRequestRow should keep the last path segment', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(260, 400);

    addTearDown(tester.view.reset);

    await _pump(
      tester,
      const AutomationRequestRow(
        method: 'POST',
        path: '/auth/send-code',
        statusCode: 200,
      ),
    );

    expect(find.text('send-code'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
  });
}

void _automationPanelButtonGroup_should_shareARowOnlyForShortLabels() {
  testWidgets(
    'AutomationPanelButtonGroup should share a row only for short labels',
    (tester) async {
      await _pump(
        tester,
        AutomationPanelButtonGroup(
          buttons: [
            AutomationPanelButton(label: 'Start over', onPressed: () {}),
            AutomationPanelButton(label: 'Finish', onPressed: () {}),
          ],
        ),
      );

      expect(_stacksVertically(tester), isFalse);

      await _pump(
        tester,
        AutomationPanelButtonGroup(
          buttons: [
            AutomationPanelButton(label: 'Use mock response', onPressed: () {}),
            AutomationPanelButton(label: 'Finish', onPressed: () {}),
          ],
        ),
      );

      expect(_stacksVertically(tester), isTrue);
    },
  );
}

bool _stacksVertically(WidgetTester tester) {
  final top = tester.getTopLeft(find.byType(AutomationPanelButton).first);
  final next = tester.getTopLeft(find.byType(AutomationPanelButton).last);

  return next.dy > top.dy;
}

void _automationWalkPlaque_should_hideOnASwipeUp() {
  testWidgets('AutomationWalkPlaque should hide on a swipe up', (tester) async {
    int hidden = 0;

    await _pump(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: AutomationWalkPlaque(
          title: 'Sign-in · step 1 of 4',
          overrideCount: 0,
          isExpanded: false,
          onToggle: () {},
          onHide: () => hidden += 1,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.fling(
      find.byType(AutomationWalkPlaque),
      const Offset(0, -80),
      800,
    );

    expect(hidden, 1);
  });
}
