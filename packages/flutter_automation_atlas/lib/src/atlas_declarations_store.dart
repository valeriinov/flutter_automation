import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_declarations.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';

/// {@category Utils}
///
/// Writes the declarations [AtlasDeclarations.read] finds in a manifest
/// file into the declarations directory, one record per file content, named
/// by its source hash.
///
/// Every variant whose manifest names the same content shares its record, and
/// a record, once written, never changes. A record carries the format of
/// [AtlasDeclarations] it was read in; one of another format counts as
/// absent and is written anew.
final class AtlasDeclarationsStore {
  static const _jsonExtension = '.json';
  static const _formatKey = 'format';
  static const _format = 'members';
  static const _declarationsKey = 'declarations';
  static const _keyKey = 'key';
  static const _hashKey = 'hash';

  final AtlasLocations _paths;

  const AtlasDeclarationsStore(this._paths);

  /// Writes the record of the Dart [source] whose source hash is [sourceHash],
  /// unless one is already written.
  void maybeWrite({required String sourceHash, required String source}) {
    final file = File(_paths.resolveDeclarationsPath(sourceHash));

    if (_tryReadRecord(file) != null) {
      return;
    }

    final record = _encodeDeclarations(_paths.readDeclarations(source));

    file
      ..createSync(recursive: true)
      ..writeAsStringSync('${jsonEncode(record)}\n');
  }

  /// The declaration hashes of the record whose source hash is [sourceHash]
  /// by [AtlasDeclaration.key], `null` when no record of the current
  /// format is written.
  Map<String, String>? tryReadHashes(String sourceHash) {
    final record = _tryReadRecord(
      File(_paths.resolveDeclarationsPath(sourceHash)),
    );

    if (record == null) {
      return null;
    }

    return {
      for (final declaration in AtlasJson.readObjects(record, _declarationsKey))
        AtlasJson.readString(declaration, _keyKey): AtlasJson.readString(
          declaration,
          _hashKey,
        ),
    };
  }

  /// Deletes every record whose source hash is not in [referencedHashes] and
  /// returns the file names deleted.
  List<String> deleteUnreferenced(Set<String> referencedHashes) {
    final directory = Directory(_paths.declarationsPath);

    if (!directory.existsSync()) {
      return const [];
    }

    final unreferencedFiles = directory
        .listSync()
        .whereType<File>()
        .where((file) => p.extension(file.path) == _jsonExtension)
        .where(
          (file) =>
              !referencedHashes.contains(p.basenameWithoutExtension(file.path)),
        )
        .toList();

    for (final file in unreferencedFiles) {
      file.deleteSync();
    }

    return unreferencedFiles.map((file) => p.basename(file.path)).sorted();
  }

  Map<String, Object?> _encodeDeclarations(AtlasDeclarations declarations) {
    return {
      _formatKey: _format,
      _declarationsKey: declarations.declarations
          .map(_encodeDeclaration)
          .toList(),
    };
  }

  Map<String, Object?>? _tryReadRecord(File file) {
    if (!file.existsSync()) {
      return null;
    }

    final record = AtlasJson.readObject(
      jsonDecode(file.readAsStringSync()),
      file.path,
    );

    return AtlasJson.tryReadString(record, _formatKey) == _format
        ? record
        : null;
  }

  Map<String, Object?> _encodeDeclaration(AtlasDeclaration declaration) {
    return {_keyKey: declaration.key, _hashKey: declaration.hash};
  }
}
