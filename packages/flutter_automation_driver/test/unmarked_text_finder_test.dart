import 'package:flutter/material.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_driver/driver_extension.dart';
import 'package:flutter_automation_driver/flutter_automation_driver.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_driver/flutter_driver.dart' show SerializableFinder;
import 'package:flutter_test/flutter_test.dart';

const _key = 'greetingTitle';
const _title = 'Hello';
const _hiddenTitle = 'Goodbye';
const _tooltip = 'Back';
const _tooltipKey = 'backLabel';

final _factory = _DriverFinderFactory();
final _textFinder = UnmarkedTextFinder.text();
final _tooltipFinder = UnmarkedTextFinder.tooltip();
final _localeKeyFinder = LocaleKeyFinder.text();
final _localeKeyTooltipFinder = LocaleKeyFinder.tooltip();

void main() {
  group('UnmarkedTextFinder Tests', () {
    _unmarkedTextFinder_should_answerRunnerFinderTypes();
  });
  group('UnmarkedTextFinder Widget Tests', () {
    _unmarkedTextFinder_should_findMarkedTextByItsValue();
    _unmarkedTextFinder_should_findMarkedEditableTextByItsValue();
    _unmarkedTextFinder_should_skipOffstageText();
    _unmarkedTextFinder_should_findRichTextByItsSpans();
    _unmarkedTextFinder_should_matchTextOnce();
    _unmarkedTextFinder_should_findRichTextOfAWidgetSpan();
    _unmarkedTextFinder_should_findMarkedTooltipByItsMessage();
  });
  group('LocaleKeyFinder Tests', () {
    _localeKeyFinder_should_answerRunnerFinderTypes();
  });
  group('LocaleKeyFinder Widget Tests', () {
    _localeKeyFinder_should_findMarkedTextByItsKey();
    _localeKeyFinder_should_findMarkedEditableTextByItsKey();
    _localeKeyFinder_should_skipTextMarkedWithOtherKey();
    _localeKeyFinder_should_skipOffstageText();
    _localeKeyFinder_should_findMarkedTooltipByItsKey();
  });
}

void _unmarkedTextFinder_should_answerRunnerFinderTypes() {
  test('UnmarkedTextFinder should answer runner finder types', () {
    expect(_textFinder.finderType, const UnmarkedText(_title).finderType);
    expect(
      _tooltipFinder.finderType,
      const UnmarkedTooltip(_tooltip).finderType,
    );
  });
}

void _unmarkedTextFinder_should_findMarkedTextByItsValue() {
  testWidgets('UnmarkedTextFinder should find marked text by its value', (
    tester,
  ) async {
    await _pump(tester, Text(LocaleKeyMarker.mark(_key, _title)));

    final finder = _resolve(_textFinder, const UnmarkedText(_title));

    expect(finder, findsOneWidget);
    expect(find.text(_title), findsNothing);
  });
}

void _unmarkedTextFinder_should_findRichTextByItsSpans() {
  testWidgets('UnmarkedTextFinder should find rich text by its spans', (
    tester,
  ) async {
    await _pump(
      tester,
      RichText(
        text: const TextSpan(
          children: [
            TextSpan(text: 'Hel'),
            TextSpan(text: 'lo'),
          ],
        ),
      ),
    );

    final finder = _resolve(_textFinder, const UnmarkedText(_title));

    expect(finder, findsOneWidget);
  });
}

void _unmarkedTextFinder_should_matchTextOnce() {
  testWidgets('UnmarkedTextFinder should match text once', (tester) async {
    await _pump(tester, const Text(_title));

    final finder = _resolve(_textFinder, const UnmarkedText(_title));

    expect(finder, findsOneWidget);
  });
}

void _unmarkedTextFinder_should_findRichTextOfAWidgetSpan() {
  testWidgets('UnmarkedTextFinder should find rich text of a widget span', (
    tester,
  ) async {
    await _pump(
      tester,
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Total '),
            WidgetSpan(
              child: RichText(text: const TextSpan(text: '42')),
            ),
          ],
        ),
      ),
    );

    final finder = _resolve(_textFinder, const UnmarkedText('42'));

    expect(finder, findsOneWidget);
  });
}

