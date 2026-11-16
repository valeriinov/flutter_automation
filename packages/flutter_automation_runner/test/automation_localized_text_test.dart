import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_localized_text.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

const _key = 'title';
const _subject = 'Block "order_remove_item"';

void main() {
  group('AutomationLocalizedTextJson Tests', () {
    _automationLocalizedTextJson_should_returnNullWhenAbsent();
    _automationLocalizedTextJson_should_readBothLanguages();
    _automationLocalizedTextJson_should_readAnySetOfLocales();
    _automationLocalizedTextJson_should_rejectLocaleWithoutText();
    _automationLocalizedTextJson_should_rejectMalformedTexts();
  });
}

void _automationLocalizedTextJson_should_returnNullWhenAbsent() {
  test('AutomationLocalizedTextJson should return null when absent', () {
    final text = AutomationLocalizedTextJson.tryRead(const {}, _key, _subject);

    expect(text, isNull);
  });
}

void _automationLocalizedTextJson_should_readBothLanguages() {
  test('AutomationLocalizedTextJson should read both languages', () {
    final text = AutomationLocalizedTextJson.tryRead(
      const {
        _key: {'en': 'Remove the item', 'uk': 'Видалити товар'},
      },
      _key,
      _subject,
    );

    expect(text?.read('en'), 'Remove the item');
    expect(text?.read('uk'), 'Видалити товар');
  });
}

void _automationLocalizedTextJson_should_readAnySetOfLocales() {
  test('AutomationLocalizedTextJson should read any set of locales', () {
    final text = AutomationLocalizedTextJson.tryRead(
      const {
        _key: {'de': 'Angebot ablehnen'},
      },
      _key,
      _subject,
    );

    expect(text?.read('de'), 'Angebot ablehnen');
  });
}

void _automationLocalizedTextJson_should_rejectLocaleWithoutText() {
  test('AutomationLocalizedTextJson should reject locale without text', () {
    const text = AutomationLocalizedText({'en': 'Remove the item'});

    expect(() => text.read('uk'), throwsA(isA<AutomationRunnerException>()));
  });
}

void _automationLocalizedTextJson_should_rejectMalformedTexts() {
  test('AutomationLocalizedTextJson should reject malformed texts', () {
    const malformedTexts = [
      'Remove the item',
      <String, Object?>{},
      {'en': '', 'uk': 'Видалити товар'},
      {'en': 'Remove the item', 'uk': ' '},
      {'en': 'Remove the item', 'uk': true},
    ];

    for (final malformed in malformedTexts) {
      expect(
        () => AutomationLocalizedTextJson.tryRead(
          {_key: malformed},
          _key,
          _subject,
        ),
        throwsA(
          isA<AutomationRunnerException>().having(
            (error) => error.message,
            'message',
            startsWith('$_subject has a malformed "$_key"'),
          ),
        ),
      );
    }
  });
}
