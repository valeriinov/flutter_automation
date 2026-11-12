import 'dart:io';

/// The language code that an automation run applied, kept in a file so that
/// the next launch of the app starts in it.
///
/// A hot restart drops every Dart object, while the files of the app stay.
final class SavedLanguageFile {
  static const _fileName = 'automation_language_code';

  final File _file;

  /// Creates the file handle in [directory], a writable folder of the app.
  SavedLanguageFile(String directory) : _file = File('$directory/$_fileName');

  /// Reads the saved language code. Answers `null` when none is saved.
  String? read() {
    if (!_file.existsSync()) {
      return null;
    }

    final languageCode = _file.readAsStringSync().trim();

    return languageCode.isEmpty ? null : languageCode;
  }

  /// Saves [languageCode] for the next launch.
  Future<void> save(String languageCode) async {
    await _file.writeAsString(languageCode);
  }
}
