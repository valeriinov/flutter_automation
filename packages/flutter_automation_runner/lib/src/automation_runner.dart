import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter_automation_driver/flutter_automation_driver.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:image/image.dart' as image;

import 'package:flutter_automation_runner/src/automation_block_library.dart';
import 'package:flutter_automation_runner/src/automation_capture.dart';
import 'package:flutter_automation_runner/src/automation_capture_stages.dart';
import 'package:flutter_automation_runner/src/automation_coverage_manifest.dart';
import 'package:flutter_automation_runner/src/automation_device.dart';
import 'package:flutter_automation_runner/src/automation_driver_command.dart';
import 'package:flutter_automation_runner/src/automation_flow.dart';
import 'package:flutter_automation_runner/src/automation_frame_summary.dart';
import 'package:flutter_automation_runner/src/automation_journal_answer.dart';
import 'package:flutter_automation_runner/src/automation_keyboard_composite.dart';
import 'package:flutter_automation_runner/src/automation_probe_series.dart';
import 'package:flutter_automation_runner/src/automation_runner_config.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';
import 'package:flutter_automation_runner/src/automation_screen_answer.dart';
import 'package:flutter_automation_runner/src/automation_target_rect.dart';

/// A step of a capture run: its 1-based [number] in the variant and the [stage]
/// that the next user action opens. A step that is no user action belongs to
/// the stage before it.
typedef _CapturedStep = ({AutomationStep step, int number, int stage});

typedef _KeyboardScreenshot = ({
  image.Image screen,
  int insetBefore,
  int insetAfter,
});

/// {@category Utils}
///
/// Walks one variant of a flow of the app in one command. It sends the steps to
/// the app back to back and times each of them.
///
/// The app must run with `--dart-define=ENABLE_FLUTTER_DRIVER=true`. A flow
/// file in the flows directory of the `flutter_automation:` section of the
/// project holds one variant per way through its journey. The runner builds the
/// named variant from the block library, so a whole walk costs one command
/// instead of one command per tap.
///
/// ```shell
/// fvm dart run flutter_automation_runner:run \
///   <flow> <variant> --uri ws://127.0.0.1:51626/token=/ws
/// ```
///
/// A variant may declare the mock configuration it needs. The runner pushes it
/// into the app before the first step. A run is therefore set up without a
/// rebuild or an edit in Dart. `--dry-run` expands the variant and prints its
/// resolved steps. It does not use a device. `--timeline-out <path>` writes the
/// raw timeline that a traced window downloaded, in the Chrome trace format
/// that DevTools and Perfetto open. It gives what the frame summary does not: a
/// mark's arguments and the full list of spans inside one frame.
///
/// Stdout carries the report and nothing else. The report is one line of JSON
/// with the per-step milliseconds, the totals and, when the variant traced, the
/// frame statistics of its window. The live commentary goes to stderr. The run
/// stops at the first step that fails and exits with code 1. It names the step
/// that stopped it.
final class AutomationRunner {
  static const _connectTimeout = Duration(seconds: 20);
  static const _isolateProbeTimeout = Duration(seconds: 5);
  static const _hotRestartTimeout = Duration(seconds: 60);
  static const _relaunchTimeout = Duration(seconds: 30);
  static const _relaunchPollInterval = Duration(milliseconds: 500);
  static const _serviceRegistrationTimeout = Duration(seconds: 5);
  static const _stillFrameTimeout = Duration(seconds: 3);
  static const _driverExtension = 'ext.flutter.driver';
  static const _uriOption = '--uri';
  static const _timelineOutOption = '--timeline-out';
  static const _dryRunFlag = '--dry-run';
  static const _captureOption = '--capture';
  static const _systemKeyboardFlag = '--system-keyboard';
  static const _localeOption = '--locale';
  static const _uriCachePath = '.dart_tool/automation_runner_uri';
  static const _ledgerPath = '.dart_tool/automation_runner_runs.jsonl';
  static const _mockApplyCommand = 'mock.apply';
  static const _localeApplyCommand = 'locale.apply';
  static const _screenReadCommand = AutomationProtocol.screenReadCommand;
  static const _journalReadCommand = 'journal.read';
  static const _keyboardReadCommand = AutomationProtocol.keyboardReadCommand;
  static const _keyboardScreenshotAttempts = 3;

  final List<String> args;

  final AutomationRunnerConfig config;

  final AutomationCaptureStages _stages;

  final String? _timelineOutPath;

  AutomationDevice? _device;
  Map<String, Object?>? _frames;

  AutomationRunner(this.args, {required this.config})
    : _stages = AutomationCaptureStages.fromArgs(args),
      _timelineOutPath = _tryReadTimelineOutPath(args);

  bool get _showsSystemKeyboard => args.contains(_systemKeyboardFlag);

  String get _usage =>
      'usage: flutter_automation_runner:run <flow> [variant] '
      '[$_uriOption <dart vm service uri>] [$_timelineOutOption <path>] '
      '[$_dryRunFlag] '
      '[$_captureOption <directory> '
      '[${AutomationCaptureStages.shootOption} <stage,stage>] '
      '[${AutomationCaptureStages.untilOption} <stage>]] '
      '[$_systemKeyboardFlag] '
      '[$_localeOption <locale code, default ${config.defaultLocale}>]';

  String get _launchClause {
    final hint = config.launchHint;

    return hint == null ? '' : ', launched with $hint';
  }