void _unmarkedTextFinder_should_findMarkedEditableTextByItsValue() {
  testWidgets(
    'UnmarkedTextFinder should find marked editable text by its value',
    (tester) async {
      final controller = TextEditingController(
        text: LocaleKeyMarker.mark(_key, _title),
      );

      await _pump(tester, TextField(controller: controller));

      final finder = _resolve(_textFinder, const UnmarkedText(_title));

      expect(finder, findsOneWidget);
      controller.dispose();
    },
  );
}

void _unmarkedTextFinder_should_skipOffstageText() {
  testWidgets('UnmarkedTextFinder should skip offstage text', (tester) async {
    await _pump(
      tester,
      Offstage(child: Text(LocaleKeyMarker.mark(_key, _hiddenTitle))),
    );

    final finder = _resolve(_textFinder, const UnmarkedText(_hiddenTitle));

    expect(finder, findsNothing);
  });
}

void _unmarkedTextFinder_should_findMarkedTooltipByItsMessage() {
  testWidgets('UnmarkedTextFinder should find marked tooltip by its message', (
    tester,
  ) async {
    await _pump(
      tester,
      Tooltip(
        message: LocaleKeyMarker.mark(_key, _tooltip),
        child: const SizedBox.square(dimension: 24),
      ),
    );

    final finder = _resolve(_tooltipFinder, const UnmarkedTooltip(_tooltip));

    expect(finder, findsOneWidget);
  });
}

void _localeKeyFinder_should_answerRunnerFinderTypes() {
  test('LocaleKeyFinder should answer runner finder types', () {
    expect(_localeKeyFinder.finderType, const LocaleKeyText(_key).finderType);
    expect(
      _localeKeyTooltipFinder.finderType,
      const LocaleKeyTooltip(_tooltipKey).finderType,
    );
  });
}

void _localeKeyFinder_should_findMarkedTextByItsKey() {
  testWidgets('LocaleKeyFinder should find marked text by its key', (
    tester,
  ) async {
    await _pump(tester, Text(LocaleKeyMarker.mark(_key, _title)));

    final finder = _resolve(_localeKeyFinder, const LocaleKeyText(_key));

    expect(finder, findsOneWidget);
  });
}

void _localeKeyFinder_should_findMarkedEditableTextByItsKey() {
  testWidgets('LocaleKeyFinder should find marked editable text by its key', (
    tester,
  ) async {
    final controller = TextEditingController(
      text: LocaleKeyMarker.mark(_key, _title),
    );

    await _pump(tester, TextField(controller: controller));

    final finder = _resolve(_localeKeyFinder, const LocaleKeyText(_key));

    expect(finder, findsOneWidget);
    controller.dispose();
  });
}

void _localeKeyFinder_should_skipTextMarkedWithOtherKey() {
  testWidgets('LocaleKeyFinder should skip text marked with other key', (
    tester,
  ) async {
    await _pump(tester, Text(LocaleKeyMarker.mark(_tooltipKey, _title)));

    final finder = _resolve(_localeKeyFinder, const LocaleKeyText(_key));

    expect(finder, findsNothing);
  });
}

void _localeKeyFinder_should_skipOffstageText() {
  testWidgets('LocaleKeyFinder should skip offstage text', (tester) async {
    await _pump(
      tester,
      Offstage(child: Text(LocaleKeyMarker.mark(_key, _hiddenTitle))),
    );

    final finder = _resolve(_localeKeyFinder, const LocaleKeyText(_key));

    expect(finder, findsNothing);
  });
}

void _localeKeyFinder_should_findMarkedTooltipByItsKey() {
  testWidgets('LocaleKeyFinder should find marked tooltip by its key', (
    tester,
  ) async {
    await _pump(
      tester,
      Tooltip(
        message: LocaleKeyMarker.mark(_tooltipKey, _tooltip),
        child: const SizedBox.square(dimension: 24),
      ),
    );

    final finder = _resolve(
      _localeKeyTooltipFinder,
      const LocaleKeyTooltip(_tooltipKey),
    );

    expect(finder, findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

Finder _resolve(FinderExtension extension, SerializableFinder query) {
  final params = query.serialize();
  final finder = extension.deserialize(params, _factory);

  return extension.createFinder(finder, _factory);
}

class _DriverFinderFactory with DeserializeFinderFactory, CreateFinderFactory {}
