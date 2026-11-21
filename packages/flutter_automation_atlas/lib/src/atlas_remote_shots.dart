import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_shot.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_id.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_storage.dart';

/// {@category Utils}
///
/// Moves screenshots between the remote storage of a project and the cache
/// folder ([AtlasLocations.shotsCachePath]).
///
/// It reads a screenshot and asks whether the storage holds it with a public
/// `GET` of the link that [AtlasShotStorage.urlTemplate] gives. An answer
/// with a 2xx or 3xx code means the storage holds the file. The code `404`
/// means it does not. Each other code stops the command with an
/// [AtlasException]. So does each failure of the request or of the adapter.
///
/// A file that it reads or puts must hold the bytes that its identifier
/// names. Other bytes stop the command.
///
/// One instance serves one command. It remembers each screenshot that the
/// storage confirmed, by an upload or a download, and [uploadUnconfirmed]
/// leaves these out.
final class AtlasRemoteShots {
  static const _pngType = 'image/png';
  static const _presenceBatchSize = 8;
  static const _firstPresentStatus = 200;
  static const _firstFailureStatus = 400;
  static const _connectionTimeout = Duration(seconds: 30);
  static const _partialExtension = '.part';

  final AtlasLocations _paths;
  final AtlasShotStorage _storage;
  final Set<String> _confirmedShots = {};

  AtlasRemoteShots(this._paths, this._storage);

  /// The remote shots of the project of [paths], or `null` when the store
  /// folder keeps the screenshots.
  static AtlasRemoteShots? tryCreate(AtlasLocations paths) {
    final storage = paths.project.shotStorage;

    return storage == null ? null : AtlasRemoteShots(paths, storage);
  }

  /// The link template of the storage.
  ///
  /// Throws an [AtlasException] when the template holds no
  /// [AtlasShotStorage.shotPlaceholder].
  String get urlTemplate {
    final template = _readUrlTemplate();

    if (!template.contains(AtlasShotStorage.shotPlaceholder)) {
      throw AtlasException(
        'The link template of the shot storage, $template, holds no '
        '${AtlasShotStorage.shotPlaceholder}.',
      );
    }

    return template;
  }

  /// Reads the screenshot [shot] from the storage into the cache folder and
  /// answers whether the storage holds it.
  Future<bool> tryDownload(String shot) async {
    final client = _createClient();

    try {
      return await _tryDownload(client, shot);
    } finally {
      client.close(force: true);
    }
  }

  /// Reads into the cache folder each of [shots] that the folder does not
  /// hold.
  ///
  /// Throws an [AtlasException] naming the screenshots that the storage does
  /// not hold.
  Future<void> ensureCached(Iterable<String> shots) async {
    final uncached = shots
        .where((shot) => !File(_paths.resolveShotPath(shot)).existsSync())
        .toList();
    final client = _createClient();
    final absent = <String>[];

    try {
      for (final batch in uncached.slices(_presenceBatchSize)) {
        final downloads = await Future.wait([
          for (final shot in batch) _tryDownload(client, shot),
        ]);

        absent.addAll([
          for (final (index, shot) in batch.indexed)
            if (!downloads[index]) shot,
        ]);
      }
    } finally {
      client.close(force: true);
    }

    if (absent.isNotEmpty) {
      throw AtlasException(
        'The shot storage holds no ${absent.join(', ')}; capture the '
        'variants again or run `upload-shots`.',
      );
    }
  }

  /// The ones of [shots] that the storage does not hold, asked
  /// [_presenceBatchSize] at a time.
  Future<List<String>> findAbsent(Iterable<String> shots) async {
    final client = _createClient();
    final absent = <String>[];

    try {
      for (final batch in shots.toSet().slices(_presenceBatchSize)) {
        final presences = await Future.wait([
          for (final shot in batch) _isPresent(client, shot),
        ]);

        absent.addAll([
          for (final (index, shot) in batch.indexed)
            if (!presences[index]) shot,
        ]);
      }
    } finally {
      client.close(force: true);
    }

    return absent;
  }

