import 'package:flutter/material.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

const _fastSettings = AutomationPlayerSettings(
  pollInterval: Duration(milliseconds: 50),
  settleDelay: Duration.zero,
  touchLead: Duration.zero,
  touchHold: Duration.zero,
  touchTrail: Duration.zero,
);
final _anchor = DateTime(2026, 3, 5);
const _dateFormats = {'uk': 'dd.MM.yyyy', 'en': 'MM/dd/yyyy'};
const _dateValueKeys = {'calendarDay': 'day.tile.{yyyyMMdd}'};

void main() {
  group('AutomationPlayerFinder Date Tests', () {
    _automationPlayerFinder_should_writeADateTextByTheLocaleFormat();
    _automationPlayerFinder_should_failWhenTheLocaleHasNoDateFormat();
    _automationPlayerFinder_should_failOnANonStringTime();
    _automationPlayerFinder_should_writeADeclaredDateKey();
    _automationFlowPlayer_should_readTheDatesOfTheCatalogue();
  });
}

Future<void> _pumpDays(WidgetTester tester, {VoidCallback? onTap}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Column(
        children: [
          const Text('07.03.2026 10:30'),
          const Text('03/07/2026'),
          TextButton(
            key: const ValueKey('day.tile.20260307'),
            onPressed: onTap,
            child: const Text('day'),
          ),
        ],
      ),
    ),
  );
}

AutomationPlayerFinder _finder(
  Map<String, Object?> json, {
  String? locale = 'uk',
  Map<String, String> dateFormats = _dateFormats,
}) {
  return AutomationPlayerFinder(
    json,
    AutomationPlayerSettings(readLocale: locale == null ? null : () => locale),
    anchor: _anchor,
    dateFormats: dateFormats,
    dateValueKeys: _dateValueKeys,
  );
}

void _automationPlayerFinder_should_writeADateTextByTheLocaleFormat() {
  testWidgets('AutomationPlayerFinder should write a dateText by the locale '
      'format', (tester) async {
    await _pumpDays(tester);

    final uk = _finder({'by': 'dateText', 'dayOffset': 2, 'time': '10:30'});
    final en = _finder({'by': 'dateText', 'dayOffset': 2}, locale: 'en');

    expect(uk.findAll(), hasLength(1));
    expect(en.findAll(), hasLength(1));
  });
}

void _automationPlayerFinder_should_failWhenTheLocaleHasNoDateFormat() {
  testWidgets('AutomationPlayerFinder should fail when the locale has no date '
      'format', (tester) async {
    await _pumpDays(tester);

    final finder = _finder({'by': 'dateText', 'dayOffset': 2}, locale: 'de');

    expect(finder.findAll, throwsA(isA<AutomationPlayerException>()));
  });
}

void _automationPlayerFinder_should_failOnANonStringTime() {
  testWidgets('AutomationPlayerFinder should fail on a non-string time', (
    tester,
  ) async {
    await _pumpDays(tester);

    final finder = _finder({'by': 'dateText', 'dayOffset': 2, 'time': 1030});

    expect(finder.findAll, throwsA(isA<AutomationPlayerException>()));
  });
}

void _automationPlayerFinder_should_writeADeclaredDateKey() {
  testWidgets('AutomationPlayerFinder should write a declared date key', (
    tester,
  ) async {
    await _pumpDays(tester);

    final finder = _finder({'by': 'calendarDay', 'dayOffset': 2});

    expect(finder.findAll(), hasLength(1));
  });
}

void _automationFlowPlayer_should_readTheDatesOfTheCatalogue() {
  testWidgets('AutomationFlowPlayer should read the dates of the catalogue', (
    tester,
  ) async {
    int taps = 0;
    final player = AutomationFlowPlayer(
      settings: _fastSettings,
      catalogue: const AutomationCatalogue(
        dateFormats: _dateFormats,
        dateValueKeys: _dateValueKeys,
      ),
    );
    final day = DateTime.now().add(const Duration(days: 2));
    final key = AutomationDatePattern.format(day, 'day.tile.yyyyMMdd');

    addTearDown(player.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TextButton(
          key: ValueKey(key),
          onPressed: () => taps += 1,
          child: const Text('day'),
        ),
      ),
    );

    final future = player.play(
      AutomationCatalogueStep(
        label: 'tap',
        action: 'tap',
        finder: const {'by': 'calendarDay', 'dayOffset': 2},
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await future;

    expect(taps, 1);
  });
}
