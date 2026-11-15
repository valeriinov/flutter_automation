import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils/sample_panel.dart';

const _screenHeight = 844.0;
const _statusBar = 47.0;
const _homeIndicator = 34.0;
const _bodyKey = Key('body');

void main() {
  group('Automation Panel Insets Widget Tests', () {
    _automationPanelFrame_should_keepTheHeaderBelowTheStatusBar();
    _automationPanelFrame_should_darkenTheStatusBarIconsOverTheApp();
    _automationPanelFrame_should_keepTheBodyAboveTheBottomArea();
    _automationPanelFrame_should_keepTheFooterAboveTheBottomArea();
    _automationPanelSheet_should_keepTheContentAboveTheBottomArea();
    _automationPanelLauncher_should_keepTheDraggedButtonBelowTheStatusBar();
  });
}

void _automationPanelFrame_should_keepTheHeaderBelowTheStatusBar() {
  testWidgets(
    'AutomationPanelFrame should keep the header below the status bar',
    (tester) async {
      await _pumpScreen(tester, _frame());

      expect(tester.getTopLeft(find.text('Flows')).dy, greaterThan(_statusBar));
    },
  );
}

void _automationPanelFrame_should_darkenTheStatusBarIconsOverTheApp() {
  testWidgets(
    'AutomationPanelFrame should darken the status bar icons over the app',
    (tester) async {
      await _pumpScreen(
        tester,
        AnnotatedRegion(
          value: SystemUiOverlayStyle.light,
          child: Stack(children: [const SizedBox.expand(), _frame()]),
        ),
      );

      final style = tester.layers.first.find<SystemUiOverlayStyle>(
        const Offset(195, _statusBar / 2),
      );

      expect(style?.statusBarIconBrightness, Brightness.dark);
    },
  );
}

void _automationPanelFrame_should_keepTheBodyAboveTheBottomArea() {
  testWidgets(
    'AutomationPanelFrame should keep the body above the bottom area',
    (tester) async {
      await _pumpScreen(tester, _frame());

      expect(
        tester.getBottomLeft(find.byKey(_bodyKey)).dy,
        lessThanOrEqualTo(_screenHeight - _homeIndicator),
      );
    },
  );
}

void _automationPanelFrame_should_keepTheFooterAboveTheBottomArea() {
  testWidgets(
    'AutomationPanelFrame should keep the footer above the bottom area',
    (tester) async {
      await _pumpScreen(tester, _frame(footer: const Text('Finish')));

      expect(
        tester.getBottomLeft(find.text('Finish')).dy,
        lessThanOrEqualTo(_screenHeight - _homeIndicator),
      );
    },
  );
}

void _automationPanelSheet_should_keepTheContentAboveTheBottomArea() {
  testWidgets(
    'AutomationPanelSheet should keep the content above the bottom area',
    (tester) async {
      await _pumpScreen(
        tester,
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showAutomationPanelSheet<void>(
                context: context,
                builder: (_) => const AutomationPanelSheet(
                  title: 'Response',
                  child: Text('Apply'),
                ),
              ),
              child: const Text('Open'),
            );
          },
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        tester.getBottomLeft(find.text('Apply')).dy,
        lessThanOrEqualTo(_screenHeight - _homeIndicator),
      );
    },
  );
}

void _automationPanelLauncher_should_keepTheDraggedButtonBelowTheStatusBar() {
  testWidgets(
    'AutomationPanelLauncher should keep the dragged button below the status '
    'bar',
    (tester) async {
      final sample = await tester.runAsync(SamplePanel.create);

      if (sample == null) {
        fail('The sample panel did not start.');
      }

      addTearDown(sample.dispose);

      await _pumpScreen(
        tester,
        AutomationPanelLauncher(
          controller: sample.controller,
          isVisible: true,
          child: const SizedBox.expand(),
        ),
      );
      await tester.drag(find.text('QA'), const Offset(0, -2000));
      await tester.pumpAndSettle();

      final button = find.ancestor(
        of: find.text('QA'),
        matching: find.byType(Container),
      );

      expect(
        tester.getTopLeft(button.first).dy,
        greaterThanOrEqualTo(_statusBar),
      );
    },
  );
}

Widget _frame({Widget? footer}) {
  return AutomationPanelFrame(
    title: 'Flows',
    onClose: () {},
    footer: footer,
    child: const SizedBox.expand(key: _bodyKey),
  );
}

Future<void> _pumpScreen(WidgetTester tester, Widget child) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, _screenHeight);
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _homeIndicator,
  );

  addTearDown(tester.view.reset);

  return tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Theme(
        data: sampleTheme.toThemeData(),
        child: Material(child: child),
      ),
    ),
  );
}