  /// Puts into the storage each of [shots] whose file the cache folder holds
  /// and that the storage did not confirm in this command.
  Future<void> uploadUnconfirmed(Iterable<String> shots) {
    return upload({
      for (final shot in shots.toSet())
        if (!_confirmedShots.contains(shot)) shot: _paths.resolveShotPath(shot),
    });
  }

  /// Puts into the storage the screenshot files of [pathsByShot], each a
  /// file path by its identifier. It leaves out a path that names no file.
  ///
  /// Throws an [AtlasException] before the upload when a file does not hold
  /// the bytes that its identifier names.
  Future<void> upload(Map<String, String> pathsByShot) async {
    final shots = [
      for (final MapEntry(key: shot, value: path) in pathsByShot.entries)
        if (File(path).existsSync())
          AtlasShot(
            hash: shot,
            bytes: File(path).readAsBytesSync(),
            type: _pngType,
          ),
    ];
    final damaged = shots
        .where((shot) => AtlasShotId.hashBytes(shot.bytes) != shot.hash)
        .map((shot) => pathsByShot[shot.hash])
        .toList();

    if (damaged.isNotEmpty) {
      throw AtlasException(
        'The files ${damaged.join(', ')} do not hold the bytes that their '
        'names give; nothing is uploaded.',
      );
    }

    if (shots.isEmpty) {
      return;
    }

    await _guardStorage(() => _storage.upload(shots));

    _confirmedShots.addAll(shots.map((shot) => shot.hash));
  }

  /// Removes the screenshots [shots] name from the storage.
  Future<void> delete(List<String> shots) async {
    if (shots.isEmpty) {
      return;
    }

    await _guardStorage(() => _storage.delete(shots));

    _confirmedShots.removeAll(shots);
  }

  Future<bool> _tryDownload(HttpClient client, String shot) async {
    final bytes = await _guardRequest(shot, (uri) async {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await _readBody(response);

      return _isHeld(response.statusCode, uri) ? body : null;
    });

    if (bytes == null) {
      return false;
    }

    if (AtlasShotId.hashBytes(bytes) != shot) {
      throw AtlasException(
        'The shot storage answered for $shot with other bytes than the '
        'identifier names.',
      );
    }

    final path = _paths.resolveShotPath(shot);

    File('$path$_partialExtension')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes)
      ..renameSync(path);

    _confirmedShots.add(shot);

    return true;
  }

  Future<bool> _isPresent(HttpClient client, String shot) {
    return _guardRequest(shot, (uri) async {
      final request = await client.getUrl(uri);

      request.followRedirects = false;

      final response = await request.close();

      await response.drain<void>();

      return _isHeld(response.statusCode, uri);
    });
  }

  bool _isHeld(int status, Uri uri) {
    if (status == HttpStatus.notFound) {
      return false;
    }

    if (status < _firstPresentStatus || status >= _firstFailureStatus) {
      throw AtlasException('The shot storage answered $status for $uri.');
    }

    return true;
  }

  Future<Uint8List> _readBody(HttpClientResponse response) async {
    final builder = BytesBuilder(copy: false);

    await response.forEach(builder.add);

    return builder.takeBytes();
  }

  Future<T> _guardRequest<T>(
    String shot,
    Future<T> Function(Uri uri) request,
  ) async {
    final link = urlTemplate.replaceAll(AtlasShotStorage.shotPlaceholder, shot);

    try {
      return await request(Uri.parse(link));
    } on AtlasException {
      rethrow;
    } on Object catch (error) {
      throw AtlasException('The shot storage did not answer for $link: $error');
    }
  }

  HttpClient _createClient() {
    return HttpClient()..connectionTimeout = _connectionTimeout;
  }

  Future<void> _guardStorage(Future<void> Function() call) async {
    try {
      await call();
    } on AtlasException {
      rethrow;
    } on Object catch (error) {
      throw AtlasException('The shot storage failed: $error');
    }
  }

  String _readUrlTemplate() {
    try {
      return _storage.urlTemplate;
    } on AtlasException {
      rethrow;
    } on Object catch (error) {
      throw AtlasException('The shot storage failed: $error');
    }
  }
}
