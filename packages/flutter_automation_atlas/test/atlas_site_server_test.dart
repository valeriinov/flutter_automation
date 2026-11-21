import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_site_server.dart';

const _version = 'v1.0.0b10_TEST';
const _page = '<html>version page</html>';
const _sitePage = '<html>site page</html>';
const _config = '{"shotUrlTemplate":"https://shots.example/{shot}.png"}';
const _outsideText = 'outside the site folder';
const _linkName = 'link.txt';

final _data = gzip.encode(utf8.encode('{"data":{"flows":[]}}'));

void main() {
  group('AtlasSiteServer Tests', () {
    _atlasSiteServer_should_servePageOfAVersionFolder();
    _atlasSiteServer_should_serveVersionDataAsGzipBytes();
    _atlasSiteServer_should_serveSettingsFileAsJson();
    _atlasSiteServer_should_answerNotFoundForPathOutsideTheSiteFolder();
    _atlasSiteServer_should_answerNotFoundForLinkOutOfTheSiteFolder();
    _atlasSiteServer_should_answerNotFoundForMissingFile();
    _atlasSiteServer_should_sendFolderWithoutSlashToItsPage();
    _atlasSiteServer_should_resolveAddressOfTheSitePageWithoutVersion();
    _atlasSiteServer_should_stopOnMissingSiteFolder();
  });
}

void _atlasSiteServer_should_servePageOfAVersionFolder() {
  test('AtlasSiteServer should serve page of a version folder', () async {
    await _runWithServer((server) async {
      final answer = await _get(server.resolvePageAddress(_version));

      expect(answer.status, HttpStatus.ok);
      expect(answer.contentType, 'text/html; charset=utf-8');
      expect(utf8.decode(answer.bytes), _page);
    });
  });
}

void _atlasSiteServer_should_serveVersionDataAsGzipBytes() {
  test('AtlasSiteServer should serve version data as gzip bytes', () async {
    await _runWithServer((server) async {
      final answer = await _get(
        server.resolvePageAddress(_version).resolve('./data.json.gz'),
      );

      expect(answer.status, HttpStatus.ok);
      expect(answer.contentType, 'application/gzip');
      expect(answer.contentEncoding, isNull);
      expect(answer.bytes, _data);
    });
  });
}

void _atlasSiteServer_should_serveSettingsFileAsJson() {
  test('AtlasSiteServer should serve settings file as JSON', () async {
    await _runWithServer((server) async {
      final answer = await _get(
        server.resolvePageAddress(_version).resolve('../atlas-config.json'),
      );

      expect(answer.contentType, 'application/json; charset=utf-8');
      expect(utf8.decode(answer.bytes), _config);
    });
  });
}

void _atlasSiteServer_should_answerNotFoundForPathOutsideTheSiteFolder() {
  test(
    'AtlasSiteServer should answer not found for path outside the site folder',
    () async {
      await _runWithServer((server) async {
        final outsidePath = Platform.resolvedExecutable;

        for (final path in [
          '/..%2Foutside.txt',
          '/$_version/..%2F..%2Foutside.txt',
          '/%2E%2E/outside.txt',
          '/../outside.txt',
          '/$outsidePath',
          '/${Uri.encodeComponent(outsidePath)}',
        ]) {
          final answer = await _sendRawRequest(server.address, path);

          expect(answer, startsWith('HTTP/1.1 404'), reason: path);
          expect(answer, isNot(contains(_outsideText)), reason: path);
        }
      });
    },
  );
}

void _atlasSiteServer_should_answerNotFoundForLinkOutOfTheSiteFolder() {
  test(
    'AtlasSiteServer should answer not found for link out of the site folder',
    () async {
      await _runWithServer((server) async {
        final answer = await _get(server.address.resolve(_linkName));

        expect(answer.status, HttpStatus.notFound);
        expect(utf8.decode(answer.bytes), isNot(contains(_outsideText)));
      });
    },
  );
}