  Future<void> run() async {
    final command = Stopwatch()..start();
    final locale = _tryReadLocale();
    final flow = _readFlow(locale ?? config.defaultLocale);
    final capturePath = _readCapturePath();

    if (_stages.isPartial && capturePath == null) {
      throw AutomationRunnerException(_usage);
    }

    if (args.contains(_dryRunFlag)) {
      _reportDryRun(flow);

      return;
    }

    final uri = _resolveVmServiceUri();

    final launchDriver = await _connect(uri);

    final capture = capturePath == null
        ? null
        : AutomationCapture(
            capturePath,
            flow: flow.name,
            variant: flow.variant,
          );

    final setupMs = await _applyMockConfig(launchDriver, flow);

    final driver = flow.mockConfig.isEmpty
        ? launchDriver
        : await _relaunchOnMockConfig(launchDriver, uri);

    if (locale != null) {
      await _applyLocale(driver, locale);
    }

    if (_showsSystemKeyboard) {
      await _turnTextEntryEmulationOff(driver);
    }

    final launch = capture == null ? null : await _clearJournal(driver);
    final steps = <Map<String, Object?>>[];
    final total = Stopwatch()..start();
    int stage = 0;
    bool isCut = false;

    for (int index = 0; index < flow.steps.length; index += 1) {
      final step = flow.steps[index];

      if (capture != null && _isCutBefore(step, stage)) {
        steps.add(await _captureCutAction(driver, step, stage));

        isCut = true;
        break;
      }

      // A step answers with a list because a `probeSeries` is one step of the
      // flow and many entries of the report: one per read, so a reader walks
      // the numbers of one node without knowing how the flow was written.
      final results = capture == null
          ? await _runStep(driver, step)
          : await _runCapturedStep(driver, capture, (
              step: step,
              number: index + 1,
              stage: stage,
            ));

      steps.addAll(results);

      if (step.isUserAction) {
        stage += 1;
      }

      if (results.any((result) => result['ok'] == false)) {
        break;
      }
    }

    total.stop();

    final runEnd = await _captureRunEnd(driver, capture, isCut: isCut);

    await driver.close();

    command.stop();

    final report = {
      'flow': flow.name,
      'variant': flow.variant,
      'ok': steps.every((step) => step['ok'] == true),
      'commandMs': command.elapsedMilliseconds,
      'setupMs': setupMs,
      'totalMs': total.elapsedMilliseconds,
      // A top-level key rather than the value of the `traceStop` step: the
      // ledger replaces `steps` with a count, so anything a later run is
      // compared against has to stand beside it.
      'frames': ?_frames,
      ...runEnd,
      'launch': ?launch,
      if (isCut) 'until': _stages.lastStage,
      'steps': steps,
    };

    stdout.writeln(jsonEncode(report));

    if (capture == null) {
      _appendToLedger(report, steps);
    } else {
      capture.appendReport(report);
    }

    if (report['ok'] == false) {
      exitCode = 1;
    }
  }

  String? _readCapturePath() {
    final index = args.indexOf(_captureOption);

    if (index < 0) {
      return null;
    }

    if (index + 1 >= args.length || args[index + 1].startsWith('-')) {
      throw const AutomationRunnerException(
        'The $_captureOption option needs a directory.',
      );
    }

    return args[index + 1];
  }

  static String? _tryReadTimelineOutPath(List<String> args) {
    final index = args.indexOf(_timelineOutOption);

    if (index < 0) {
      return null;
    }

    if (index + 1 >= args.length || args[index + 1].startsWith('-')) {
      throw const AutomationRunnerException(
        'The $_timelineOutOption option needs a file path.',
      );
    }

    return args[index + 1];
  }

  String? _tryReadLocale() {
    final index = args.indexOf(_localeOption);

    if (index < 0) {
      return null;
    }

    if (index + 1 >= args.length || args[index + 1].startsWith('-')) {
      throw const AutomationRunnerException(
        'The $_localeOption option needs a locale code.',
      );
    }

    return args[index + 1];
  }

  /// Prints the steps that the variant expands to, and does not touch a device.
  ///
  /// The runner builds a flow from blocks. This output therefore tells a
  /// malformed reference or an unresolved parameter apart from a step that the
  /// app failed.
  void _reportDryRun(AutomationFlow flow) {
    stderr.writeln('${flow.id}: ${flow.steps.length} steps');

    for (final step in flow.steps) {
      stderr.writeln('  ${step.action.padRight(16)}${step.label}');
    }

    stdout.writeln(
      jsonEncode({
        'flow': flow.name,
        'variant': flow.variant,
        'dryRun': true,
        'entry': ?flow.entry?.toJson(),
        'stateOf': ?flow.stateOf,
        'mock': flow.mockConfig,
        'steps': flow.steps.map(_reportDryRunStep).toList(),
      }),
    );
  }

  /// The step as [AutomationStep.toReport] prints it, beside the finder that
  /// the run sends to the driver in its locale.
  Map<String, Object?> _reportDryRunStep(AutomationStep step) {
    return {...step.toReport(), 'finder': ?step.finder?.serialize()};
  }

  void _appendToLedger(
    Map<String, Object?> report,
    List<Map<String, Object?>> steps,
  ) {
    final entry = {
      ...report,
      'steps': steps.length,
      'failed': steps
          .where((step) => step['ok'] == false)
          .map((step) => step['label'])
          .toList(),
    };

    File(
      _ledgerPath,
    ).writeAsStringSync('${jsonEncode(entry)}\n', mode: FileMode.append);
  }

  AutomationFlow _readFlow(String locale) {
    final name = args.firstOrNull;

    if (name == null || name.startsWith('-')) {
      throw AutomationRunnerException(_usage);
    }

    final file = File('${config.flowsPath}/$name.json');

    if (!file.existsSync()) {
      throw AutomationRunnerException('No flow file at ${file.path}.');
    }

    return AutomationFlow.fromJson(
      name: name,
      variant: _readVariant(),
      json: jsonDecode(file.readAsStringSync()),
      blocks: AutomationBlockLibrary.fromDirectory(config.blocksPath),
      finders: config.finderRegistry,
      locale: locale,
    );
  }

