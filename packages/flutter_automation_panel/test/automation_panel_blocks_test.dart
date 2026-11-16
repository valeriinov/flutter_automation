import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
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
    _automationWalkPlaque_should_exitStepAndOpenFromItsLine();
    _automationWalkPlaque_should_pinExitAndNextUnderALongBody();
    _automationWalkPlaque_should_scrollItsBodyAndDragOnlyByTheHead();
    _automationRunDoneSheet_should_pinItsButtonsAndShare();
    _automationRunDoneSheet_should_hideShareWithoutACallback();
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
        child: _plaque(isExpanded: false, onDragged: (delta) => moved += delta),
      ),
    );

    final line = find.textContaining(_flowTitle, findRichText: true);
    final before = tester.getTopLeft(line);

    await tester.drag(line, const Offset(0, 120));
    await tester.pump();

    expect(moved, greaterThan(80));
    expect(tester.getTopLeft(line), before);
  });
}

void _automationWalkPlaque_should_exitStepAndOpenFromItsLine() {
  testWidgets('AutomationWalkPlaque should exit step and open from its line', (
    tester,
  ) async {
    int exits = 0;
    int nexts = 0;
    int toggles = 0;

    await _pump(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: _plaque(
          isExpanded: false,
          onExit: () => exits += 1,
          onNext: () => nexts += 1,
          onToggle: () => toggles += 1,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.close));
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.tap(find.textContaining(_flowTitle, findRichText: true));

    expect((exits, nexts, toggles), (1, 1, 1));
  });
}

void _automationWalkPlaque_should_pinExitAndNextUnderALongBody() {
  testWidgets(
    'AutomationWalkPlaque should pin exit and next under a long body',
    (tester) async {
      int nexts = 0;

      await _pump(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: _plaque(isExpanded: true, onNext: () => nexts += 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final next = find.widgetWithText(
        AutomationPanelButton,
        AutomationPanelStrings.nextStep,
      );
      final exit = find.widgetWithText(
        AutomationPanelButton,
        AutomationPanelStrings.exit,
      );

      expect(tester.getBottomLeft(next).dy, lessThanOrEqualTo(360));
      expect(exit.hitTestable(), findsOneWidget);
      expect(find.text('Branch 19').hitTestable(), findsNothing);

      await tester.tap(next);

      expect(nexts, 1);
    },
  );
}

void _automationWalkPlaque_should_scrollItsBodyAndDragOnlyByTheHead() {
  testWidgets(
    'AutomationWalkPlaque should scroll its body and drag only by the head',
    (tester) async {
      double moved = 0;

      await _pump(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: _plaque(
              isExpanded: true,
              onDragged: (delta) => moved += delta,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final first = find.text('Branch 0');
      final before = tester.getTopLeft(first);

      await tester.drag(first, const Offset(0, -120));
      await tester.pumpAndSettle();

      expect(moved, 0);
      expect(tester.getTopLeft(first).dy, lessThan(before.dy));

      await tester.drag(
        find.textContaining(_flowTitle, findRichText: true),
        const Offset(0, 120),
      );
      await tester.pump();

      expect(moved, greaterThan(80));
    },
  );
}

void _automationRunDoneSheet_should_pinItsButtonsAndShare() {
  testWidgets('AutomationRunDoneSheet should pin its buttons and share', (
    tester,
  ) async {
    int shares = 0;

    await _pumpRunDone(tester, onShare: () => shares += 1);

    final share = find.text(AutomationPanelStrings.shareLogs);

    expect(share.hitTestable(), findsOneWidget);
    expect(find.text(AutomationPanelStrings.runAgain).hitTestable(), findsOne);
    expect(find.text(AutomationPanelStrings.exit).hitTestable(), findsOne);
    expect(find.text('/request/29').hitTestable(), findsNothing);

    await tester.tap(share);

    expect(shares, 1);
  });
}

void _automationRunDoneSheet_should_hideShareWithoutACallback() {
  testWidgets('AutomationRunDoneSheet should hide share without a callback', (
    tester,
  ) async {
    await _pumpRunDone(tester);

    expect(find.text(AutomationPanelStrings.shareLogs), findsNothing);
    expect(find.text(AutomationPanelStrings.runAgain), findsOneWidget);
  });
}

const _flowTitle = 'Sign-in';

Widget _plaque({
  required bool isExpanded,
  VoidCallback? onExit,
  VoidCallback? onNext,
  VoidCallback? onToggle,
  ValueChanged<double>? onDragged,
}) {
  return AutomationWalkPlaque(
    flowTitle: _flowTitle,
    collapsedStep: AutomationPanelStrings.stepShort(1, 4),
    expandedStep: AutomationPanelStrings.stepOf(1, 4),
    overrideCount: 0,
    isExpanded: isExpanded,
    nextLabel: AutomationPanelStrings.nextStep,
    onToggle: onToggle ?? () {},
    onExit: onExit ?? () {},
    onNext: onNext ?? () {},
    onDragged: onDragged,
    child: Column(
      children: [
        for (int index = 0; index < 20; index += 1)
          SizedBox(height: 48, child: Text('Branch $index')),
      ],
    ),
  );
}

Future<void> _pumpRunDone(WidgetTester tester, {VoidCallback? onShare}) {
  return _pump(
    tester,
    Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: AutomationRunDoneSheet(
          outcome: 'Signed in',
          stepCount: 4,
          duration: const Duration(seconds: 12),
          requests: [
            for (int index = 0; index < 30; index += 1)
              AutomationCatalogueRequest(
                method: 'GET',
                path: '/request/$index',
                statusCode: 200,
              ),
          ],
          onShare: onShare,
          onRunAgain: () {},
          onExit: () {},
        ),
      ),
    ),
  );
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
