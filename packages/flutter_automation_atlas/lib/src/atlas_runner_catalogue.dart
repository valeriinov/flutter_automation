import 'dart:io';

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';

/// {@category Utils}
///
/// Every flow and every block of the automation runner, as the decoded JSON
/// objects its `--catalogue` command prints, before a `Use` expands.
///
/// The runner compiles the flows of the project. A process reads the catalogue
/// of one root once. A second read of the same root takes the first answer.
final class AtlasRunnerCatalogue {
  static final _byRoot = <String, AtlasRunnerCatalogue>{};

  static const _flowsKey = 'flows';
  static const _blocksKey = 'blocks';
  static const _errorKey = 'error';

  /// Flow objects by flow name.
  final Map<String, Object?> flows;

  /// Block objects by block name.
  final Map<String, Object?> blocks;

  const AtlasRunnerCatalogue({required this.flows, required this.blocks});

  /// The catalogue of the runner of the project under the root of [paths].
  factory AtlasRunnerCatalogue.read(AtlasLocations paths) {
    return _byRoot[paths.rootPath] ??= _run(paths);
  }

  /// Decodes the [text] the runner printed for `--catalogue`.
  ///
  /// Throws a [AtlasException] when the text is the error line of the
  /// runner or holds no flows or no blocks object.
  factory AtlasRunnerCatalogue.decode(String text) {
    final json = AtlasJson.decodeObject(text, 'The runner catalogue');
    final error = json[_errorKey];

    if (error != null) {
      throw AtlasException('The runner failed: $error');
    }

    return AtlasRunnerCatalogue(
      flows: AtlasJson.readObject(
        json[_flowsKey],
        'The flows of the runner catalogue',
      ),
      blocks: AtlasJson.readObject(
        json[_blocksKey],
        'The blocks of the runner catalogue',
      ),
    );
  }

  /// Makes the reads of the root [rootPath] answer with [catalogue], so a test
  /// holds the flows in memory and starts no runner.
  static void seed(String rootPath, AtlasRunnerCatalogue catalogue) {
    _byRoot[rootPath] = catalogue;
  }

  static AtlasRunnerCatalogue _run(AtlasLocations paths) {
    final dart = paths.project.launch.resolveCommand('dart');
    final result = Process.runSync(dart.executable, [
      ...dart.arguments,
      'run',
      paths.runnerEntryPath,
      '--catalogue',
    ], workingDirectory: paths.rootPath);
    final lines = (result.stdout as String).trimRight().split('\n');

    if (result.exitCode != 0) {
      throw AtlasException(
        'The runner exited with ${result.exitCode}: ${result.stderr}',
      );
    }

    return AtlasRunnerCatalogue.decode(lines.last);
  }
}