  String? _readVariant() {
    final variant = args.elementAtOrNull(1);

    if (variant == null || variant.startsWith('-')) {
      return null;
    }

    return variant;
  }

  String _resolveVmServiceUri() {
    final index = args.indexOf(_uriOption);

    if (index >= 0 && index + 1 < args.length) {
      return args[index + 1];
    }

    final cache = File(_uriCachePath);

    if (cache.existsSync()) {
      return cache.readAsStringSync().trim();
    }

    throw const AutomationRunnerException(
      'No Dart VM Service uri. Pass $_uriOption <uri> once — the run caches it '
      'in $_uriCachePath and reuses it until the app is relaunched. The uri is '
      'in the flutter run log, and in the Dart MCP listConnectedApps answer.',
    );
  }

  Future<FlutterDriver> _connect(String uri, {int? isolateNumber}) async {
    try {
      final driver = await FlutterDriver.connect(
        dartVmServiceUrl: uri,
        isolateNumber:
            isolateNumber ?? await _tryResolveDriverIsolateNumber(uri),
        logCommunicationToFile: false,
      ).timeout(_connectTimeout);

      File(_uriCachePath).writeAsStringSync(uri);

      return driver;
    } on Object catch (error) {
      throw AutomationRunnerException(
        'No drivable app at $uri: $error\n'
        'Relaunch it with --dart-define=ENABLE_FLUTTER_DRIVER=true, then pass '
        'the new uri with $_uriOption.',
      );
    }
  }

  /// The number of the isolate that the driver answers from. It is `null` when
  /// the probe reaches none, and the first isolate of the app then stands as
  /// the pick.
  ///
  /// A hot restart leaves the app with more than one `main` isolate, and the
  /// restarted one is not the first of them. `FlutterDriver.connect` with no
  /// number takes that first isolate, so the connection times out on an app
  /// that runs and accepts the driver.
  ///
  /// The [excluded] parameter names an isolate that the probe passes over, the
  /// one that a restart replaced.
  Future<int?> _tryResolveDriverIsolateNumber(
    String uri, {
    int? excluded,
  }) async {
    try {
      return await _readDriverIsolateNumber(
        uri,
        excluded: excluded,
      ).timeout(_isolateProbeTimeout);
    } on Object {
      return null;
    }
  }

  Future<int?> _readDriverIsolateNumber(String uri, {int? excluded}) async {
    final socket = await WebSocket.connect(uri);

    try {
      return await _findDriverIsolateNumber(
        _VmServiceSession(socket),
        excluded: excluded,
      );
    } finally {
      await socket.close();
    }
  }

  Future<int?> _findDriverIsolateNumber(
    _VmServiceSession session, {
    int? excluded,
  }) async {
    final vm = await session.tryCall(id: 'getVM', method: 'getVM');

    final isolates = vm?['isolates'];

    if (isolates is! List) {
      return null;
    }

    for (final isolate in isolates.whereType<Map<String, Object?>>()) {
      final number = await _tryReadDriverIsolateNumber(session, isolate);

      if (number != null && number != excluded) {
        return number;
      }
    }

    return null;
  }

  /// The number of this isolate, given it carries the driver extension.
  Future<int?> _tryReadDriverIsolateNumber(
    _VmServiceSession session,
    Map<String, Object?> isolateRef,
  ) async {
    final id = isolateRef['id'];
    final number = int.tryParse('${isolateRef['number']}');

    if (id is! String || number == null) {
      return null;
    }

    final isolate = await session.tryCall(
      id: 'getIsolate-$id',
      method: 'getIsolate',
      params: {'isolateId': id},
    );

    final extensions = isolate?['extensionRPCs'];

    if (extensions is! List || !extensions.contains(_driverExtension)) {
      return null;
    }

    return number;
  }

  /// Pushes the mock configuration of the variant into the app.
  ///
  /// Returns the milliseconds it cost. It returns zero when the variant names
  /// no configuration, and the run then walks the app in whatever state it
  /// launched in.
  Future<int> _applyMockConfig(
    FlutterDriver driver,
    AutomationFlow flow,
  ) async {
    if (flow.mockConfig.isEmpty) {
      return 0;
    }

    final watch = Stopwatch()..start();

    try {
      final answer = await driver.requestData(
        jsonEncode({'command': _mockApplyCommand, 'config': flow.mockConfig}),
      );

      watch.stop();
      stderr.writeln('ok   ${watch.elapsedMilliseconds}ms  mock $answer');

      return watch.elapsedMilliseconds;
    } on Object catch (error) {
      throw AutomationRunnerException(
        'The app refused the mock configuration of ${flow.id}: $error\n'
        'A variant naming a "mock" block needs an app that answers '
        '$_mockApplyCommand$_launchClause.',
      );
    }
  }

  /// Restarts the app so that it launches on the mock configuration just
  /// applied. Then it connects to the restarted app.
  ///
  /// The app reads its session, and the link and the push that opened it, once,
  /// on launch. `mock.apply` saves the configuration that the next launch seeds
  /// from. The restart is the `hotRestart` method that `flutter run` registers
  /// on the app's websocket.
  Future<FlutterDriver> _relaunchOnMockConfig(
    FlutterDriver driver,
    String uri,
  ) async {
    final watch = Stopwatch()..start();

    final launchIsolate = await _tryResolveDriverIsolateNumber(uri);

    await driver.close();
    await _hotRestart(uri);

    final isolate = await _waitForDriverIsolate(uri, excluded: launchIsolate);
    final restartedDriver = await _connect(uri, isolateNumber: isolate);

    // The extension registers before `runApp`, so a step sent on connect can
    // reach an app with no root widget yet.
    await restartedDriver.waitUntilFirstFrameRasterized();
    await _waitPastSplash(restartedDriver);

    watch.stop();
    stderr.writeln('ok   ${watch.elapsedMilliseconds}ms  relaunch on mock');

    return restartedDriver;
  }

