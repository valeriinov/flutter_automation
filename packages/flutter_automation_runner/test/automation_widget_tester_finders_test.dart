import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/widget_tester_finders.dart';

const _title = 'Hello';

void main() {
  group('AutomationWidgetTesterFinders Tests', () {
    _automationWidgetTesterFinders_should_findRichTextByItsSpans();
    _automationWidgetTesterFinders_should_matchTextOnce();
  });
}

Finder _findText() {
  return AutomationWidgetTesterFinders.build(const AutomationTextSpec(_title));
}

void _automationWidgetTesterFinders_should_findRichTextByItsSpans() {
  testWidgets('AutomationWidgetTesterFinders should find rich text by its '
      'spans', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RichText(
          text: const TextSpan(
            children: [
              TextSpan(text: 'Hel'),
              TextSpan(text: 'lo'),
            ],
          ),
        ),
      ),
    );

    expect(_findText(), findsOneWidget);
  });
}

void _automationWidgetTesterFinders_should_matchTextOnce() {
  testWidgets('AutomationWidgetTesterFinders should match text once', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Text(_title),
      ),
    );

    expect(_findText(), findsOneWidget);
  });
}