void _atlasSiteServer_should_answerNotFoundForMissingFile() {
  test('AtlasSiteServer should answer not found for missing file', () async {
    await _runWithServer((server) async {
      final answer = await _get(server.address.resolve('missing/data.json.gz'));

      expect(answer.status, HttpStatus.notFound);
    });
  });
}

void _atlasSiteServer_should_sendFolderWithoutSlashToItsPage() {
  test(
    'AtlasSiteServer should send folder without slash to its page',
    () async {
      await _runWithServer((server) async {
        final answer = await _get(server.address.resolve(_version));

        expect(answer.status, HttpStatus.movedPermanently);
        expect(answer.location, '/$_version/');
      });
    },
  );
}

void _atlasSiteServer_should_resolveAddressOfTheSitePageWithoutVersion() {
  test(
    'AtlasSiteServer should resolve address of the site page without version',
    () async {
      await _runWithServer((server) async {
        final answer = await _get(server.resolvePageAddress(null));

        expect(server.address.host, InternetAddress.loopbackIPv4.address);
        expect(utf8.decode(answer.bytes), _sitePage);
      });
    },
  );
}

void _atlasSiteServer_should_stopOnMissingSiteFolder() {
  test('AtlasSiteServer should stop on missing site folder', () async {
    await expectLater(
      AtlasSiteServer.start(p.join(Directory.systemTemp.path, 'atlas-no-site')),
      throwsA(isA<AtlasException>()),
    );
  });
}

typedef _Answer = ({
  int status,
  String? contentType,
  String? contentEncoding,
  String? location,
  List<int> bytes,
});

Future<void> _runWithServer(
  Future<void> Function(AtlasSiteServer server) body,
) async {
  final directory = await Directory.systemTemp.createTemp('atlas-site-');

  final sitePath = p.join(directory.path, 'site');

  try {
    _writeFile(
      p.join(directory.path, 'outside.txt'),
      utf8.encode(_outsideText),
    );
    _writeFile(p.join(sitePath, 'index.html'), utf8.encode(_sitePage));
    _writeFile(p.join(sitePath, 'atlas-config.json'), utf8.encode(_config));
    _writeFile(p.join(sitePath, _version, 'index.html'), utf8.encode(_page));
    _writeFile(p.join(sitePath, _version, 'data.json.gz'), _data);
    Link(
      p.join(sitePath, _linkName),
    ).createSync(p.join(directory.path, 'outside.txt'));

    final server = await AtlasSiteServer.start(sitePath);

    try {
      await body(server);
    } finally {
      await server.stop();
    }
  } finally {
    await directory.delete(recursive: true);
  }
}

void _writeFile(String path, List<int> bytes) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
}

Future<_Answer> _get(Uri address) async {
  final client = HttpClient()..autoUncompress = false;

  try {
    final request = await client.getUrl(address);

    request.followRedirects = false;

    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      [],
      (all, chunk) => all..addAll(chunk),
    );

    return (
      status: response.statusCode,
      contentType: response.headers.value(HttpHeaders.contentTypeHeader),
      contentEncoding: response.headers.value(
        HttpHeaders.contentEncodingHeader,
      ),
      location: response.headers.value(HttpHeaders.locationHeader),
      bytes: bytes,
    );
  } finally {
    client.close(force: true);
  }
}

// `HttpClient` normalizes the path of a request. A socket sends the path as
// the test writes it.
Future<String> _sendRawRequest(Uri address, String path) async {
  final socket = await Socket.connect(address.host, address.port);

  try {
    socket.write(
      'GET $path HTTP/1.1\r\n'
      'Host: ${address.host}:${address.port}\r\n'
      'Connection: close\r\n'
      '\r\n',
    );

    await socket.flush();

    return await utf8.decoder.bind(socket).join();
  } finally {
    socket.destroy();
  }
}
