import 'dart:io';

import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_automation_atlas/src/atlas_project.dart';

/// {@category Utils}
///
/// What a capture records about the code tree it ran on: the commit, and
/// whether the tree held changes the commit does not.
typedef AtlasSourceStamp = ({String commit, bool isDirty});

/// {@category Utils}
///
/// Reads the git state of the code tree under the root of [AtlasLocations].
///
/// The atlas keeps its files in the store folder, which may lie inside the
/// code repository or outside it. The tree counts as dirty when `git status`
/// lists a change outside the store folder, the QA recordings and
/// [AtlasProject.sourceDirtyIgnores].
final class AtlasStore {
  static const _excludeMagic = ':(exclude)';

  final AtlasLocations _locations;

  const AtlasStore(this._locations);

  /// The commit of the code tree and its dirty flag, read once before a
  /// capture starts; absent when the root is no git tree or has no commit.
  AtlasSourceStamp? tryReadSourceStamp() {
    final commit = _tryRunGit(['rev-parse', 'HEAD']);

    if (commit == null) {
      return null;
    }

    final status = _tryRunGit([
      'status',
      '--porcelain',
      '--',
      '.',
      ..._listExcludedPathspecs(),
    ]);

    return (commit: commit, isDirty: status == null || status.isNotEmpty);
  }

  List<String> _listExcludedPathspecs() {
    final paths = _locations.project.sourceDirtyIgnores;
    final recordings = _locations.project.paths.recordings;
    final store = _locations.storePath;
    final root = p.absolute(_locations.rootPath);

    return [
      for (final path in [
        if (p.isWithin(root, store)) p.relative(store, from: root),
        recordings,
        ...paths,
      ])
        '$_excludeMagic$path',
    ];
  }

  String? _tryRunGit(List<String> arguments) {
    final result = Process.runSync(
      'git',
      arguments,
      workingDirectory: _locations.rootPath,
    );

    return result.exitCode == 0 ? '${result.stdout}'.trim() : null;
  }
}
