import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _chromeEnvironmentKey = 'CHROME_EXECUTABLE';
const _macChromePath =
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const _pathChromeNames = ['google-chrome', 'chromium', 'chromium-browser'];
const _listeningPrefix = 'DevTools listening on ';
const _startTimeout = Duration(seconds: 30);
const _deleteAttempts = 50;
const _deleteDelay = Duration(milliseconds: 100);

/// Returns the Chrome executable that `CHROME_EXECUTABLE` names, the macOS
/// application, or the first Chrome on `PATH`. Returns `null` when the
/// machine has none.
String? tryFindChrome() {
  final named = Platform.environment[_chromeEnvironmentKey];

  if (named != null && File(named).existsSync()) {
    return named;
  }

  if (File(_macChromePath).existsSync()) {
    return _macChromePath;
  }

  for (final name in _pathChromeNames) {
    final result = Process.runSync('which', [name]);

    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
  }

  return null;
}

/// A headless Chrome that has one page open and evaluates scripts in it
/// through the DevTools protocol.
final class HeadlessChrome {
  final Process _process;
  final Directory _profile;
  final WebSocket _socket;
  final Map<int, Completer<Map<String, Object?>>> _replies = {};
  int _nextId = 0;

  HeadlessChrome._(this._process, this._profile, this._socket) {
    _socket.listen(_readReply);
  }

  /// Starts the [executable] on the page at [pageUri].
  static Future<HeadlessChrome> open(String executable, Uri pageUri) async {
    final profile = Directory.systemTemp.createTempSync('headless_chrome');

    final process = await Process.start(executable, [
      '--headless=new',
      '--disable-gpu',
      '--no-first-run',
      '--no-sandbox',
      '--remote-debugging-port=0',
      '--user-data-dir=${profile.path}',
      '$pageUri',
    ]);
    final browserUri = await _readBrowserUri(process);
    final pageSocketUri = await _readPageSocketUri(browserUri);

    return HeadlessChrome._(
      process,
      profile,
      await WebSocket.connect('$pageSocketUri'),
    );
  }

  /// Returns the value of [expression] after its promise settles.
  Future<Object?> evaluate(String expression) async {
    final reply = await _send('Runtime.evaluate', {
      'expression': expression,
      'awaitPromise': true,
      'returnByValue': true,
    });

    final result = reply['result'];

    if (result is! Map<String, Object?>) {
      throw StateError('Chrome refused the script: ${reply['error']}');
    }

    final exception = result['exceptionDetails'];

    if (exception != null) {
      throw StateError('The page script failed: $exception');
    }

    return (result['result'] as Map<String, Object?>)['value'];
  }

  /// Stops the browser and deletes its profile.
  Future<void> close() async {
    await _socket.close();

    _process.kill();

    await _process.exitCode;
    await _deleteProfile();
  }

  // The helper processes of Chrome outlive the main one and still write to
  // the profile for a moment.
  Future<void> _deleteProfile() async {
    for (int attempt = 1; attempt < _deleteAttempts; attempt++) {
      try {
        _profile.deleteSync(recursive: true);

        return;
      } on FileSystemException {
        await Future<void>.delayed(_deleteDelay);
      }
    }

    _profile.deleteSync(recursive: true);
  }

  Future<Map<String, Object?>> _send(
    String method,
    Map<String, Object?> params,
  ) {
    final id = _nextId++;
    final reply = Completer<Map<String, Object?>>();

    _replies[id] = reply;

    _socket.add(jsonEncode({'id': id, 'method': method, 'params': params}));

    return reply.future;
  }

  void _readReply(Object? message) {
    final reply = jsonDecode(message as String) as Map<String, Object?>;

    _replies.remove(reply['id'])?.complete(reply);
  }

  static Future<Uri> _readBrowserUri(Process process) {
    return process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .firstWhere((line) => line.startsWith(_listeningPrefix))
        .then((line) => Uri.parse(line.substring(_listeningPrefix.length)))
        .timeout(_startTimeout);
  }

  static Future<Uri> _readPageSocketUri(Uri browserUri) async {
    final client = HttpClient();

    try {
      final request = await client.getUrl(
        Uri.http('${browserUri.host}:${browserUri.port}', '/json/list'),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      final targets = jsonDecode(body) as List<Object?>;
      final page = targets.cast<Map<String, Object?>>().firstWhere(
        (target) => target['type'] == 'page',
      );

      return Uri.parse(page['webSocketDebuggerUrl'] as String);
    } finally {
      client.close();
    }
  }
}
