import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockApiRequest Tests', () {
    _mockApiRequest_should_readTheLanguageCodeOfTheFirstRange();
    _mockApiRequest_should_readTheLanguageCodeInLowerCase();
    _mockApiRequest_should_readNoLanguageCodeWithoutALanguage();
    _mockApiRequest_should_readNoLanguageCodeForAnyLanguage();
  });
}

void _mockApiRequest_should_readTheLanguageCodeOfTheFirstRange() {
  test('MockApiRequest should read the language code of the first range', () {
    expect(_requestIn('uk-UA,uk;q=0.9,en;q=0.8').languageCode, 'uk');
  });
}

void _mockApiRequest_should_readTheLanguageCodeInLowerCase() {
  test('MockApiRequest should read the language code in lower case', () {
    expect(_requestIn('EN-GB').languageCode, 'en');
  });
}

void _mockApiRequest_should_readNoLanguageCodeWithoutALanguage() {
  test('MockApiRequest should read no language code without a language', () {
    expect(_requestIn(null).languageCode, isNull);
    expect(_requestIn('').languageCode, isNull);
  });
}

void _mockApiRequest_should_readNoLanguageCodeForAnyLanguage() {
  test('MockApiRequest should read no language code for any language', () {
    expect(_requestIn('*').languageCode, isNull);
  });
}

MockApiRequest _requestIn(String? acceptLanguage) {
  return MockApiRequest(
    path: '/items',
    body: const {},
    acceptLanguage: acceptLanguage,
  );
}
