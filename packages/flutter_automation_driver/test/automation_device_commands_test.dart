import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_automation_driver/driver_extension.dart';
import 'package:flutter_test/flutter_test.dart';

const _screen = {'name': 'home'};
const _logicalWidth = 400.0;
const _logicalHeight = 800.0;
const _pixelRatio = 2.0;
const _keyboardInset = 600.0;
const _frameText = 'Frame text';

void main() {
  _setup();
  group('AutomationDeviceCommands Widget Tests', () {
    _automationDeviceCommands_should_skipLocaleApplyWithoutApplier();
    _automationDeviceCommands_should_answerKeyboardInset();
    _automationDeviceCommands_should_answerScreenViewKeyboardAndPlatform();
    _automationDeviceCommands_should_answerNoScreenWhenReaderReturnsNull();
    _automationDeviceCommands_should_callScreenReaderAtCommandTime();
    _automationDeviceCommands_should_readNoFrameWithoutFlags();
    _automationDeviceCommands_should_readTheTextsOfTheFrameOnRequest();
    _automationDeviceCommands_should_readTheWidgetsOfTheFrameOnRequest();
    _automationDeviceCommands_should_applyTheLocaleWithTheApplier();
    _automationDeviceCommands_should_rejectALocaleWithoutLanguageCode();
  });
}

void _setup() {
  setUp(() {
    AutomationDeviceCommands.register(screenReader: () => _screen);
  });
}

void _automationDeviceCommands_should_answerKeyboardInset() {
  testWidgets('AutomationDeviceCommands should answer keyboard inset', (
    tester,
  ) async {
    _setUpView(tester);

    final answer = await _ask(AutomationProtocol.keyboardReadCommand);

    expect(answer, {AutomationProtocol.keyboardInsetKey: _keyboardInset});
  });
}

void _automationDeviceCommands_should_answerScreenViewKeyboardAndPlatform() {
  testWidgets(
    'AutomationDeviceCommands should answer screen view keyboard and platform',
    (tester) async {
      _setUpView(tester);

      final answer = await _ask(AutomationProtocol.screenReadCommand);

      expect(answer, {
        AutomationProtocol.screenKey: _screen,
        AutomationProtocol.viewKey: {
          AutomationProtocol.widthKey: _logicalWidth,
          AutomationProtocol.heightKey: _logicalHeight,
        },
        AutomationProtocol.keyboardInsetKey: _keyboardInset,
        AutomationProtocol.platformKey: defaultTargetPlatform.name,
      });
    },
  );
}

void _automationDeviceCommands_should_answerNoScreenWhenReaderReturnsNull() {
  testWidgets(
    'AutomationDeviceCommands should answer no screen when reader returns null',
    (tester) async {
      _setUpView(tester);
      AutomationDeviceCommands.register(screenReader: () => null);

      final answer = await _ask(AutomationProtocol.screenReadCommand);

      expect(answer[AutomationProtocol.screenKey], isNull);
    },
  );
}

void _automationDeviceCommands_should_callScreenReaderAtCommandTime() {
  testWidgets('AutomationDeviceCommands should call screen reader at command '
      'time', (tester) async {
    _setUpView(tester);

    int calls = 0;

    AutomationDeviceCommands.register(
      screenReader: () {
        calls++;

        return null;
      },
    );
    expect(calls, 0);

    await _ask(AutomationProtocol.screenReadCommand);

    expect(calls, 1);
  });
}

// The command registry is static, so the case that needs `locale.apply`
// unregistered runs before any case that registers an applier.
void _automationDeviceCommands_should_skipLocaleApplyWithoutApplier() {
  test('AutomationDeviceCommands should not register locale apply without an '
      'applier', () {
    expect(
      () => _ask(AutomationProtocol.localeApplyCommand, {
        AutomationProtocol.localeKey: 'uk',
      }),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          startsWith('No automation command'),
        ),
      ),
    );
  });
}

void _automationDeviceCommands_should_readNoFrameWithoutFlags() {
  testWidgets('AutomationDeviceCommands should read no frame without flags', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp());

    final answer = await _ask(AutomationProtocol.screenReadCommand);

    expect(answer.containsKey(AutomationProtocol.textsKey), isFalse);
    expect(answer.containsKey(AutomationProtocol.widgetsKey), isFalse);
  });
}

void _automationDeviceCommands_should_readTheTextsOfTheFrameOnRequest() {
  testWidgets('AutomationDeviceCommands should read the texts of the frame', (
    tester,
  ) async {
    _setUpView(tester);

    await tester.pumpWidget(_buildApp());

    final answer = await _ask(AutomationProtocol.screenReadCommand, {
      AutomationProtocol.textsKey: true,
    });

    expect(answer[AutomationProtocol.textsKey], [_frameText]);
    expect(answer.containsKey(AutomationProtocol.widgetsKey), isFalse);
  });
}

void _automationDeviceCommands_should_readTheWidgetsOfTheFrameOnRequest() {
  testWidgets('AutomationDeviceCommands should read the widgets of the frame', (
    tester,
  ) async {
    _setUpView(tester);

    await tester.pumpWidget(_buildApp());

    final answer = await _ask(AutomationProtocol.screenReadCommand, {
      AutomationProtocol.widgetsKey: true,
    });

    expect(answer[AutomationProtocol.widgetsKey], contains('Text'));
    expect(answer.containsKey(AutomationProtocol.textsKey), isFalse);
  });
}

void _automationDeviceCommands_should_applyTheLocaleWithTheApplier() {
  test(
    'AutomationDeviceCommands should apply the locale with the applier',
    () async {
      final languageCodes = <String>[];

      AutomationDeviceCommands.register(
        screenReader: () => null,
        localeApplier: languageCodes.add,
      );

      final answer = await _ask(AutomationProtocol.localeApplyCommand, {
        AutomationProtocol.localeKey: 'uk',
      });

      expect(languageCodes, ['uk']);
      expect(answer, {AutomationProtocol.localeKey: 'uk'});
    },
  );
}

void _automationDeviceCommands_should_rejectALocaleWithoutLanguageCode() {
  test('AutomationDeviceCommands should reject a locale without a code', () {
    AutomationDeviceCommands.register(
      screenReader: () => null,
      localeApplier: (_) {},
    );
    expect(() => _ask(AutomationProtocol.localeApplyCommand), throwsStateError);
  });
}

Widget _buildApp() {
  return const Directionality(
    textDirection: TextDirection.ltr,
    child: Text(_frameText),
  );
}

void _setUpView(WidgetTester tester) {
  tester.view
    ..devicePixelRatio = _pixelRatio
    ..physicalSize = const Size(
      _logicalWidth * _pixelRatio,
      _logicalHeight * _pixelRatio,
    )
    ..viewInsets = const FakeViewPadding(bottom: _keyboardInset);

  addTearDown(tester.view.reset);
}

Future<Map<String, Object?>> _ask(
  String command, [
  Map<String, Object?> payload = const {},
]) async {
  final message = jsonEncode({'command': command, ...payload});

  final answer = await AutomationCommandRegistry.handle(message);

  return jsonDecode(answer) as Map<String, Object?>;
}
