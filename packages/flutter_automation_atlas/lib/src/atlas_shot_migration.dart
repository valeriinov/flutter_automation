import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_remote_shots.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_id.dart';

/// {@category Utils}
///
/// What [AtlasShotMigration.run] changed.
typedef AtlasShotMigrationResult = ({
  int renamedShots,
  int rewrittenSnapshots,
  int storedShots,
});

/// {@category Utils}
///
/// Gives each screenshot of the shots folder of the store its [AtlasShotId].
///
/// In each snapshot of the store, it rewrites only the `shot` fields of the
/// stages and of the end that name a file of the folder; each other byte of
/// the snapshot stays. It then renames each file of the folder to the
/// identifier of its bytes. Each file first takes a temporary name, so that
/// no rename replaces a file that still has another name to take. A run that
/// stopped continues with the next run. A second run changes nothing.
///
/// With a remote shot storage, it then puts the files of the folder into the
/// storage. It asks the storage for each identifier that the snapshots name.
final class AtlasShotMigration {
  static const _jsonExtension = '.json';
  static const _pngExtension = '.png';
  static const _movedExtension = '.moved';
  static const _shotKey = 'shot';

  final AtlasLocations _paths;

  const AtlasShotMigration(this._paths);

  /// Migrates the store and returns the counts of what changed.
  ///
  /// Throws an [AtlasException] before it changes a file when a snapshot
  /// names a screenshot that is no identifier and has no file. It throws
  /// also when the storage does not hold an identifier after the upload.
  Future<AtlasShotMigrationResult> run() async {
    _placeMovedShots();

    final shotFiles = _listFiles(_paths.storeShotsPath, _pngExtension);
    final identifiers = {
      for (final file in shotFiles)
        p.basenameWithoutExtension(file.path): AtlasShotId.hashBytes(
          file.readAsBytesSync(),
        ),
    };
    final snapshotFiles = _listFiles(_paths.dataPath, _jsonExtension);
    final namedShots = {for (final file in snapshotFiles) ..._readShots(file)};

    _failOnUnknownShots(namedShots, identifiers);

    final rewrittenSnapshots = snapshotFiles
        .where(
          (file) => _rewrite(file, {
            for (final shot in namedShots.whereNot(AtlasShotId.isValid))
              shot: ?identifiers[shot],
          }),
        )
        .toList();
    final renamedShots = shotFiles
        .where((file) => _move(file, identifiers))
        .toList();

    _placeMovedShots();

    final storedShots = await _store(
      identifiers.values.toSet(),
      namedShots.map((shot) => identifiers[shot] ?? shot).toSet(),
    );

    return (
      renamedShots: renamedShots.length,
      rewrittenSnapshots: rewrittenSnapshots.length,
      storedShots: storedShots,
    );
  }

  List<File> _listFiles(String path, String extension) {
    final directory = Directory(path);

    if (!directory.existsSync()) {
      return const [];
    }

    return directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => p.extension(file.path) == extension)
        .toList()
      ..sort((first, second) => first.path.compareTo(second.path));
  }

  Set<String> _readShots(File snapshot) {
    final json = AtlasJson.decodeObject(
      snapshot.readAsStringSync(),
      'The snapshot ${snapshot.path}',
    );

    return {
      for (final stage in AtlasJson.readObjects(json, 'stages'))
        ?AtlasJson.tryReadString(stage, _shotKey),
      if (json['end'] case final Map<String, Object?> end)
        ?AtlasJson.tryReadString(end, _shotKey),
    };
  }

  void _failOnUnknownShots(
    Set<String> namedShots,
    Map<String, String> identifiers,
  ) {
    final unknown = namedShots
        .where(
          (shot) =>
              !identifiers.containsKey(shot) && !AtlasShotId.isValid(shot),
        )
        .toList();

    if (unknown.isNotEmpty) {
      throw AtlasException(
        'The snapshots name the shots ${unknown.join(', ')}, which have no '
        'file in ${_paths.storeShotsPath}; nothing is migrated.',
      );
    }
  }

  bool _move(File file, Map<String, String> identifiers) {
    final name = p.basenameWithoutExtension(file.path);
    final identifier = identifiers[name];

    if (identifier == null || identifier == name) {
      return false;
    }

    file.renameSync(
      '${_paths.resolveStoreShotPath(identifier)}$_movedExtension',
    );

    return true;
  }

  void _placeMovedShots() {
    for (final file in _listFiles(_paths.storeShotsPath, _movedExtension)) {
      file.renameSync(
        file.path.substring(0, file.path.length - _movedExtension.length),
      );
    }
  }

  bool _rewrite(File snapshot, Map<String, String> identifiers) {
    final text = snapshot.readAsStringSync();
    final rewritten = text.replaceAllMapped(
      RegExp('"$_shotKey"(\\s*:\\s*)("[^"]*")'),
      (match) {
        final identifier = identifiers[jsonDecode('${match[2]}')];

        return identifier == null
            ? '${match[0]}'
            : '"$_shotKey"${match[1]}"$identifier"';
      },
    );

    if (rewritten == text) {
      return false;
    }

    snapshot.writeAsStringSync(rewritten);

    return true;
  }

  Future<int> _store(Set<String> storeShots, Set<String> namedShots) async {
    final remoteShots = AtlasRemoteShots.tryCreate(_paths);

    if (remoteShots == null) {
      return 0;
    }

    await remoteShots.upload({
      for (final shot in storeShots) shot: _paths.resolveStoreShotPath(shot),
    });

    final absent = await remoteShots.findAbsent(namedShots);

    if (absent.isNotEmpty) {
      throw AtlasException(
        'The shot storage holds no ${absent.join(', ')} after the upload.',
      );
    }

    return storeShots.length;
  }
}
