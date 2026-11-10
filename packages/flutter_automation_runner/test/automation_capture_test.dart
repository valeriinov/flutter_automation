import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'package:flutter_automation_runner/src/automation_capture.dart';

const _sourceWidth = 720;
const _sourceHeight = 1280;
const _targetWidth = 360;
const _largeImageSize = 400;
const _maxScreenshotBytes = 100 * 1024;
const _pixelChannelModulo = 256;
const _randomSeed = 1701;
const _stripeStep = _sourceWidth ~/ _targetWidth;
const _whiteChannel = 255;
const _flow = 'login';
const _variant = 'phoneOtpSignIn';

void main() {
  group('AutomationCapture Tests', () {
    _automationCapture_should_resizeAndNameScreenshots();
    _automationCapture_should_nameEndScreenshot();
    _automationCapture_should_blendThinStrokesWhenResizing();
    _automationCapture_should_appendReports();
    _automationCapture_should_rejectOversizedScreenshots();
  });
}

void _automationCapture_should_resizeAndNameScreenshots() {
  test('AutomationCapture should resize and name screenshots', () async {
    await _withCaptureDirectory((directory) {
      final sut = _createCapture(directory);
      final source = image.Image(width: _sourceWidth, height: _sourceHeight);
      final fileName = sut.saveScreenshot(screen: source, step: 3);
      final duplicateFileName = sut.saveScreenshot(screen: source, step: 3);
      final file = File('${directory.path}/$fileName');
      final saved = image.decodeImage(file.readAsBytesSync());

      expect(fileName, '${_flow}_${_variant}_3.png');
      expect(duplicateFileName, '${_flow}_${_variant}_3_2.png');
      expect(File('${directory.path}/$duplicateFileName').existsSync(), isTrue);
      expect(saved?.width, _targetWidth);
      expect(file.lengthSync(), lessThanOrEqualTo(_maxScreenshotBytes));
    });
  });
}

void _automationCapture_should_nameEndScreenshot() {
  test('AutomationCapture should name end screenshot', () async {
    await _withCaptureDirectory((directory) {
      final sut = _createCapture(directory);
      final source = image.Image(width: _sourceWidth, height: _sourceHeight);
      final fileName = sut.saveEndScreenshot(screen: source);

      expect(fileName, '${_flow}_${_variant}_end.png');
      expect(File('${directory.path}/$fileName').existsSync(), isTrue);
    });
  });
}

void _automationCapture_should_blendThinStrokesWhenResizing() {
  test('AutomationCapture should blend thin strokes when resizing', () async {
    await _withCaptureDirectory((directory) {
      final sut = _createCapture(directory);
      final source = _createStripedImage();
      final fileName = sut.saveScreenshot(screen: source, step: 1);
      final saved = image.decodePng(
        File('${directory.path}/$fileName').readAsBytesSync(),
      );

      expect(saved?.getPixel(0, 0).r, greaterThan(0));
    });
  });
}

void _automationCapture_should_appendReports() {
  test('AutomationCapture should append reports', () async {
    await _withCaptureDirectory((directory) {
      final sut = _createCapture(directory);

      sut.appendReport({'flow': 'login', 'ok': true});
      sut.appendReport({'flow': 'order_flow', 'ok': false});

      final file = File('${directory.path}/reports.jsonl');
      final reports = file
          .readAsLinesSync()
          .map(jsonDecode)
          .toList(growable: false);

      expect(reports, hasLength(2));
      expect(reports.firstOrNull, containsPair('flow', 'login'));
      expect(reports.last, containsPair('ok', false));
    });
  });
}

void _automationCapture_should_rejectOversizedScreenshots() {
  test('AutomationCapture should reject oversized screenshots', () async {
    await _withCaptureDirectory((directory) {
      final sut = _createCapture(directory);
      final source = _createNoiseImage();

      expect(
        () => sut.saveScreenshot(screen: source, step: 1),
        throwsA(isA<StateError>()),
      );
    });
  });
}

image.Image _createStripedImage() {
  final source = image.Image(width: _sourceWidth, height: _sourceHeight);
  final white = image.ColorRgb8(_whiteChannel, _whiteChannel, _whiteChannel);

  for (int x = 1; x < _sourceWidth; x += _stripeStep) {
    image.drawLine(
      source,
      x1: x,
      y1: 0,
      x2: x,
      y2: _sourceHeight - 1,
      color: white,
    );
  }

  return source;
}

image.Image _createNoiseImage() {
  final source = image.Image(width: _largeImageSize, height: _largeImageSize);
  final random = Random(_randomSeed);

  for (final pixel in source) {
    pixel.setRgb(
      random.nextInt(_pixelChannelModulo),
      random.nextInt(_pixelChannelModulo),
      random.nextInt(_pixelChannelModulo),
    );
  }

  return source;
}

AutomationCapture _createCapture(Directory directory) {
  return AutomationCapture(directory.path, flow: _flow, variant: _variant);
}

Future<void> _withCaptureDirectory(void Function(Directory) body) async {
  final directory = await Directory.systemTemp.createTemp(
    'automation-capture-',
  );

  try {
    body(directory);
  } finally {
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }
}
