import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'package:flutter_automation_runner/src/automation_keyboard_composite.dart';

const _width = 4;
const _height = 6;
const _keyboardInset = 2;
const _opaqueAlpha = 255;
const _screenRgb = (red: 10, green: 20, blue: 30);
const _keyboardRgb = (red: 200, green: 100, blue: 50);
const _rgbaChannels = 4;

final _screenColor = [
  _screenRgb.red,
  _screenRgb.green,
  _screenRgb.blue,
  _opaqueAlpha,
];

final _keyboardColor = [
  _keyboardRgb.red,
  _keyboardRgb.green,
  _keyboardRgb.blue,
  _opaqueAlpha,
];

void main() {
  group('AutomationKeyboardComposite Tests', () {
    _automationKeyboardComposite_should_takeKeyboardRowsFromSimulatorScreen();
    _automationKeyboardComposite_should_keepScreenWithoutKeyboard();
    _automationKeyboardComposite_should_replaceWholeScreenForTallInset();
    _automationKeyboardComposite_should_rejectScreensOfDifferentSize();
  });
}

void _automationKeyboardComposite_should_takeKeyboardRowsFromSimulatorScreen() {
  test('AutomationKeyboardComposite should take keyboard rows from device '
      'screen', () {
    final screen = _createScreen();
    final composed = AutomationKeyboardComposite.compose(
      screen: screen,
      deviceScreen: _createSimulatorScreen(),
      keyboardInset: _keyboardInset,
    );

    expect(_readRowColors(composed, 0), everyElement(_screenColor));
    expect(
      _readRowColors(composed, _height - _keyboardInset - 1),
      everyElement(_screenColor),
    );
    expect(
      _readRowColors(composed, _height - _keyboardInset),
      everyElement(_keyboardColor),
    );
    expect(_readRowColors(composed, _height - 1), everyElement(_keyboardColor));
    expect(_readRowColors(screen, _height - 1), everyElement(_screenColor));
  });
}

void _automationKeyboardComposite_should_keepScreenWithoutKeyboard() {
  test('AutomationKeyboardComposite should keep screen without keyboard', () {
    final composed = AutomationKeyboardComposite.compose(
      screen: _createScreen(),
      deviceScreen: _createSimulatorScreen(),
      keyboardInset: 0,
    );

    expect(_readRowColors(composed, _height - 1), everyElement(_screenColor));
  });
}

void _automationKeyboardComposite_should_replaceWholeScreenForTallInset() {
  test(
    'AutomationKeyboardComposite should replace whole screen for tall inset',
    () {
      final composed = AutomationKeyboardComposite.compose(
        screen: _createScreen(),
        deviceScreen: _createSimulatorScreen(),
        keyboardInset: _height * 2,
      );

      expect(_readRowColors(composed, 0), everyElement(_keyboardColor));
    },
  );
}

void _automationKeyboardComposite_should_rejectScreensOfDifferentSize() {
  test(
    'AutomationKeyboardComposite should reject screens of different size',
    () {
      expect(
        () => AutomationKeyboardComposite.compose(
          screen: _createScreen(),
          deviceScreen: image.Image(width: _width, height: _height + 1),
          keyboardInset: _keyboardInset,
        ),
        throwsA(isA<StateError>()),
      );
    },
  );
}

image.Image _createScreen() {
  return image.Image(width: _width, height: _height, numChannels: _rgbaChannels)
    ..clear(
      image.ColorRgba8(
        _screenRgb.red,
        _screenRgb.green,
        _screenRgb.blue,
        _opaqueAlpha,
      ),
    );
}

image.Image _createSimulatorScreen() {
  return image.Image(width: _width, height: _height)..clear(
    image.ColorRgb8(_keyboardRgb.red, _keyboardRgb.green, _keyboardRgb.blue),
  );
}

List<List<num>> _readRowColors(image.Image screen, int row) {
  return [
    for (int column = 0; column < screen.width; column += 1)
      _readColor(screen.getPixel(column, row)),
  ];
}

List<num> _readColor(image.Pixel pixel) {
  return [pixel.r, pixel.g, pixel.b, pixel.a];
}
