import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_runner/src/recording/automation_recording.dart';

/// {@category Utils}
///
/// The folder that holds one recording file per flow variant:
/// `<directory>/<flow>/<variant>.json`.
final class AutomationRecordingFiles {
  static const _jsonExtension = '.json';

  /// Folder of the recordings.
  final String directory;

  const AutomationRecordingFiles(this.directory);

  /// Writes [recording] to the file of its flow variant and returns the file.
  File write(AutomationRecording recording) {
    final file = File(
      '$directory/${recording.flow}/${recording.variant}$_jsonExtension',
    );

    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(recording.toJson()),
    );

    return file;
  }

  /// Writes the recording of [report] when the run passed and returns its file.
  /// A run that failed leaves the folder as it is and answers `null`.
  ///
  /// The [report] parameter is the report that the runner prints.
  File? writeReport(Map<String, Object?> report) {
    if (report['ok'] != true) {
      return null;
    }

    return write(AutomationRecording.fromReport(report));
  }

  /// Reads every recording of the folder, sorted by flow and variant. A missing
  /// folder gives none.
  List<AutomationRecording> readAll() {
    final folder = Directory(directory);

    if (!folder.existsSync()) {
      return const [];
    }

    final recordings = folder
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith(_jsonExtension))
        .map(_read)
        .whereType<AutomationRecording>()
        .toList();

    return recordings..sort(_compare);
  }

  AutomationRecording? _read(File file) {
    final json = jsonDecode(file.readAsStringSync());

    return json is Map<String, Object?>
        ? AutomationRecording.fromJson(json)
        : null;
  }

  int _compare(AutomationRecording first, AutomationRecording second) {
    final byFlow = first.flow.compareTo(second.flow);

    return byFlow == 0 ? first.variant.compareTo(second.variant) : byFlow;
  }
}