  Future<void> _hotRestart(String uri) async {
    final socket = await WebSocket.connect(uri);

    try {
      if (await _tryHotRestart(_VmServiceSession(socket))) {
        return;
      }
    } finally {
      await socket.close();
    }

    throw AutomationRunnerException(
      'No flutter run answers hotRestart at $uri, so the app cannot launch on '
      'the mock configuration of the variant. Relaunch it with flutter run and '
      'pass the new uri with $_uriOption.',
    );
  }

  /// `flutter run` registers `hotRestart` under the number of whichever client
  /// it was. A call to a number that nobody registered never answers. The
  /// method therefore comes from the `ServiceRegistered` event that the
  /// `Service` stream replays to a new listener.
  Future<bool> _tryHotRestart(_VmServiceSession session) async {
    final registration = session.answers.firstWhere(
      _isHotRestartRegistration,
      orElse: () => const {},
    );

    await session.tryCall(
      id: 'streamListen-Service',
      method: 'streamListen',
      params: {'streamId': 'Service'},
    );

    try {
      final method = _readRegisteredMethod(
        await registration.timeout(_serviceRegistrationTimeout),
      );

      final answer = await session
          .tryCall(id: 'hotRestart', method: method, params: {'pause': false})
          .timeout(_hotRestartTimeout);

      return answer != null;
    } on TimeoutException {
      return false;
    }
  }

  static bool _isHotRestartRegistration(Map<String, Object?> message) {
    final event = _readServiceEvent(message);

    return event?['kind'] == 'ServiceRegistered' &&
        event?['service'] == 'hotRestart';
  }

  static String _readRegisteredMethod(Map<String, Object?> message) {
    return '${_readServiceEvent(message)?['method']}';
  }

  static Map<String, Object?>? _readServiceEvent(Map<String, Object?> message) {
    final params = message['params'];

    if (params is! Map<String, Object?>) {
      return null;
    }

    final event = params['event'];

    return event is Map<String, Object?> ? event : null;
  }

  /// The relaunched app starts on the splash and opens its first screen once
  /// its startup requests complete, which the screen it logs states.
  Future<void> _waitPastSplash(FlutterDriver driver) async {
    final watch = Stopwatch()..start();

    while (watch.elapsed < _relaunchTimeout) {
      final answer = await _readScreen(driver);

      if (answer.isPastSplash(config.splashScreen)) {
        return;
      }

      await Future<void>.delayed(_relaunchPollInterval);
    }

    throw AutomationRunnerException(
      'The app restarted on the mock configuration but logged no screen past '
      'the splash within ${_relaunchTimeout.inSeconds} s.',
    );
  }

  Future<int> _waitForDriverIsolate(String uri, {int? excluded}) async {
    final watch = Stopwatch()..start();

    while (watch.elapsed < _relaunchTimeout) {
      final number = await _tryResolveDriverIsolateNumber(
        uri,
        excluded: excluded,
      );

      if (number != null) {
        return number;
      }

      await Future<void>.delayed(_relaunchPollInterval);
    }

    throw AutomationRunnerException(
      'The app restarted on the mock configuration but registered no driver '
      'within ${_relaunchTimeout.inSeconds} s.',
    );
  }

  Future<void> _applyLocale(FlutterDriver driver, String locale) async {
    try {
      final answer = await driver.requestData(
        jsonEncode({'command': _localeApplyCommand, 'locale': locale}),
      );

      stderr.writeln('ok   locale $answer');
    } on Object catch (error) {
      throw AutomationRunnerException(
        'The app refused the locale "$locale": $error\n'
        'The $_localeOption option needs an app that answers '
        '$_localeApplyCommand$_launchClause.',
      );
    }
  }

  /// The system keyboard rises for a field that has focus while the own text
  /// input of the driver is off. The runner turns that input off before the
  /// first step can focus a field.
  Future<void> _turnTextEntryEmulationOff(FlutterDriver driver) async {
    try {
      await driver.setTextEntryEmulation(enabled: false);
    } on Object catch (error) {
      throw AutomationRunnerException(
        'The app refused to turn text entry emulation off: $error',
      );
    }
  }

  /// Returns the record of the launch the app keeps beside the journal.
  Future<Map<String, Object?>?> _clearJournal(FlutterDriver driver) async {
    try {
      return (await _readJournal(driver)).launch;
    } on Object catch (error) {
      throw AutomationRunnerException(
        'The app refused $_journalReadCommand: $error\n'
        'A capture run needs an app that answers '
        '$_journalReadCommand$_launchClause.',
      );
    }
  }

  bool _isCutBefore(AutomationStep step, int stage) {
    return step.isUserAction && _stages.stopsBefore(stage);
  }

  /// The entry of the action at which `--until` stops the walk. The run does
  /// not send the action, and its `journalBeforeAction` closes the journal of
  /// the stage before it.
  Future<Map<String, Object?>> _captureCutAction(
    FlutterDriver driver,
    AutomationStep step,
    int stage,
  ) async {
    return {
      'label': step.label,
      ..._describeStep(step),
      'ok': true,
      ...await _captureUnshotAction(
        driver,
        step,
        shouldKeepRecords: _stages.shoots(stage - 1),
      ),
    };
  }

