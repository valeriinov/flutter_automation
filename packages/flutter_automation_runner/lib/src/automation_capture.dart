import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as image;

/// {@category Utils}
///
/// Writes what one capture run of a flow variant records into its directory. It
/// writes a compact PNG of the screen before each user action and after the
/// last step. It also writes the report of the run in `reports.jsonl`.
final class AutomationCapture {
  static const _screenshotWidth = 360;
  static const _maxScreenshotBytes = 100 * 1024;
  static const _pngCompressionLevel = 9;
  static const _pngExtension = '.png';
  static const _endScreenshotName = 'end';
  static const _firstDuplicateSuffix = 2;
  static const _reportFileName = 'reports.jsonl';

  final Directory _directory;
  final String _flow;
  final String _variant;

  AutomationCapture(
    String directoryPath, {
    required String flow,
    required String variant,
  }) : _directory = Directory(directoryPath),
       _flow = flow,
       _variant = variant {
    _directory.createSync(recursive: true);
  }

  /// Writes a resized PNG of the [screen] before [step] and returns its name
  /// relative to the capture folder.
  String saveScreenshot({required image.Image screen, required int step}) {
    return _saveScreenshot(screen, '$step');
  }

  /// Writes a resized PNG of the [screen] the run ended on and returns its name
  /// relative to the capture folder.
  String saveEndScreenshot({required image.Image screen}) {
    return _saveScreenshot(screen, _endScreenshotName);
  }

  /// Appends a complete capture report as one JSON Lines record.
  void appendReport(Map<String, Object?> report) {
    File(
      '${_directory.path}/$_reportFileName',
    ).writeAsStringSync('${jsonEncode(report)}\n', mode: FileMode.append);
  }

  String _saveScreenshot(image.Image screen, String name) {
    final resized = image.copyResize(
      screen,
      width: _screenshotWidth,
      interpolation: image.Interpolation.average,
    );
    final quantized = image.quantize(resized);
    final encoded = image.encodePng(quantized, level: _pngCompressionLevel);

    if (encoded.length > _maxScreenshotBytes) {
      throw StateError(
        'Screenshot is ${encoded.length} bytes, the limit is '
        '$_maxScreenshotBytes bytes.',
      );
    }

    final baseFileName = '${_flow}_${_variant}_$name$_pngExtension';
    final fileName = _getAvailableFileName(baseFileName);

    File('${_directory.path}/$fileName').writeAsBytesSync(encoded);

    return fileName;
  }

  String _getAvailableFileName(String baseFileName) {
    if (!_fileExists(baseFileName)) {
      return baseFileName;
    }

    final stem = baseFileName.substring(
      0,
      baseFileName.length - _pngExtension.length,
    );
    int suffix = _firstDuplicateSuffix;

    while (_fileExists('${stem}_$suffix$_pngExtension')) {
      suffix += 1;
    }

    return '${stem}_$suffix$_pngExtension';
  }

  bool _fileExists(String fileName) {
    return File('${_directory.path}/$fileName').existsSync();
  }
}
