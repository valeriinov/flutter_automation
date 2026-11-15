import 'package:flutter_automation/automation_date_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

final _anchor = DateTime(2026, 2, 27);

void main() {
  group('AutomationDatePattern Tests', () {
    _automationDatePattern_should_writeTokensAndKeepTheRest();
    _automationDatePattern_should_writeTheDayTextAcrossAMonthEnd();
    _automationDatePattern_should_writeTheDayKeyFromATemplate();
  });
}

void _automationDatePattern_should_writeTokensAndKeepTheRest() {
  test('AutomationDatePattern should write tokens and keep the rest', () {
    expect(
      AutomationDatePattern.format(DateTime(2026, 3, 5), 'dd.MM.yyyy'),
      '05.03.2026',
    );
  });
}

void _automationDatePattern_should_writeTheDayTextAcrossAMonthEnd() {
  test('AutomationDatePattern should write the day text with a time', () {
    final text = AutomationDatePattern.writeDayText(
      _anchor,
      3,
      'dd.MM.yyyy',
      time: '10:30',
    );

    expect(text, '02.03.2026 10:30');
  });
}

void _automationDatePattern_should_writeTheDayKeyFromATemplate() {
  test('AutomationDatePattern should write the day key from a template', () {
    final key = AutomationDatePattern.writeDayKey(
      _anchor,
      2,
      'day.tile.{yyyyMMdd}',
    );

    expect(key, 'day.tile.20260301');
  });
}
