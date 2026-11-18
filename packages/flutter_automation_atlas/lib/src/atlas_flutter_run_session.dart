import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_launch_settings.dart';

/// {@category Utils}
///
/// One `flutter run --machine` of the app on a simulator, driven over the
/// JSON-RPC its stdin and stdout carry.
///
/// The app is built and launched once per capture command and restarted before
/// every variant, so each walk starts from launch instead of from the screen
/// the walk before it parked on.
final class AtlasFlutterRunSession {
  static const _startTimeout = Duration(minutes: 20);
  static const _requestTimeout = Duration(minutes: 2);
  static const _exitTimeout = Duration(seconds: 30);
  static const _appLogPrefix = 'flutter:';

  final Process _process;
  final Completer<void> _started = Completer();
  final Map<int, Completer<Map<String, Object?>>> _pendingRequests = {};
  int _lastRequestId = 0;
  bool _isRunning = true;

  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  String? _appId;
  String? _vmServiceUri;

  AtlasFlutterRunSession._(this._process);

  /// The Dart VM Service websocket uri of the running app.
  String get vmServiceUri {
    final uri = _vmServiceUri;

    if (uri == null) {
      throw const AtlasException('flutter run named no VM Service uri.');
    }

    return uri;
  }

  /// Builds and launches the app on the simulator [deviceId] names, as
  /// [launch] tells, and waits until it runs.
  static Future<AtlasFlutterRunSession> start(
    AtlasLaunchSettings launch, {
    required String deviceId,
  }) async {
    stderr.writeln('Launching the app on $deviceId');

    final command = launch.resolveCommand('flutter');

    final process = await Process.start(command.executable, [
      ...command.arguments,
      'run',
      '--machine',
      '--debug',
      if (launch.flavor case final flavor?) ...['--flavor', flavor],
      '-t',
      launch.entry,
      for (final define in launch.defines) '--dart-define=$define',
      '-d',
      deviceId,
    ]);

    final session = AtlasFlutterRunSession._(process).._listen();

    try {
      await session._started.future.timeout(_startTimeout);
    } on Object catch (error) {
      await session.stop();

      throw AtlasException('The app did not start: $error');
    }

    return session;
  }

  /// Restarts the app from `main`, dropping every route and all state.
  Future<void> restart() async {
    final response = await _request('app.restart', {
      'appId': _appId,
      'fullRestart': true,
      'pause': false,
      'reason': 'manual',
    });

    final result = AtlasJson.tryReadObject(response, 'result') ?? {};

    if (result['code'] != 0) {
      throw AtlasException('The app did not restart: $result');
    }
  }

  /// Stops the app and ends `flutter run`.
  Future<void> stop() async {
    if (_isRunning && _appId != null) {
      await _requestStop();
    }

    _process.kill();

    await _process.exitCode.timeout(_exitTimeout, onTimeout: () => -1);
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
  }

  void _listen() {
    _stdoutSubscription = _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine, onDone: _handleStdoutDone);
    _stderrSubscription = _process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_forwardLine);
  }

  Future<void> _requestStop() async {
    try {
      await _request('app.stop', {'appId': _appId});
    } on Object catch (error) {
      stderr.writeln('The app did not stop cleanly: $error');
    }
  }

  void _handleLine(String line) {
    final message = _tryDecodeMessage(line);

    if (message == null) {
      _forwardLine(line);

      return;
    }

    final id = message['id'];

    if (id is int) {
      _completeRequest(id, message);

      return;
    }

    _handleEvent(message);
  }

  void _handleStdoutDone() {
    const error = AtlasException('flutter run exited.');

    _isRunning = false;

    if (!_started.isCompleted) {
      _started.completeError(error);
    }

    for (final request in _pendingRequests.values) {
      request.completeError(error);
    }

    _pendingRequests.clear();
  }

  Future<Map<String, Object?>> _request(
    String method,
    Map<String, Object?> params,
  ) {
    _lastRequestId += 1;

    final id = _lastRequestId;
    final completer = Completer<Map<String, Object?>>();

    _pendingRequests[id] = completer;

    _process.stdin.writeln(
      jsonEncode([
        {'id': id, 'method': method, 'params': params},
      ]),
    );

    return completer.future.timeout(_requestTimeout);
  }

  // The machine output of flutter run wraps every message in a one-item
  // JSON list.
  Map<String, Object?>? _tryDecodeMessage(String line) {
    final trimmed = line.trim();

    if (!trimmed.startsWith('[')) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmed);

      return decoded is List<Object?>
          ? decoded.whereType<Map<String, Object?>>().firstOrNull
          : null;
    } on FormatException {
      return null;
    }
  }

  void _completeRequest(int id, Map<String, Object?> message) {
    final completer = _pendingRequests.remove(id);

    if (completer == null) {
      return;
    }

    if (message.containsKey('error')) {
      completer.completeError(
        AtlasException('flutter run refused a request: $message'),
      );

      return;
    }

    completer.complete(message);
  }

  void _handleEvent(Map<String, Object?> message) {
    final params = AtlasJson.tryReadObject(message, 'params') ?? {};

    switch (message['event']) {
      case 'app.start':
        _appId = AtlasJson.tryReadString(params, 'appId');
      case 'app.debugPort':
        _vmServiceUri = AtlasJson.tryReadString(params, 'wsUri');
      case 'app.started':
        _completeStart();
      case 'app.progress':
      case 'daemon.logMessage':
        _forwardMessage(params);
      case _:
    }
  }

  void _completeStart() {
    if (_appId == null || _vmServiceUri == null) {
      _started.completeError(
        const AtlasException(
          'flutter run started the app without naming its id or its VM '
          'Service uri.',
        ),
      );

      return;
    }

    _started.complete();
  }

  void _forwardMessage(Map<String, Object?> params) {
    final text = AtlasJson.tryReadString(params, 'message') ?? '';

    const LineSplitter().convert(text).forEach(_forwardLine);
  }

  // The flutter run tool prefixes every line the app prints with the word
  // flutter and a colon.
  void _forwardLine(String line) {
    if (line.startsWith(_appLogPrefix)) {
      return;
    }

    stderr.writeln(line);
  }
}
