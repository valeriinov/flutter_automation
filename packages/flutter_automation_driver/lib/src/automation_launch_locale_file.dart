import 'dart:io';

/// The language code that a run saves for the next launch of the app.
///
/// A hot restart drops every Dart object, while the files of the app stay. The
/// file is in `Directory.systemTemp`: the engine points it at the cache folder
/// of the app on Android and at the `tmp` folder of the app on iOS.
abstract final class AutomationLaunchLocaleFile {
  static const _fileName = 'automation_launch_locale';

  /// Saves [languageCode] for the next launch.
  static Future<void> save(String languageCode) async {
    await _resolveFile().writeAsString(languageCode);
  }

  /// Reads and removes the code that [save] left.
  ///
  /// Answers `null` when [save] left none or left an empty file.
  static String? consume() {
    final file = _resolveFile();

    if (!file.existsSync()) {
      return null;
    }

    try {
      final languageCode = file.readAsStringSync().trim();

      return languageCode.isEmpty ? null : languageCode;
    } finally {
      file.deleteSync();
    }
  }

  static File _resolveFile() {
    return File('${Directory.systemTemp.path}/$_fileName');
  }
}
