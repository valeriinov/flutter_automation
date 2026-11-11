import 'dart:convert';
import 'dart:io';

/// {@category Utils}
///
/// The scenario file the next launch of the app starts from.
///
/// A hot restart drops every Dart object, the mock and the scenario a run
/// applied to it included, while the files of the app stay. A scenario saved
/// here is read and removed by the launch that follows, so what the app reads
/// on start already answers from that scenario.
abstract final class MockScenarioFile {
  static const _fileName = 'mock_scenario.json';

  /// Saves [json], a scenario as JSON, in [directory] for the next launch.
  static Future<void> save(String directory, Map<String, Object?> json) async {
    await _resolveFile(directory).writeAsString(jsonEncode(json));
  }

  /// Reads and removes the scenario [save] left in [directory].
  ///
  /// Answers an empty object when it left none or left a file that is not a
  /// JSON object.
  static Future<Map<String, Object?>> consume(String directory) async {
    final file = _resolveFile(directory);

    if (!file.existsSync()) {
      return const {};
    }

    try {
      final json = jsonDecode(await file.readAsString());

      return json is Map<String, Object?> ? json : const {};
    } on FormatException {
      return const {};
    } finally {
      await file.delete();
    }
  }

  static File _resolveFile(String directory) => File('$directory/$_fileName');
}
