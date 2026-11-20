import 'package:flutter/material.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_test/flutter_test.dart';

const _title = 'Hello';
const _inlineValue = '42';

void main() {
  group('AutomationTextReader Tests', () {
    _automationTextReader_should_readTextOnce();
    _automationTextReader_should_readRichTextThatNoTextBuilds();
    _automationTextReader_should_readRichTextOfAWidgetSpan();
    _automationTextReader_should_readTextOfAWidgetSpanOnce();
    _automationTextReader_should_readSelectableTextOnce();
    _automationTextReader_should_readTextWithSemanticsLabelOnce();
  });
}

void _automationTextReader_should_readTextOnce() {
  testWidgets('AutomationTextReader should read text once', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Text(_title),
      ),
    );

    expect(_readTexts(tester), [_title]);
  });
}

void _automationTextReader_should_readRichTextThatNoTextBuilds() {
  testWidgets('AutomationTextReader should read rich text that no text '
      'builds', (tester) async {
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

    expect(_readTexts(tester), [_title]);
  });
}

void _automationTextReader_should_readRichTextOfAWidgetSpan() {
  testWidgets('AutomationTextReader should read rich text of a widget span', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Total '),
              WidgetSpan(
                child: RichText(text: const TextSpan(text: _inlineValue)),
              ),
            ],
          ),
        ),
      ),
    );

    expect(_readTexts(tester), ['Total \u{FFFC}', _inlineValue]);
  });
}

void _automationTextReader_should_readTextOfAWidgetSpanOnce() {
  testWidgets('AutomationTextReader should read text of a widget span once', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Total '),
              WidgetSpan(child: Text(_inlineValue)),
            ],
          ),
        ),
      ),
    );

    expect(_readTexts(tester), ['Total \u{FFFC}', _inlineValue]);
  });
}

void _automationTextReader_should_readSelectableTextOnce() {
  testWidgets('AutomationTextReader should read selectable text once', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SelectionArea(child: Text(_title))),
    );

    expect(_countTitles(tester), 1);
  });
}

void _automationTextReader_should_readTextWithSemanticsLabelOnce() {
  testWidgets('AutomationTextReader should read text with semantics label '
      'once', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Text(_title, semanticsLabel: 'greeting'),
      ),
    );

    expect(_countTitles(tester), 1);
  });
}

List<String> _readTexts(WidgetTester tester) {
  return tester.allElements.map(AutomationTextReader.tryRead).nonNulls.toList();
}

int _countTitles(WidgetTester tester) {
  return _readTexts(tester).where((text) => text == _title).length;
}
