import 'dart:io';

import 'package:flutter_automation_atlas/src/atlas_shot.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_atlas_root.dart';

/// A storage on a loopback server: [upload] puts the bytes where the public
/// `GET` of [urlTemplate] reads them.
final class FakeAtlasShotStorage implements AtlasShotStorage {
  final Map<String, List<int>> files = {};
  final List<List<String>> uploads = [];
  final List<List<String>> deletions = [];
  final List<String> requestedShots = [];
  final HttpServer _server;
  final List<String> uploadFailures = [];
  final Map<String, DateTime> uploadTimes = {};
  int listCalls = 0;
  int? answeredStatus;
  bool isRedirecting = false;

  FakeAtlasShotStorage._(this._server);

  static Future<FakeAtlasShotStorage> start() async {
    final storage = FakeAtlasShotStorage._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );

    storage._server.listen(storage._answer);

    return storage;
  }

  @override
  String get urlTemplate {
    return 'http://${_server.address.host}:${_server.port}/shots/'
        '${AtlasShotStorage.shotPlaceholder}.png';
  }

  List<String> get uploadedShots => uploads.expand((shots) => shots).toList();

  @override
  Future<void> upload(List<AtlasShot> shots) async {
    if (uploadFailures.isNotEmpty) {
      throw StateError(uploadFailures.removeAt(0));
    }

    uploads.add([for (final shot in shots) shot.hash]);
    files.addAll({for (final shot in shots) shot.hash: shot.bytes});
  }

  @override
  Future<void> delete(List<String> shots) async {
    deletions.add(shots);
    shots.forEach(files.remove);
  }

  @override
  Future<List<AtlasStoredShot>> list() async {
    listCalls++;

    return [
      for (final shot in files.keys)
        AtlasStoredShot(
          shot: shot,
          uploadedAt: uploadTimes[shot] ?? DateTime.now(),
        ),
    ];
  }

  Future<void> stop() => _server.close(force: true);

  Future<void> _answer(HttpRequest request) async {
    final segment = request.uri.pathSegments.last;
    final shot = segment.substring(0, segment.length - '.png'.length);
    final bytes = files[shot];
    final response = request.response;

    if (request.uri.pathSegments.first == 'shots') {
      requestedShots.add(shot);
    }

    if (answeredStatus case final status?) {
      response.statusCode = status;
    } else if (bytes == null) {
      response.statusCode = HttpStatus.notFound;
    } else if (isRedirecting && request.uri.pathSegments.first == 'shots') {
      response.statusCode = HttpStatus.found;

      response.headers.set(HttpHeaders.locationHeader, '/files/$shot.png');
    } else {
      response.add(bytes);
    }

    await response.close();
  }
}

Future<FakeAtlasShotStorage> startFakeAtlasShotStorage(
  TestAtlasRoot root,
) async {
  final storage = await FakeAtlasShotStorage.start();

  addTearDown(storage.stop);

  root.project.storage = storage;

  return storage;
}
