import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_source_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_settings.dart';

/// {@category Utils}
///
/// Rewrites the hashes a stored snapshot holds of the raw content of its
/// manifest files into the hashes [AtlasSourceHash] takes of them.
///
/// A stored hash is rewritten only for the content it was taken of: the
/// current file when the hash is that file's raw hash, else the version of
/// the file in git history whose raw hash it is. A hash matching none of
/// them, or one already normalized, is kept, so the command runs any number
/// of times.
///
/// The command drops a path in the automation folder
/// ([AtlasStaleSettings.automationDirectory]) from the manifest and
/// from each stage when its file does not exist.
final class AtlasManifestNormalization {
  final AtlasLocations _paths;
  final Map<String, Map<String, String>> _normalizedHashesByPath = {};
  final Map<String, Map<String, String>> _historyHashesByPath = {};
  final Set<String> _unresolvedHashes = {};

  AtlasManifestNormalization(this._paths);

  /// Rewrites every stored snapshot of every locale and returns what it did.
  AtlasManifestNormalizationResult run() {
    final store = AtlasSnapshotStore(_paths);
    int rewrittenSnapshots = 0;

    for (final snapshot in store.readEveryLocale()) {
      final normalized = _normalizeSnapshot(snapshot);

      if (const DeepCollectionEquality().equals(
        normalized,
        snapshot.toJson(),
      )) {
        continue;
      }

      store.write(
        AtlasSnapshot.fromJson(normalized, fileLocale: snapshot.locale),
      );

      rewrittenSnapshots += 1;
    }

    return AtlasManifestNormalizationResult(
      rewrittenSnapshots: rewrittenSnapshots,
      unresolvedHashes: _unresolvedHashes.sorted(),
    );
  }

  Map<String, Object?> _normalizeSnapshot(AtlasSnapshot snapshot) {
    final json = snapshot.toJson();

    return {
      ...json,
      'manifest': _normalizeHashes(snapshot.manifest),
      'stages': [
        for (final stage in snapshot.stages)
          stage
              .copyWithHashes(
                stepHash: stage.stepHash,
                sources: _normalizeHashes(stage.sources),
                localeKeys: stage.localeKeys,
              )
              .toJson(),
      ],
    };
  }

  Map<String, String> _normalizeHashes(Map<String, String> hashes) {
    return {
      for (final MapEntry(key: path, value: hash) in hashes.entries)
        if (!_isGoneFromMovedModule(path)) path: _normalizeHash(path, hash),
    };
  }

  bool _isGoneFromMovedModule(String path) {
    return path.startsWith(_paths.project.staleSettings.automationDirectory) &&
        !File(_paths.resolve(path)).existsSync();
  }

  String _normalizeHash(String path, String hash) {
    return _normalizedHashesByPath
        .putIfAbsent(path, () => {})
        .putIfAbsent(hash, () => _resolveNormalizedHash(path, hash));
  }

  String _resolveNormalizedHash(String path, String hash) {
    final resolvedPath = _paths.resolve(path);

    if (_isHashOfCurrentFile(resolvedPath, hash)) {
      return _paths.sourceHash.tryHashFile(resolvedPath) ?? hash;
    }

    final historyHash = _readHistoryHashes(path)[hash];

    if (historyHash == null && !_isNormalized(path, hash)) {
      _unresolvedHashes.add('$path $hash');
    }

    return historyHash ?? hash;
  }

  bool _isHashOfCurrentFile(String resolvedPath, String hash) {
    return AtlasContentHash.tryHashFile(resolvedPath) == hash;
  }

  bool _isNormalized(String path, String hash) {
    return _paths.sourceHash.tryHashFile(_paths.resolve(path)) == hash ||
        _readHistoryHashes(path).containsValue(hash);
  }

  Map<String, String> _readHistoryHashes(String path) {
    return _historyHashesByPath.putIfAbsent(path, () {
      final revisions = utf8.decode(
        _runGit(['log', '--format=%H', '--', path]),
      );

      return {
        for (final revision in revisions.split('\n').where(_isNotEmpty))
          ...?_tryHashRevision(revision, path),
      };
    });
  }

  bool _isNotEmpty(String text) => text.isNotEmpty;

  Map<String, String>? _tryHashRevision(String revision, String path) {
    final bytes = _runGit(['show', '$revision:$path']);

    if (bytes.isEmpty) {
      return null;
    }

    return {
      AtlasContentHash.hashBytes(bytes): _paths.sourceHash.hashSource(
        utf8.decode(bytes, allowMalformed: true),
      ),
    };
  }

  List<int> _runGit(List<String> args) {
    final result = Process.runSync(
      'git',
      args,
      workingDirectory: _paths.rootPath,
      stdoutEncoding: null,
    );
    final stdout = result.stdout;

    return result.exitCode == 0 && stdout is List<int> ? stdout : const [];
  }
}

/// {@category Utils}
///
/// What [AtlasManifestNormalization.run] rewrote.
final class AtlasManifestNormalizationResult {
  /// How many snapshot files were written.
  final int rewrittenSnapshots;

  /// The stored hashes neither the current file nor any version in git
  /// history was raw-hashed to, as `<path> <hash>`.
  final List<String> unresolvedHashes;

  const AtlasManifestNormalizationResult({
    required this.rewrittenSnapshots,
    required this.unresolvedHashes,
  });
}
