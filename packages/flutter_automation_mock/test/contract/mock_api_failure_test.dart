import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = 'rateLimited';
const _errorCode = 'tooManyRequests';
const _defaultLanguageCode = 'en';
const _texts = {
  _key: AutomationLocalizedText({
    'en': 'Too many requests',
    'uk': 'Забагато запитів',
  }),
};

void main() {
  group('MockApiFailure Tests', () {
    _mockApiFailure_should_takeTheMessageFirst();
    _mockApiFailure_should_takeTheTextOfTheKeyInTheRequestLanguage();
    _mockApiFailure_should_takeTheTextOfTheKeyInTheDefaultLanguage();
    _mockApiFailure_should_takeTheDefaultLanguageForARequestWithoutOne();
    _mockApiFailure_should_takeTheErrorCodeForAnUnknownKey();
    _mockApiFailure_should_takeTheKeyForAnUnknownKeyWithoutAnErrorCode();
    _mockApiFailure_should_answerNullWithoutAMessageAndAKey();
  });
}

void _mockApiFailure_should_takeTheMessageFirst() {
  test('MockApiFailure should take the message first', () {
    const sut = MockApiFailure(message: 'Wait', messageKey: _key);

    expect(_resolve(sut, acceptLanguage: 'uk'), 'Wait');
  });
}

void _mockApiFailure_should_takeTheTextOfTheKeyInTheRequestLanguage() {
  test('MockApiFailure should take the text of the key in the request '
      'language', () {
    const sut = MockApiFailure(errorCode: _errorCode, messageKey: _key);

    expect(_resolve(sut, acceptLanguage: 'uk-UA,uk;q=0.9'), 'Забагато запитів');
  });
}

void _mockApiFailure_should_takeTheTextOfTheKeyInTheDefaultLanguage() {
  test('MockApiFailure should take the text of the key in the default '
      'language', () {
    const sut = MockApiFailure(errorCode: _errorCode, messageKey: _key);

    expect(_resolve(sut, acceptLanguage: 'de'), 'Too many requests');
  });
}

void _mockApiFailure_should_takeTheDefaultLanguageForARequestWithoutOne() {
  test('MockApiFailure should take the default language for a request '
      'without one', () {
    const sut = MockApiFailure(messageKey: _key);

    expect(_resolve(sut, acceptLanguage: null), 'Too many requests');
  });
}

void _mockApiFailure_should_takeTheErrorCodeForAnUnknownKey() {
  test('MockApiFailure should take the error code for an unknown key', () {
    const sut = MockApiFailure(errorCode: _errorCode, messageKey: 'unknown');

    expect(_resolve(sut, acceptLanguage: 'uk'), _errorCode);
  });
}

void _mockApiFailure_should_takeTheKeyForAnUnknownKeyWithoutAnErrorCode() {
  test('MockApiFailure should take the key for an unknown key without an '
      'error code', () {
    const sut = MockApiFailure(messageKey: 'unknown');

    expect(_resolve(sut, acceptLanguage: 'uk'), 'unknown');
  });
}

void _mockApiFailure_should_answerNullWithoutAMessageAndAKey() {
  test('MockApiFailure should answer null without a message and a key', () {
    const sut = MockApiFailure(errorCode: _errorCode);

    expect(_resolve(sut, acceptLanguage: 'uk'), isNull);
  });
}

String? _resolve(MockApiFailure failure, {required String? acceptLanguage}) {
  return failure.resolveMessage(
    MockApiRequest(
      path: '/items',
      body: const {},
      acceptLanguage: acceptLanguage,
    ),
    readText: (key, languageCode) => _texts[key]?.texts[languageCode],
    defaultLanguageCode: _defaultLanguageCode,
  );
}
