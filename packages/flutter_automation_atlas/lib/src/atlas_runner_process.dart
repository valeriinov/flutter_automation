import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_atlas/src/atlas_stage_scope.dart';
import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';

/// {@category Utils}
///
/// The automation runner walking one variant against the running app, as a
/// subprocess writing its capture into a directory.
///
/// A restarted app registers the driver extension only once its first frames
/// are up, so a walk that finds no driver waits and walks once more.
///
/// A full walk of a variant whose flow is in the QA catalogue, in the default
/// locale, also writes the recording of the QA catalogue; a partial walk and a
/// walk in another locale write none.
final class AtlasRunnerProcess {
  static const _driverExtension = 'ext.flutter.driver';
  static const _driverRegistrationDelay = Duration(seconds: 3);

  final AtlasLocations _paths;
  final String _vmServiceUri;
  final String _locale;
  final AtlasProcessStarter _startProcess;

  /// The [startProcess] parameter starts the runner, `Process.start` when
  /// absent.
  const AtlasRunnerProcess(
    this._paths,
    this._vmServiceUri,
    this._locale, {
    AtlasProcessStarter startProcess = _startRunner,
  }) : _startProcess = startProcess;

  /// Walks the [scope] of [variant] with `--capture` into [captureDirectory],
  /// the app in the locale this process was given and the system keyboard
  /// shown in its screenshots, and returns the decoded report.
  Future<Map<String, Object?>> capture(
    AtlasVariantDefinition variant,
    AtlasStageScope scope,
    Directory captureDirectory,
  ) async {
    await Future<void>.delayed(_driverRegistrationDelay);

    final report = await _run(variant, scope, captureDirectory);

    if (!_isDriverMissing(report)) {
      return report;
    }

    stderr.writeln('No driver in the app yet, walking ${variant.id} again');

    await Future<void>.delayed(_driverRegistrationDelay);

    captureDirectory
      ..deleteSync(recursive: true)
      ..createSync(recursive: true);

    return _run(variant, scope, captureDirectory);
  }

  bool _isRecorded(AtlasVariantDefinition variant, AtlasStageScope scope) {
    return variant.isInQaCatalogue &&
        scope.isEveryStage &&
        _locale == _paths.defaultLocale;
  }

  bool _isDriverMissing(Map<String, Object?> report) {
    final runError = report['error'];

    if (runError is String) {
      return runError.contains(_driverExtension);
    }

    final firstStep = AtlasJson.readObjects(report, 'steps').firstOrNull;
    final error = firstStep == null
        ? null
        : AtlasJson.tryReadString(firstStep, 'error');

    return error?.contains(_driverExtension) ?? false;
  }

  Future<Map<String, Object?>> _run(
    AtlasVariantDefinition variant,
    AtlasStageScope scope,
    Directory captureDirectory,
  ) async {
    final dart = _paths.project.launch.resolveCommand('dart');

    final process = await _startProcess(dart.executable, [
      ...dart.arguments,
      'run',
      _paths.runnerEntryPath,
      variant.flow,
      variant.name,
      '--uri',
      _vmServiceUri,
      '--capture',
      captureDirectory.path,
      '--system-keyboard',
      '--locale',
      _locale,
      if (_isRecorded(variant, scope)) ...['--record', _paths.recordingsPath],
      ...scope.runnerArguments,
    ]);

    final stderrSubscription = process.stderr.listen(stderr.add);

    final output = await process.stdout.transform(utf8.decoder).join();

    await stderrSubscription.asFuture<void>();
    await stderrSubscription.cancel();
    await process.exitCode;

    return _decodeReport(output);
  }

  // A launcher banner may precede the report line.
  Map<String, Object?> _decodeReport(String output) {
    final start = output.indexOf('{');

    if (start < 0) {
      throw AtlasException('The runner printed no report: $output');
    }

    return AtlasJson.decodeObject(output.substring(start), 'The runner report');
  }
}

/// {@category Utils}
///
/// Starts the process [executable] with [arguments].
typedef AtlasProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

Future<Process> _startRunner(String executable, List<String> arguments) {
  return Process.start(executable, arguments);
}