  Future<List<Map<String, Object?>>> _runCapturedStep(
    FlutterDriver driver,
    AutomationCapture capture,
    _CapturedStep capturedStep,
  ) async {
    final (:step, number: _, :stage) = capturedStep;

    final screenshot = await _captureBeforeAction(
      driver,
      capture,
      capturedStep,
    );

    if (screenshot['ok'] == false) {
      return [
        {'label': step.label, ..._describeStep(step), ...screenshot},
      ];
    }

    final results = await _runStep(driver, step);

    final last = results.lastOrNull;

    if (last == null) {
      return results;
    }

    last.addAll(screenshot);

    if (last['ok'] == true) {
      final journalStage = step.isUserAction ? stage : stage - 1;

      last.addAll(
        await _captureJournal(
          driver,
          step,
          shouldKeepRecords: _stages.shoots(journalStage),
        ),
      );
    }

    return results;
  }

  /// The records read before the action of a stage arrived after the last
  /// read of the stage before it, and are that stage's.
  Future<Map<String, Object?>> _captureBeforeAction(
    FlutterDriver driver,
    AutomationCapture capture,
    _CapturedStep capturedStep,
  ) async {
    final (:step, number: _, :stage) = capturedStep;

    if (!step.isUserAction) {
      return const {};
    }

    if (_stages.shoots(stage)) {
      return _captureScreenBeforeAction(driver, capture, capturedStep);
    }

    return _captureUnshotAction(
      driver,
      step,
      shouldKeepRecords: _stages.shoots(stage - 1),
    );
  }

  Future<Map<String, Object?>> _captureScreenBeforeAction(
    FlutterDriver driver,
    AutomationCapture capture,
    _CapturedStep capturedStep,
  ) async {
    final (:step, :number, :stage) = capturedStep;

    await _waitForStillFrame(driver);

    final screenshot = await _captureScreenshot(driver, capture, step, number);

    if (screenshot['ok'] == false) {
      return screenshot;
    }

    return {
      ...screenshot,
      ...await _captureJournalBeforeAction(
        driver,
        step,
        shouldKeepRecords: _stages.shoots(stage - 1),
        shouldMeasureTarget: true,
      ),
    };
  }

  /// `journal.read` empties the journal, so a stage left unshot still reads
  /// it, to keep its records out of the next stage's.
  Future<Map<String, Object?>> _captureUnshotAction(
    FlutterDriver driver,
    AutomationStep step, {
    required bool shouldKeepRecords,
  }) async {
    await _waitForStillFrame(driver);

    return {
      'screenshot': null,
      ...await _captureJournalBeforeAction(
        driver,
        step,
        shouldKeepRecords: shouldKeepRecords,
        shouldMeasureTarget: false,
      ),
    };
  }

  Future<Map<String, Object?>> _captureScreenshot(
    FlutterDriver driver,
    AutomationCapture capture,
    AutomationStep step,
    int stepNumber,
  ) async {
    try {
      return {
        'screenshot': capture.saveScreenshot(
          screen: await _takeScreenshot(driver),
          step: stepNumber,
        ),
      };
    } on Object catch (error) {
      stderr.writeln('fail capture  ${step.label}');

      return {
        'screenshot': null,
        'ok': false,
        'error': 'Could not capture the screen before ${step.label}: $error',
      };
    }
  }

  Future<Map<String, Object?>> _captureJournalBeforeAction(
    FlutterDriver driver,
    AutomationStep step, {
    required bool shouldKeepRecords,
    required bool shouldMeasureTarget,
  }) async {
    try {
      final answer = await _readJournal(
        driver,
        shouldReadTexts: true,
        shouldReadWidgets: true,
      );

      return {
        'journalBeforeAction': shouldKeepRecords ? answer.records : const [],
        'texts': answer.texts,
        'widgets': answer.widgets,
        if (shouldMeasureTarget)
          ...await _captureTargetRect(
            driver,
            step,
            (await _readScreen(driver)).view,
          ),
      };
    } on Object catch (error) {
      stderr.writeln('fail capture  ${step.label}');

      return {
        'ok': false,
        'error': 'Could not read the journal before ${step.label}: $error',
      };
    }
  }

  Future<Map<String, Object?>> _captureTargetRect(
    FlutterDriver driver,
    AutomationStep step,
    AutomationViewSize? view,
  ) async {
    final finder = step.finder;

    if (finder == null) {
      return const {};
    }

    try {
      final rect = await _readTargetRect(driver, step, finder, view);

      return {'targetRect': rect.toJson()};
    } on Object catch (error) {
      stderr.writeln('     no target rect  ${step.label}: $error');

      return {'targetRectError': '$error'};
    }
  }

  Future<AutomationTargetRect> _readTargetRect(
    FlutterDriver driver,
    AutomationStep step,
    SerializableFinder finder,
    AutomationViewSize? view,
  ) async {
    if (view == null) {
      throw StateError(
        '$_screenReadCommand answered no view of a positive size.',
      );
    }

    return AutomationTargetRect.fromOffsets(
      topLeft: await driver.getTopLeft(finder, timeout: step.timeout),
      bottomRight: await driver.getBottomRight(finder, timeout: step.timeout),
      view: view,
    );
  }

  Future<List<Map<String, Object?>>> _runStep(
    FlutterDriver driver,
    AutomationStep step,
  ) async {
    if (step.action == 'probeSeries') {
      return _runProbeSeries(driver, step);
    }

    return [await _report(step.label, step, () => _sendStep(driver, step))];
  }

