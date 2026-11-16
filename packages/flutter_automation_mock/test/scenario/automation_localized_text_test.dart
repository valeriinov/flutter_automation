import 'package:flutter_automation_mock/mock_section.dart';
import 'package:flutter_test/flutter_test.dart';

const _text = AutomationLocalizedText({
  'uk': 'Видалити товар',
  'en': 'Remove the item',
  'pl': 'Usuń towar',
});

void main() {
  group('AutomationLocalizedText Tests', () {
    _automationLocalizedText_should_resolveTheRequestedLanguage();
    _automationLocalizedText_should_fallBackToEnglish();
    _automationLocalizedText_should_fallBackToTheFirstText();
    _automationLocalizedText_should_resolveAnEmptyStringWhenNoTextIsWritten();
    _automationLocalizedText_should_writeSortedJson();
  });
}

void _automationLocalizedText_should_resolveTheRequestedLanguage() {
  test('AutomationLocalizedText should resolve the requested language', () {
    expect(_text.resolve('uk'), 'Видалити товар');
  });
}

void _automationLocalizedText_should_fallBackToEnglish() {
  test('AutomationLocalizedText should fall back to English', () {
    expect(_text.resolve('de'), 'Remove the item');
  });
}

void _automationLocalizedText_should_fallBackToTheFirstText() {
  test('AutomationLocalizedText should fall back to the first text', () {
    const text = AutomationLocalizedText({'uk': 'Видалити', 'pl': 'Usuń'});

    expect(text.resolve('de'), 'Видалити');
  });
}

void _automationLocalizedText_should_resolveAnEmptyStringWhenNoTextIsWritten() {
  test('AutomationLocalizedText should resolve an empty string when no text is '
      'written', () {
    const text = AutomationLocalizedText({});

    expect(text.resolve('de'), '');
  });
}

void _automationLocalizedText_should_writeSortedJson() {
  test('AutomationLocalizedText should write sorted JSON', () {
    expect(_text.toJson().keys, ['en', 'pl', 'uk']);
    expect(_text.locales, ['uk', 'en', 'pl']);
  });
}
