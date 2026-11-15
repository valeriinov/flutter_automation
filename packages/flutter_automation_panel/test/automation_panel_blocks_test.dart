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
    _automationPanelSheet_should_keepTheHeadWhileTheBodyScrolls();
    _automationPanelSheet_should_notMoveAShortSheet();
    _automationPanelSheet_should_holdAListTile();
    _automationWalkPlaque_should_reportADragDown();
    _automationWalkPlaque_should_exitFromItsHeader();
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

void _automationWalkPlaque_should_reportADragDown() {
  testWidgets('AutomationWalkPlaque should report a drag down', (tester) async {
    double moved = 0;

    await _pump(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: AutomationWalkPlaque(
          title: 'Sign-in · step 1 of 4',
          overrideCount: 0,
          isExpanded: false,
          onToggle: () {},
          onExit: () {},
          onDragged: (delta) => moved += delta,
          child: const SizedBox(),
        ),
      ),
    );

    final line = find.text('Sign-in · step 1 of 4');
    final before = tester.getTopLeft(line);

    await tester.drag(line, const Offset(0, 120));
    await tester.pump();

    expect(moved, greaterThan(80));
    expect(tester.getTopLeft(line), before);
  });
}

void _automationWalkPlaque_should_exitFromItsHeader() {
  testWidgets('AutomationWalkPlaque should exit from its header', (
    tester,
  ) async {
    int exits = 0;
    int toggles = 0;

    await _pump(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: AutomationWalkPlaque(
          title: 'Sign-in · step 1 of 4',
          overrideCount: 0,
          isExpanded: false,
          onToggle: () => toggles += 1,
          onExit: () => exits += 1,
          child: const SizedBox(),
        ),
      ),
    );

    expect(find.text('Exit'), findsOneWidget);

    await tester.tap(find.text('Exit'));

    expect(exits, 1);
    expect(toggles, 0);
  });
}

Future<void> _openSheet(WidgetTester tester, {required int rowCount}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return TextButton(
            onPressed: () => showAutomationPanelSheet<void>(
              context: context,
              builder: (_) => AutomationPanelSheet(
                title: 'Sheet title',
                child: Column(
                  children: [
                    for (int row = 0; row < rowCount; row += 1)
                      SizedBox(height: 50, child: Text('Row $row')),
                  ],
                ),
              ),
            ),
            child: const Text('Open'),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void _automationPanelSheet_should_keepTheHeadWhileTheBodyScrolls() {
  testWidgets(
    'AutomationPanelSheet should keep the head while the body scrolls',
    (tester) async {
      await _openSheet(tester, rowCount: 30);

      final title = tester.getTopLeft(find.text('Sheet title'));
      final row = tester.getTopLeft(find.text('Row 0'));

      await tester.drag(find.text('Row 1'), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('Sheet title')), title);
      expect(tester.getTopLeft(find.text('Row 0')).dy, lessThan(row.dy));
    },
  );
}

void _automationPanelSheet_should_notMoveAShortSheet() {
  testWidgets('AutomationPanelSheet should not move a short sheet', (
    tester,
  ) async {
    await _openSheet(tester, rowCount: 2);

    final title = tester.getTopLeft(find.text('Sheet title'));
    final row = tester.getTopLeft(find.text('Row 0'));

    await tester.drag(find.text('Row 0'), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Sheet title')), title);
    expect(tester.getTopLeft(find.text('Row 0')), row);
  });
}

void _automationPanelSheet_should_holdAListTile() {
  testWidgets('AutomationPanelSheet should hold a ListTile', (tester) async {
    await _pump(
      tester,
      AutomationPanelSheet(
        title: 'Sheet title',
        child: SwitchListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('Mock mode'),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Mock mode'), findsOneWidget);
  });
}