  Future<Map<String, Object?>> _captureJournal(
    FlutterDriver driver,
    AutomationStep step, {
    required bool shouldKeepRecords,
  }) async {
    try {
      final answer = await _readJournal(driver, shouldReadTexts: true);

      return {
        'journal': shouldKeepRecords ? answer.records : const [],
        'screen': (await _readScreen(driver)).screen,
        'textsAfterStep': answer.texts,
      };
    } on Object catch (error) {
      stderr.writeln('fail capture  ${step.label}');

      return {
        'ok': false,
        'error': 'Could not read the journal after ${step.label}: $error',
      };
    }
  }

  Future<Map<String, Object?>> _captureRunEnd(
    FlutterDriver driver,
    AutomationCapture? capture, {
    required bool isCut,
  }) async {
    if (capture == null) {
      return const {};
    }

    if (isCut) {
      return _readManifest(driver);
    }

    return {
      ...await _captureEndScreenshot(driver, capture),
      ...await _captureEndJournal(driver),
      ...await _readManifest(driver),
    };
  }

  Future<Map<String, Object?>> _captureEndScreenshot(
    FlutterDriver driver,
    AutomationCapture capture,
  ) async {
    await _waitForStillFrame(driver);

    try {
      return {
        'endScreenshot': capture.saveEndScreenshot(
          screen: await _takeScreenshot(driver),
        ),
      };
    } on Object catch (error) {
      stderr.writeln('fail capture  end screenshot');

      return {'endScreenshotError': '$error'};
    }
  }

  /// An animation that loops, such as a loader, never lets the wait pass, so
  /// after its timeout the run takes the screenshot mid-animation.
  Future<void> _waitForStillFrame(FlutterDriver driver) async {
    try {
      await driver.waitUntilNoTransientCallbacks(timeout: _stillFrameTimeout);
    } on DriverError {
      stderr.writeln(
        '     still animating after ${_stillFrameTimeout.inSeconds}s',
      );
    }
  }

  Future<image.Image> _takeScreenshot(FlutterDriver driver) async {
    if (!_showsSystemKeyboard) {
      return _decodeScreenshot(await driver.screenshot());
    }

    for (int attempt = 1; ; attempt += 1) {
      final (:screen, :insetBefore, :insetAfter) =
          await _takeKeyboardScreenshot(driver);

      if (insetBefore == insetAfter) {
        return screen;
      }

      if (attempt == _keyboardScreenshotAttempts) {
        throw StateError(
          'The keyboard stood $insetBefore px high before the device '
          'screenshot and $insetAfter px after it, on each of '
          '$_keyboardScreenshotAttempts attempts.',
        );
      }
    }
  }

  /// The driver renders the Flutter layer alone, so the run reads a system
  /// keyboard over it from a screenshot of the device. The run reads the
  /// keyboard height before the first screenshot and after the last. A keyboard
  /// that still moves gives two heights, and the run takes its shot again.
  Future<_KeyboardScreenshot> _takeKeyboardScreenshot(
    FlutterDriver driver,
  ) async {
    final insetBefore = await _readKeyboardInset(driver);

    final screen = _decodeScreenshot(await driver.screenshot());

    if (insetBefore <= 0) {
      return (
        screen: screen,
        insetBefore: insetBefore,
        insetAfter: await _readKeyboardInset(driver),
      );
    }

    final device = await _resolveDevice(driver);
    final deviceScreen = await device.takeScreenshot();
    final insetAfter = await _readKeyboardInset(driver);

    return (
      screen: AutomationKeyboardComposite.compose(
        screen: screen,
        deviceScreen: _decodeScreenshot(deviceScreen),
        keyboardInset: insetBefore,
      ),
      insetBefore: insetBefore,
      insetAfter: insetAfter,
    );
  }

  image.Image _decodeScreenshot(List<int> bytes) {
    final screen = image.decodeImage(Uint8List.fromList(bytes));

    if (screen == null) {
      throw StateError('A screenshot is not an image.');
    }

    return screen;
  }

  /// The height of the system keyboard in physical pixels, zero while none
  /// stands.
  Future<int> _readKeyboardInset(FlutterDriver driver) async {
    final response = await driver.requestData(
      jsonEncode({'command': _keyboardReadCommand}),
    );

    if (jsonDecode(response) case {'inset': final num inset}) {
      return inset.round();
    }

    throw StateError(
      '$_keyboardReadCommand did not return an {"inset"} object.',
    );
  }

  Future<AutomationDevice> _resolveDevice(FlutterDriver driver) async {
    final device = _device;

    if (device != null) {
      return device;
    }

    final foundDevice = await AutomationDevice.find(
      (await _readScreen(driver)).platform,
    );

    _device = foundDevice;

    return foundDevice;
  }

  Future<Map<String, Object?>> _captureEndJournal(FlutterDriver driver) async {
    try {
      final answer = await _readJournal(
        driver,
        shouldReadTexts: true,
        shouldReadWidgets: true,
      );

      return {
        'endJournal': answer.records,
        'endTexts': answer.texts,
        'endWidgets': answer.widgets,
      };
    } on Object catch (error) {
      stderr.writeln('fail capture  end journal');

      return {'endJournalError': '$error'};
    }
  }

  Future<AutomationScreenAnswer> _readScreen(FlutterDriver driver) async {
    final response = await driver.requestData(
      jsonEncode({'command': _screenReadCommand}),
    );

    return AutomationScreenAnswer.fromJson(jsonDecode(response));
  }

