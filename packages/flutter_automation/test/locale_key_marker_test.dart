import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_test/flutter_test.dart';

const _titleKey = 'greetingTitle';
const _title = 'Hello';
const _sentKey = 'sentCount';
const _phone = '+380501234567';

void main() {
  group('LocaleKeyMarker Tests', () {
    _localeKeyMarker_should_readKeyBackFromMarkedValue();
    _localeKeyMarker_should_stripMarkToValue();
    _localeKeyMarker_should_readEveryMarkInOrder();
    _localeKeyMarker_should_returnNoKeysForUnmarkedText();
  });
}

void _localeKeyMarker_should_readKeyBackFromMarkedValue() {
  test('LocaleKeyMarker should read key back from marked value', () {
    final marked = LocaleKeyMarker.mark(_titleKey, _title);
    final keys = LocaleKeyMarker.readKeys(marked);

    expect(keys, [_titleKey]);
  });
}

void _localeKeyMarker_should_stripMarkToValue() {
  test('LocaleKeyMarker should strip mark to value', () {
    final marked = LocaleKeyMarker.mark(_titleKey, _title);
    final stripped = LocaleKeyMarker.strip(marked);

    expect(marked, isNot(_title));
    expect(stripped, _title);
  });
}

void _localeKeyMarker_should_readEveryMarkInOrder() {
  test('LocaleKeyMarker should read every mark in order', () {
    final text =
        '${LocaleKeyMarker.mark(_titleKey, _title)} · '
        '${LocaleKeyMarker.mark(_sentKey, _phone)}';
    final keys = LocaleKeyMarker.readKeys(text);

    expect(keys, [_titleKey, _sentKey]);
    expect(LocaleKeyMarker.strip(text), '$_title · $_phone');
  });
}

void _localeKeyMarker_should_returnNoKeysForUnmarkedText() {
  test('LocaleKeyMarker should return no keys for unmarked text', () {
    final keys = LocaleKeyMarker.readKeys(_title);

    expect(keys, isEmpty);
    expect(LocaleKeyMarker.strip(_title), _title);
  });
}
