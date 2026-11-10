import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_driver/driver_extension.dart';
import 'package:flutter_test/flutter_test.dart';

const _screen = {'name': 'home'};
const _logicalWidth = 400.0;
const _logicalHeight = 800.0;
const _pixelRatio = 2.0;
const _keyboardInset = 600.0;

void main() {
  _setup();
  group('AutomationDeviceCommands Widget Tests', () {
    _automationDeviceCommands_should_answerKeyboardInset();
    _automationDeviceCommands_should_answerScreenViewKeyboardAndPlatform();
    _automationDeviceCommands_should_answerNoScreenWhenReaderReturnsNull();
    _automationDeviceCommands_should_callScreenReaderAtCommandTime();
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

Future<Map<String, Object?>> _ask(String command) async {
  final message = jsonEncode({'command': command});

  final answer = await AutomationCommandHandler.handle(message);

  return jsonDecode(answer) as Map<String, Object?>;
}