  /// The app empties its journal on every read.
  Future<AutomationJournalAnswer> _readJournal(
    FlutterDriver driver, {
    bool shouldReadTexts = false,
    bool shouldReadWidgets = false,
  }) async {
    final response = await driver.requestData(
      jsonEncode({
        'command': _journalReadCommand,
        if (shouldReadTexts) 'texts': true,
        if (shouldReadWidgets) 'widgets': true,
      }),
    );

    return AutomationJournalAnswer.fromJson(jsonDecode(response));
  }

  /// A profile build keeps no coverage, so its run carries the error instead.
  Future<Map<String, Object?>> _readManifest(FlutterDriver driver) async {
    try {
      return {
        'manifest': await AutomationCoverageManifest.read(
          driver,
          appPackagePrefix: config.packagePrefix,
        ),
      };
    } on Object catch (error) {
      stderr.writeln('fail capture  manifest');

      return {'manifestError': '$error'};
    }
  }

  /// Cycles the step's probes until its window has elapsed.
  ///
  /// The window is time, not a count of cycles, because a probe is a driver
  /// round trip. The same count covers a shorter slice of the movement on a
  /// faster machine. Coverage would then track the machine instead of the
  /// animation.
  Future<List<Map<String, Object?>>> _runProbeSeries(
    FlutterDriver driver,
    AutomationStep step,
  ) async {
    final phase = Stopwatch()..start();
    final reads = <Map<String, Object?>>[];
    final positionsByProbeName = <String, List<double>>{};

    for (int cycle = 0; phase.elapsed < step.duration; cycle += 1) {
      final dueProbes = step.probes
          .where((probe) => probe.after <= phase.elapsed)
          .toList(growable: false);

      final cycleReads = await _runProbeCycle(driver, step, cycle, dueProbes);

      reads.addAll(cycleReads);
      _recordProbePositions(
        probes: dueProbes,
        reads: cycleReads,
        positionsByProbeName: positionsByProbeName,
      );

      if (cycleReads.any((read) => read['ok'] == false)) {
        break;
      }
    }

    if (reads.any((read) => read['ok'] == false)) {
      return reads;
    }

    final signChanges = _resolveSignChangesByProbeName(positionsByProbeName);

    if (signChanges.isEmpty) {
      return reads;
    }

    final details = signChanges.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(', ');

    return [
      ...reads,
      await _report(
        '${step.label} monotonicity',
        step,
        () async =>
            throw StateError('Probe series has sign changes ($details).'),
      ),
    ];
  }

  Future<List<Map<String, Object?>>> _runProbeCycle(
    FlutterDriver driver,
    AutomationStep step,
    int cycle,
    List<AutomationProbe> probes,
  ) async {
    final reads = <Map<String, Object?>>[];

    for (final probe in probes) {
      reads.add(await _runProbe(driver, step, probe, cycle));

      if (reads.last['ok'] == false) {
        break;
      }
    }

    return reads;
  }

  void _recordProbePositions({
    required List<AutomationProbe> probes,
    required List<Map<String, Object?>> reads,
    required Map<String, List<double>> positionsByProbeName,
  }) {
    for (int index = 0; index < reads.length; index += 1) {
      final read = reads[index];

      if (read['ok'] != true) {
        continue;
      }

      final value = read['value'];

      if (value is! Map) {
        continue;
      }

      final dy = value['dy'];

      if (dy is! num) {
        continue;
      }

      positionsByProbeName
          .putIfAbsent(probes[index].name, () => <double>[])
          .add(dy.toDouble());
    }
  }

  Map<String, int> _resolveSignChangesByProbeName(
    Map<String, List<double>> positionsByProbeName,
  ) {
    final signChanges = <String, int>{};

    for (final entry in positionsByProbeName.entries) {
      final changes = resolveProbeSeriesSignChanges(entry.value);

      if (changes > 0) {
        signChanges[entry.key] = changes;
      }
    }

    return signChanges;
  }

  Future<Map<String, Object?>> _runProbe(
    FlutterDriver driver,
    AutomationStep step,
    AutomationProbe probe,
    int cycle,
  ) {
    return _report(
      '${step.label} ${probe.name} $cycle',
      step,
      () => _probeCenter(driver, probe.finder, step.timeout),
    );
  }

  Future<Map<String, Object?>> _report(
    String label,
    AutomationStep step,
    Future<Object?> Function() send,
  ) async {
    final watch = Stopwatch()..start();

    try {
      final value = await send();

      watch.stop();
      stderr.writeln('ok   ${watch.elapsedMilliseconds}ms  $label');

      return {
        'label': label,
        ..._describeStep(step),
        'ms': watch.elapsedMilliseconds,
        'ok': true,
        'value': ?value,
      };
    } on Object catch (error) {
      watch.stop();
      stderr.writeln('fail ${watch.elapsedMilliseconds}ms  $label');

      return {
        'label': label,
        ..._describeStep(step),
        'ms': watch.elapsedMilliseconds,
        'ok': false,
        'error': '$error',
      };
    }
  }

  Map<String, Object?> _describeStep(AutomationStep step) {
    return {
      'action': step.action,
      'target': ?step.target,
      'block': ?step.block,
    };
  }

  Future<Object?> _sendStep(FlutterDriver driver, AutomationStep step) async {
    if (step.action == 'probeCenter') {
      return _probeCenter(driver, _resolveFinder(step), step.timeout);
    }

    await _sendAction(driver, step);

    return null;
  }

  Future<Object?> _probeCenter(
    FlutterDriver driver,
    SerializableFinder finder,
    Duration timeout,
  ) async {
    final center = await driver.getCenter(finder, timeout: timeout);

    return {'dx': center.dx, 'dy': center.dy};
  }

