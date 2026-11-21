import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';

/// {@category Utils}
///
/// Serves the files of a site folder over HTTP on `127.0.0.1`. A browser
/// opens the page of a version from that address. Such a page reads its data
/// with `fetch`. A browser refuses `fetch` for a page opened from a file.
///
/// The server picks a free port. It answers with the file that the path of
/// the request names under the site folder, or with the `index.html` of a
/// folder. The extension of the file gives the `Content-Type`. A `.gz` file
/// goes out as `application/gzip` with no `Content-Encoding`. The page gets
/// the gzip bytes. The answer is `404` for a path that names no file. It is
/// `404` also for a file outside the site folder, a symbolic link to such a
/// file included.
final class AtlasSiteServer {
  static const _indexFileName = 'index.html';
  static const _defaultContentType = 'application/octet-stream';
  static const _contentTypes = {
    '.html': 'text/html; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.gz': 'application/gzip',
    '.js': 'text/javascript; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.png': 'image/png',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
  };
  static final _leadingSlashes = RegExp('^/+');

  final String _sitePath;
  final HttpServer _server;

  AtlasSiteServer._(this._sitePath, this._server);

  /// The address of the `index.html` of the site folder.
  Uri get address {
    return Uri(
      scheme: 'http',
      host: _server.address.address,
      port: _server.port,
      path: '/',
    );
  }

  /// Starts a server for the site folder at [sitePath].
  ///
  /// Throws an [AtlasException] when [sitePath] names no folder.
  static Future<AtlasSiteServer> start(String sitePath) async {
    final directory = Directory(sitePath);

    if (!directory.existsSync()) {
      throw AtlasException('No site folder at $sitePath.');
    }

    final server = AtlasSiteServer._(
      directory.resolveSymbolicLinksSync(),
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );

    server._server.listen(server._answer);

    return server;
  }

  /// Opens [address] in the browser of the user with the command of the
  /// platform: `open` on macOS, `xdg-open` on Linux, `cmd /c start` on
  /// Windows. It does nothing when the platform has no such command.
  static Future<void> openInBrowser(Uri address) async {
    final command = switch (Platform.operatingSystem) {
      'macos' => ['open'],
      'windows' => ['cmd', '/c', 'start'],
      _ => ['xdg-open'],
    };

    try {
      await Process.run(command.first, [...command.skip(1), '$address']);
    } on ProcessException {
      return;
    }
  }

  /// The address of the page of the version with the label [version]. It is
  /// [address] when [version] is `null`.
  Uri resolvePageAddress(String? version) {
    return version == null
        ? address
        : address.resolve('${Uri.encodeComponent(version)}/');
  }

  /// Stops the server.
  Future<void> stop() => _server.close(force: true);

  Future<void> _answer(HttpRequest request) async {
    final response = request.response;
    final path = _tryResolvePath(request.uri.path);

    if (path == null) {
      response.statusCode = HttpStatus.notFound;
    } else if (_isFolderWithoutSlash(path, request.uri.path)) {
      response.statusCode = HttpStatus.movedPermanently;

      response.headers.set(HttpHeaders.locationHeader, '${request.uri.path}/');
    } else {
      await _sendFile(response, _resolveFile(path));
    }

    await response.close();
  }

  String? _tryResolvePath(String requestPath) {
    final relativePath = _tryDecode(
      requestPath,
    )?.replaceFirst(_leadingSlashes, '');

    if (relativePath == null) {
      return null;
    }

    final path = p.normalize(p.join(_sitePath, relativePath));

    if (path != _sitePath && !p.isWithin(_sitePath, path)) {
      return null;
    }

    return _isInsideSite(_resolveFile(path)) ? path : null;
  }

  String? _tryDecode(String requestPath) {
    try {
      return Uri.decodeComponent(requestPath);
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
  }

  bool _isInsideSite(File file) {
    if (!file.existsSync()) {
      return false;
    }

    return p.isWithin(_sitePath, file.resolveSymbolicLinksSync());
  }

  bool _isFolderWithoutSlash(String path, String requestPath) {
    return Directory(path).existsSync() && !requestPath.endsWith('/');
  }

  File _resolveFile(String path) {
    return Directory(path).existsSync()
        ? File(p.join(path, _indexFileName))
        : File(path);
  }

  Future<void> _sendFile(HttpResponse response, File file) async {
    response.headers
      ..set(
        HttpHeaders.contentTypeHeader,
        _contentTypes[p.extension(file.path)] ?? _defaultContentType,
      )
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..contentLength = file.lengthSync();

    await response.addStream(file.openRead());
  }
}
