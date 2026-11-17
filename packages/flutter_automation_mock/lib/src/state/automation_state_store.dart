import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_mock/src/state/automation_state.dart';

/// {@category Utils}
///
/// The files that hold the choice of a tester, the presets and the reports of
/// the runs, in one folder of the project.
///
/// Only the code of the package writes and reads them. `state.json` holds the
/// mode, the scenario, the walk in progress and the outcome failures. The
/// scenario holds the failures and latencies of single paths. The launch
/// reads it and keeps it. `presets/<name>.json` holds a scenario the tester
/// saved. `runs/<id>/report.json` holds the report of a run; the store keeps
/// the newest [maxRuns].
///
/// A write goes to a temporary file first and a rename completes it, so a
/// crash never leaves half a file. The writes of one folder run one after
/// another, also across store objects.
final class AutomationStateStore {
  /// How many run reports the store keeps.
  static const maxRuns = 20;

  static const _encoder = JsonEncoder.withIndent('  ');
  static const _stateFileName = 'state.json';
  static const _presetsFolder = 'presets';
  static const _runsFolder = 'runs';
  static const _reportFileName = 'report.json';
  static const _jsonExtension = '.json';
  static const _temporaryExtension = '.tmp';
  static final _queues = <String, Future<void>>{};
  static int _temporaryCounter = 0;

  /// Folder that holds the files.
  final String directory;

  /// Creates the store over [directory], which the app can write and the
  /// system does not clean.
  AutomationStateStore(this.directory);

  /// Reads `state.json`. A missing or broken file gives the default state.
  Future<AutomationState> read() async {
    final json = await _readJson(File('$directory/$_stateFileName'));

    return AutomationState.fromJson(json);
  }

  /// Writes [state] to `state.json`.
  Future<void> write(AutomationState state) {
    return _writeJson(File('$directory/$_stateFileName'), state.toJson());
  }

  /// Reads `state.json`, lets [change] build the new state and writes it, with
  /// no other write between the read and the write.
  ///
  /// The [change] parameter receives the state on disk.
  Future<void> update(AutomationState Function(AutomationState) change) {
    return _enqueue(() async {
      final file = File('$directory/$_stateFileName');

      final json = await _readJson(file);

      await _writeJsonNow(
        file,
        change(AutomationState.fromJson(json)).toJson(),
      );
    });
  }

  /// Deletes `state.json`, so the next launch starts from the default state.
  Future<void> reset() async {
    final file = File('$directory/$_stateFileName');

    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Names of the saved presets, sorted.
  Future<List<String>> listPresets() async {
    final folder = Directory('$directory/$_presetsFolder');

    if (!folder.existsSync()) {
      return const [];
    }

    final names = folder
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith(_jsonExtension))
        .map((name) => name.substring(0, name.length - _jsonExtension.length))
        .toList();

    return names..sort();
  }

  /// Reads the scenario JSON of the preset [name], empty when it does not
  /// exist.
  Future<Map<String, Object?>> readPreset(String name) {
    return _readJson(_resolvePreset(name));
  }

  /// Saves the scenario JSON [scenario] as the preset [name].
  ///
  /// Throws an [ArgumentError] when [name] is empty or holds a path separator.
  Future<void> savePreset(String name, Map<String, Object?> scenario) {
    return _writeJson(_resolvePreset(name), scenario);
  }

  /// Deletes the preset [name].
  Future<void> deletePreset(String name) async {
    final file = _resolvePreset(name);

    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Saves [report] as the report of a new run and drops the oldest reports
  /// above [maxRuns].
  ///
  /// The [runId] parameter names the run folder; it sorts by time.
  /// Returns the file of the report.
  Future<File> saveRun(String runId, Map<String, Object?> report) async {
    _checkName(runId);

    final file = File('$directory/$_runsFolder/$runId/$_reportFileName');

    await _writeJson(file, report);
    await _dropOldRuns(keep: runId);

    return file;
  }

  /// Ids of the saved runs, newest first.
  Future<List<String>> listRuns() async {
    final folder = Directory('$directory/$_runsFolder');

    if (!folder.existsSync()) {
      return const [];
    }

    final ids = folder
        .listSync()
        .whereType<Directory>()
        .map((run) => run.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .toList();

    return ids..sort((first, second) => second.compareTo(first));
  }

  /// Reads the report of the run [runId], empty when it does not exist.
  Future<Map<String, Object?>> readRun(String runId) {
    _checkName(runId);

    return _readJson(File('$directory/$_runsFolder/$runId/$_reportFileName'));
  }

  File _resolvePreset(String name) {
    _checkName(name);

    return File('$directory/$_presetsFolder/$name$_jsonExtension');
  }

  void _checkName(String name) {
    if (!_isPlainFileName(name)) {
      throw ArgumentError.value(name, 'name', 'Must be a plain file name');
    }
  }

  bool _isPlainFileName(String name) {
    final isRelativeSegment = name == '.' || name == '..';
    final hasSeparator = name.contains('/') || name.contains('\\');

    return name.trim().isNotEmpty && !isRelativeSegment && !hasSeparator;
  }

  Future<void> _dropOldRuns({required String keep}) async {
    final ids = await listRuns();

    final others = ids.where((id) => id != keep);

    for (final id in others.skip(maxRuns - 1)) {
      await Directory('$directory/$_runsFolder/$id').delete(recursive: true);
    }
  }

  Future<Map<String, Object?>> _readJson(File file) async {
    if (!file.existsSync()) {
      return const {};
    }

    try {
      final json = jsonDecode(await file.readAsString());

      return json is Map<String, Object?> ? json : const {};
    } on FormatException {
      return const {};
    }
  }

  Future<void> _writeJson(File file, Map<String, Object?> json) {
    return _enqueue(() => _writeJsonNow(file, json));
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final previous = _queues[directory] ?? Future<void>.value();
    final next = previous.then((_) => action());

    _queues[directory] = next.then((_) {}, onError: (_) {});

    return next;
  }

  Future<void> _writeJsonNow(File file, Map<String, Object?> json) async {
    await file.parent.create(recursive: true);

    _temporaryCounter += 1;

    final temporary = File(
      '${file.path}.$_temporaryCounter$_temporaryExtension',
    );

    await temporary.writeAsString(_encoder.convert(json), flush: true);
    await temporary.rename(file.path);
  }
}