  Future<void> _sendAction(FlutterDriver driver, AutomationStep step) {
    return switch (step.action) {
      'tap' => driver.tap(_resolveFinder(step), timeout: step.timeout),
      'waitFor' => driver.waitFor(_resolveFinder(step), timeout: step.timeout),
      'waitForAbsent' => driver.waitForAbsent(
        _resolveFinder(step),
        timeout: step.timeout,
      ),
      'waitForTappable' => driver.waitForTappable(
        _resolveFinder(step),
        timeout: step.timeout,
      ),
      'scrollIntoView' => driver.scrollIntoView(
        _resolveFinder(step),
        timeout: step.timeout,
      ),
      'scroll' => driver.scroll(
        _resolveFinder(step),
        step.dx,
        step.dy,
        step.duration,
        frequency: step.frequency,
        timeout: step.timeout,
      ),
      'enterText' => _enterText(driver, step),
      'driverCommand' => driver.sendCommand(
        AutomationDriverCommand(
          name: _resolveCommand(step),
          arguments: step.arguments,
          timeout: step.timeout,
        ),
      ),
      'traceStart' => _startTracing(driver, step),
      'traceStop' => _stopTracing(driver, step),
      _ => throw AutomationRunnerException('Unknown action "${step.action}".'),
    };
  }

  /// Opens the window over which the run reads the frames.
  ///
  /// The step's own `durationMs` is how long the run leaves the screen still
  /// first. A `waitFor` resolves the moment its widget is in the tree. The
  /// screen that it named is then still opening: its list still moves to its
  /// first position, and its overlay still fades. A window opened right then
  /// reads that opening as the step it wraps.
  ///
  /// The VM keeps each event recorded since the app started, and `startTracing`
  /// alone adds to that buffer. The run therefore clears the window next. A
  /// summary read over the buffer as it stands names the widest frame of the
  /// whole history of the app, its own opening. It does not name the widest
  /// frame of the step that the window wraps.
  Future<void> _startTracing(FlutterDriver driver, AutomationStep step) async {
    await Future<void>.delayed(step.duration);
    await driver.clearTimeline(timeout: step.timeout);
    await driver.startTracing(timeout: step.timeout);
  }

  /// Keeps the timeline open for the step's own window. It then downloads the
  /// timeline and puts what it says about the frames of that window into the
  /// report.
  ///
  /// The window is a wait, not a `waitFor`, because the step measures how the
  /// app spent a slice of the clock, not whether something appeared.
  Future<void> _stopTracing(FlutterDriver driver, AutomationStep step) async {
    await Future<void>.delayed(step.duration);

    final timeline = await driver.stopTracingAndDownloadTimeline(
      timeout: step.timeout,
    );

    _frames = AutomationFrameSummary(
      timeline,
      goalMillis: config.frameGoalMs,
    ).toReport();

    _maybeWriteTimeline(timeline);
  }

  /// Writes the raw [timeline] to the path `--timeline-out` names, when it
  /// names one.
  void _maybeWriteTimeline(Timeline timeline) {
    final timelineOutPath = _timelineOutPath;

    if (timelineOutPath == null) {
      return;
    }

    File(timelineOutPath).writeAsStringSync(jsonEncode(timeline.json));
  }

  /// The driver enters text only through its own text input, which the system
  /// keyboard gives way to. The input stands in for the text entry alone, and
  /// the keyboard stays up around it.
  Future<void> _enterText(FlutterDriver driver, AutomationStep step) async {
    final text = _resolveText(step);

    if (!_showsSystemKeyboard) {
      return driver.enterText(text, timeout: step.timeout);
    }

    await driver.setTextEntryEmulation(enabled: true, timeout: step.timeout);

    try {
      await driver.enterText(text, timeout: step.timeout);
    } on Object {
      await _tryTurnTextEntryEmulationOff(driver, step);

      rethrow;
    }

    await driver.setTextEntryEmulation(enabled: false, timeout: step.timeout);
  }

  /// Turns emulation off after a text entry that failed. It writes its own
  /// failure to stderr, so the failure of the text entry is the one that the
  /// step reports.
  Future<void> _tryTurnTextEntryEmulationOff(
    FlutterDriver driver,
    AutomationStep step,
  ) async {
    try {
      await driver.setTextEntryEmulation(enabled: false, timeout: step.timeout);
    } on Object catch (error) {
      stderr.writeln('fail emulation off after ${step.label}: $error');
    }
  }

  SerializableFinder _resolveFinder(AutomationStep step) {
    final finder = step.finder;

    if (finder == null) {
      throw AutomationRunnerException('"${step.action}" needs a finder.');
    }

    return finder;
  }

  String _resolveText(AutomationStep step) {
    final text = step.text;

    if (text == null) {
      throw AutomationRunnerException('"${step.action}" needs a text.');
    }

    return text;
  }

  String _resolveCommand(AutomationStep step) {
    final command = step.command;

    if (command == null) {
      throw AutomationRunnerException('"${step.action}" needs a command.');
    }

    return command;
  }
}

/// One Dart VM Service socket and the answers that arrive over it, each answer
/// with the id of the request it belongs to.
final class _VmServiceSession {
  final WebSocket socket;
  final Stream<Map<String, Object?>> answers;

  _VmServiceSession(this.socket)
    : answers = socket
          .cast<String>()
          .map(jsonDecode)
          .where((message) => message is Map<String, Object?>)
          .cast<Map<String, Object?>>()
          .asBroadcastStream();

  /// Sends one request and returns the result of the answer with its id.
  Future<Map<String, Object?>?> tryCall({
    required String id,
    required String method,
    Map<String, Object?> params = const {},
  }) async {
    socket.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );

    final answer = await answers.firstWhere((message) => message['id'] == id);

    final result = answer['result'];

    return result is Map<String, Object?> ? result : null;
  }
}
