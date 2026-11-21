import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_capture.dart';
import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replay.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_check.dart';
import 'package:flutter_automation_atlas/src/atlas_stage_scope.dart';
import 'package:flutter_automation_atlas/src/atlas_store.dart';
import 'package:flutter_automation_atlas/src/run_atlas.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/recording_stdout.dart';
import 'test_utils/test_atlas_root.dart';
import 'test_utils/test_automation_pubspec.dart';
import 'test_utils/test_git.dart';

const _flow = 'shop_flow';
const _firstVariant = 'shopFromExistingItem';
const _secondVariant = 'shopFromSearch';
const _sourcePath = 'lib/settings/settings_view.dart';
const _recordedSource = 'class SettingsView {}';
const _changedSource = 'class SettingsView { int a = 0; }';
const _pubspecPath = 'pubspec.yaml';
const _ignoredPath = 'local.env';
const _headlessFrameHash = 'aaaaaaaaaaaa';
const _storeFolder = 'atlas_store';
const _noSourceCommit = 'not found';
const _snapshotOption = '--snapshot';
final _uk = fakeAtlasLocales.first;
final _recordedManifest = {
  _sourcePath: testSourceHash.hashSource(_recordedSource),
};

void main() {
  group('AtlasSourceCommit Tests', () {
    _atlasStore_should_readNoCommitForStoreOutsideRepository();
    _atlasHeadless_should_takeSourceCommitForCleanStoreOutsideRepository();
    _atlasStore_should_stampBothVariantsCleanInStoreInsideCleanRepository();
    _atlasStore_should_notCountStoreAndRecordingsAsChanges();
    _atlasStore_should_countChangedSourceAsDirty();
    _atlasStore_should_notCountIgnoredFileAsChange();
    _atlasHeadless_should_findCommitByGitLogWhenSnapshotIsDirty();
    _atlasHeadless_should_findCommitByGitLogWhenSnapshotHasNoSourceCommit();
    _atlasHeadless_should_takeSourceCommitWhenItIsAncestorOfHead();
    _atlasHeadless_should_findCommitAfterRebaseWithOldBranchDeleted();
    _atlasHeadless_should_findCommitInBranchRebuiltFromSameFiles();
    _atlasHeadless_should_findNoCommitWhenNoAncestorHoldsSources();
    _atlasStaleCheck_should_reportFreshWhenOnlyPubspecVersionChanged();
    _atlasRun_should_printSameCommitAsSnapshotCommitRead();
    _atlasRun_should_printNotFoundWhenNoCommitIsKnown();
  });
}

void _atlasStore_should_readNoCommitForStoreOutsideRepository() {
  test(
    'AtlasStore should read no commit for store outside repository',
    () async {
      await _runInRepo((root) {
        _initRepository(root);
        root.writeSource(_sourcePath, _recordedSource);
        _commit(root, 'add the view');
        _writeSnapshot(root, _firstVariant, sources: _recordedManifest);

        final commit = _readCommit(root, _firstVariant);

        expect(commit, isNull);
      }, isStoreOutside: true);
    },
  );
}

void _atlasHeadless_should_takeSourceCommitForCleanStoreOutsideRepository() {
  test('AtlasHeadless should take source commit for clean store outside '
      'repository', () async {
    await _runInRepo((root) {
      _initRepository(root);
      root.writeSource(_sourcePath, _recordedSource);

      final sourceCommit = _commit(root, 'add the view');

      root.writeSource(_sourcePath, _changedSource);
      _commit(root, 'change the view');
      _writeSnapshot(
        root,
        _firstVariant,
        sources: _recordedManifest,
        source: (commit: sourceCommit, isDirty: false),
      );

      final commit = _readCommit(root, _firstVariant);

      expect(commit, sourceCommit);
    }, isStoreOutside: true);
  });
}

void _atlasStore_should_stampBothVariantsCleanInStoreInsideCleanRepository() {
  test('AtlasStore should stamp both variants clean in store inside clean '
      'repository', () async {
    await _runInRepo((root) async {
      _initRepository(root);
      root.writeFlutterConfig();
      root.writeSource(_sourcePath, _recordedSource);

      final head = _commit(root, 'add the view');

      _writeFlow(root);

      await _captureBothVariants(root);

      final first = _readSnapshot(root, _firstVariant);
      final second = _readSnapshot(root, _secondVariant);

      expect(first.sourceCommit, head);
      expect(first.sourceDirty, isFalse);
      expect(second.sourceCommit, head);
      expect(second.sourceDirty, isFalse);
    });
  });
}

void _atlasStore_should_notCountStoreAndRecordingsAsChanges() {
  test('AtlasStore should not count store and recordings as changes', () async {
    await _runInRepo((root) {
      _initRepository(root);
      root.writeSource(_sourcePath, _recordedSource);
      _commit(root, 'add the view');
      _writeSnapshot(root, _firstVariant);
      root.writeSource(root.project.paths.recordings, '{}');

      final stamp = AtlasStore(root.paths).tryReadSourceStamp();

      expect(stamp?.isDirty, isFalse);
    });
  });
}

void _atlasStore_should_countChangedSourceAsDirty() {
  test('AtlasStore should count changed source as dirty', () async {
    await _runInRepo((root) {
      _initRepository(root);
      root.writeSource(_sourcePath, _recordedSource);
      _commit(root, 'add the view');
      root.writeSource(_sourcePath, _changedSource);

      final stamp = AtlasStore(root.paths).tryReadSourceStamp();

      expect(stamp?.isDirty, isTrue);
    });
  });
}

void _atlasStore_should_notCountIgnoredFileAsChange() {
  test('AtlasStore should not count ignored file as change', () async {
    await _runInRepo((root) {
      _initRepository(root);
      root.writeSource(_sourcePath, _recordedSource);
      _commit(root, 'add the view');
      root.writeSource(_ignoredPath, 'KEY=value');

      final stamp = AtlasStore(root.paths).tryReadSourceStamp();

      expect(root.project.sourceDirtyIgnores, contains(_ignoredPath));
      expect(stamp?.isDirty, isFalse);
    });
  });
}

void _atlasHeadless_should_findCommitByGitLogWhenSnapshotIsDirty() {
  test(
    'AtlasHeadless should find commit by git log when snapshot is dirty',
    () async {
      await _runInRepo((root) {
        _initRepository(root);
        root.writeSource(_sourcePath, _recordedSource);
        _commit(root, 'add the view');
        _writeSnapshot(
          root,
          _firstVariant,
          sources: _recordedManifest,
          source: (commit: _unknownCommit, isDirty: true),
        );

        final withCodeCommit = _commit(root, 'capture with the code');
        final commit = _readCommit(root, _firstVariant);

        expect(commit, withCodeCommit);
      });
    },
  );
}

void _atlasHeadless_should_findCommitByGitLogWhenSnapshotHasNoSourceCommit() {
  test(
    'AtlasHeadless should find commit by git log when snapshot has no source '
    'commit',
    () async {
      await _runInRepo((root) {
        _initRepository(root);
        root.writeSource(_sourcePath, _recordedSource);
        _commit(root, 'add the view');
        _writeSnapshot(root, _firstVariant, sources: _recordedManifest);

        final captureCommit = _commit(root, 'capture');
        final commit = _readCommit(root, _firstVariant);

        expect(commit, captureCommit);
      });
    },
  );
}

void _atlasHeadless_should_takeSourceCommitWhenItIsAncestorOfHead() {
  test(
    'AtlasHeadless should take source commit when it is ancestor of HEAD',
    () async {
      await _runInRepo((root) {
        _initRepository(root);
        root.writeSource(_sourcePath, _recordedSource);

        final sourceCommit = _commit(root, 'add the view');

        root.writeSource(_sourcePath, _changedSource);
        _commit(root, 'change the view');
        _writeSnapshot(
          root,
          _firstVariant,
          sources: _recordedManifest,
          source: (commit: sourceCommit, isDirty: false),
        );
        _commit(root, 'capture');

        final commit = _readCommit(root, _firstVariant);

        expect(commit, sourceCommit);
      });
    },
  );
}

void _atlasHeadless_should_findCommitAfterRebaseWithOldBranchDeleted() {
  test(
    'AtlasHeadless should find commit after rebase with old branch deleted',
    () async {
      await _runInRepo((root) async {
        _initRepository(root);
        _writeFlow(root);
        root.writeSource(_sourcePath, _recordedSource);

        final oldCommit = _commit(root, 'add the view');

        _writeSnapshot(
          root,
          _firstVariant,
          sources: _recordedManifest,
          source: (commit: oldCommit, isDirty: false),
          isCurrent: true,
        );
        _commit(root, 'capture');

        final rebuilt = _rebuildBranch(root, count: 2);
        final commit = _readCommit(root, _firstVariant);

        final staleness = await _check(root);

        expect(_isAncestor(root, oldCommit), isFalse);
        expect(commit, rebuilt.last);
        expect(staleness.reason, AtlasStaleReason.fresh);
      });
    },
  );
}

void _atlasHeadless_should_findCommitInBranchRebuiltFromSameFiles() {
  test(
    'AtlasHeadless should find commit in branch rebuilt from same files',
    () async {
      await _runInRepo((root) {
        _initRepository(root);
        root.writeSource(_sourcePath, _recordedSource);

        final oldCommit = _commit(root, 'add the view');

        _writeSnapshot(
          root,
          _firstVariant,
          sources: _recordedManifest,
          source: (commit: oldCommit, isDirty: false),
        );
        _commit(root, 'capture');

        final rebuilt = _rebuildBranch(root, count: 1);

        root.writeSource(_sourcePath, _changedSource);
        _commit(root, 'change the view');
        _writeSnapshot(
          root,
          _firstVariant,
          sources: _recordedManifest,
          source: (commit: oldCommit, isDirty: false),
        );
        _commit(root, 'capture again');

        final commit = _readCommit(root, _firstVariant);

        expect(commit, rebuilt.single);
      });
    },
  );
}

void _atlasHeadless_should_findNoCommitWhenNoAncestorHoldsSources() {
  test(
    'AtlasHeadless should find no commit when no ancestor holds sources',
    () async {
      await _runInRepo((root) {
        _initRepository(root);
        root.writeSource(_sourcePath, _changedSource);
        _commit(root, 'add the view');
        _writeSnapshot(
          root,
          _firstVariant,
          sources: _recordedManifest,
          source: (commit: _unknownCommit, isDirty: false),
        );
        _commit(root, 'capture');

        final commit = _readCommit(root, _firstVariant);

        expect(commit, isNull);
      });
    },
  );
}

void _atlasStaleCheck_should_reportFreshWhenOnlyPubspecVersionChanged() {
  test(
    'AtlasStaleCheck should report fresh when only pubspec version changed',
    () async {
      await _runInRepo((root) async {
        _initRepository(root);
        _writeFlow(root);
        root.writeSource(_pubspecPath, _pubspecWithVersion('1.0.0+1'));

        final sourceCommit = _commit(root, 'add the code');

        _writeSnapshot(
          root,
          _firstVariant,
          sources: {
            _pubspecPath: testSourceHash.hashSource(
              _pubspecWithVersion('1.0.0+1'),
            ),
          },
          source: (commit: sourceCommit, isDirty: false),
          isCurrent: true,
        );
        _commit(root, 'capture');
        root.writeSource(_pubspecPath, _pubspecWithVersion('1.0.1+2'));
        _commit(root, 'bump the version');

        final commit = _readCommit(root, _firstVariant);

        _writeHeadlessReports(root, baselineCommit: commit);

        final staleness = await _check(root);

        expect(commit, sourceCommit);
        expect(staleness.reason, AtlasStaleReason.fresh);
      });
    },
  );
}

void _atlasRun_should_printSameCommitAsSnapshotCommitRead() {
  test('AtlasRun should print same commit as snapshot commit read', () async {
    await _runInRepo((root) async {
      _initRepository(root);
      root.writeSource(_sourcePath, _recordedSource);

      final sourceCommit = _commit(root, 'add the view');

      _writeSnapshot(
        root,
        _firstVariant,
        sources: _recordedManifest,
        source: (commit: sourceCommit, isDirty: false),
      );
      _commit(root, 'capture');

      final lines = await RecordingStdout.captureLines(
        () => _runSourceCommit(root, _snapshotPath(root, _firstVariant)),
      );

      expect(lines, [_readCommit(root, _firstVariant)]);
      expect(lines, [sourceCommit]);
    });
  });
}

void _atlasRun_should_printNotFoundWhenNoCommitIsKnown() {
  test('AtlasRun should print not found when no commit is known', () async {
    await _runInRepo((root) async {
      _initRepository(root);
      root.writeSource(_sourcePath, _recordedSource);
      _commit(root, 'add the view');

      final lines = await RecordingStdout.captureLines(
        () => _runSourceCommit(root, _snapshotPath(root, _firstVariant)),
      );

      expect(lines, [_noSourceCommit]);
    });
  });
}

const _unknownCommit = 'decaf0000000decaf0000000decaf0000000abcd';

Future<void> _runInRepo(
  FutureOr<void> Function(TestAtlasRoot root) body, {
  bool isStoreOutside = false,
}) async {
  final directory = await Directory.systemTemp.createTemp('atlas-repo-');
  final outsideDirectory = await Directory.systemTemp.createTemp(
    'atlas-store-',
  );

  try {
    final storePath = isStoreOutside
        ? outsideDirectory.path
        : p.join(directory.path, _storeFolder);

    await body(TestAtlasRoot(directory, FakeAtlasProject(), store: storePath));
  } finally {
    await directory.delete(recursive: true);
    await outsideDirectory.delete(recursive: true);
  }
}

void _initRepository(TestAtlasRoot root) {
  initTestGit(root.paths.rootPath);
}

String _commit(TestAtlasRoot root, String message) {
  _runGit(root, ['add', '--all']);
  _runGit(root, ['commit', '--quiet', '--no-verify', '-m', message]);

  return _runGit(root, ['rev-parse', 'HEAD']);
}

// Replays the first [count] commits of the branch as new commits of an
// unrelated root and deletes the old branch, as a rebase does when the old
// commits are gone. Returns the new commits, oldest first.
List<String> _rebuildBranch(TestAtlasRoot root, {required int count}) {
  final oldHistory = _runGit(root, [
    'rev-list',
    '--reverse',
    'HEAD',
  ]).split('\n');
  final oldBranch = _runGit(root, ['rev-parse', '--abbrev-ref', 'HEAD']);
  final rebuilt = <String>[];

  _runGit(root, ['checkout', '--quiet', '--orphan', 'rebuilt']);

  for (final (index, oldCommit) in oldHistory.take(count).indexed) {
    _runGit(root, ['read-tree', '--reset', '-u', oldCommit]);
    _runGit(root, [
      'commit',
      '--quiet',
      '--no-verify',
      '--allow-empty',
      '-m',
      'rebuilt $index',
    ]);
    rebuilt.add(_runGit(root, ['rev-parse', 'HEAD']));
  }

  _runGit(root, ['branch', '--quiet', '-D', oldBranch]);

  return rebuilt;
}

bool _isAncestor(TestAtlasRoot root, String commit) {
  final result = tryRunTestGit(root.paths.rootPath, [
    'merge-base',
    '--is-ancestor',
    commit,
    'HEAD',
  ]);

  return result.exitCode == 0;
}

String _runGit(TestAtlasRoot root, List<String> arguments) {
  return runTestGit(root.paths.rootPath, arguments);
}

void _writeSnapshot(
  TestAtlasRoot root,
  String variant, {
  Map<String, String> sources = const {},
  AtlasSourceStamp? source,
  bool isCurrent = false,
}) {
  final snapshot = createAtlasSnapshot(
    flow: _flow,
    variant: variant,
    defHash: isCurrent ? _readDefHash(root, variant) : testAtlasDefHash,
    manifest: isCurrent ? sources : const {},
    stages: [
      AtlasStage(
        label: 'open the search',
        action: 'tap',
        journal: const [],
        ok: true,
        target: const {'by': 'valueKey', 'value': 'open'},
        block: null,
        targetRect: null,
        screen: null,
        designScreen: null,
        shot: 'a.png',
        error: null,
        sources: sources,
      ),
    ],
  );

  AtlasSnapshotStore(root.paths).write(
    source == null
        ? snapshot
        : snapshot.copyWithSource(
            commit: source.commit,
            isDirty: source.isDirty,
          ),
  );
}

String _pubspecWithVersion(String version) {
  return '$testAutomationPubspec\nversion: $version\n';
}

void _writeHeadlessReports(
  TestAtlasRoot root, {
  required String? baselineCommit,
}) {
  final snapshot = _readSnapshot(root, _firstVariant);
  final current = AtlasHeadlessReport(
    frameHashes: const [_headlessFrameHash],
    endFrameHash: _headlessFrameHash,
    error: null,
    journals: [const [], snapshot.stages.single.journal],
    sourceHashes: {
      for (final path in snapshot.manifest.keys)
        path: testSourceHash.tryHashFile(root.paths.resolve(path)),
    },
  );
  final baseline = AtlasHeadlessReport(
    frameHashes: const [_headlessFrameHash],
    endFrameHash: _headlessFrameHash,
    error: null,
    journals: [const [], snapshot.stages.single.journal],
    commit: baselineCommit,
  );

  for (final (isBaseline, report) in [(false, current), (true, baseline)]) {
    root.writeHeadlessReport(
      report,
      flow: _flow,
      variant: _firstVariant,
      isBaseline: isBaseline,
    );
  }
}

String _readDefHash(TestAtlasRoot root, String variant) {
  return AtlasDefinitions.read(
    root.paths,
  ).findFlow(_flow).findVariant(variant).defHash;
}

Future<AtlasStaleness> _check(TestAtlasRoot root) async {
  final variants = AtlasDefinitions.read(
    root.paths,
  ).variants.where((variant) => variant.name == _firstVariant).toList();

  final stalenesses = await AtlasStaleCheck(
    root.paths,
    _uk,
    mockReplay: const _SameMockReplay(),
    snapshotCommitReader: (snapshotPath) {
      return AtlasHeadless.tryReadSnapshotCommit(root.paths, snapshotPath);
    },
  ).check(variants);

  return stalenesses.single;
}

AtlasSnapshot _readSnapshot(TestAtlasRoot root, String variant) {
  final snapshot = AtlasSnapshotStore(
    root.paths,
  ).tryRead(flow: _flow, variant: variant, locale: _uk);

  if (snapshot == null) {
    fail('No snapshot of $variant');
  }

  return snapshot;
}

String _snapshotPath(TestAtlasRoot root, String variant) {
  return root.paths.resolveSnapshotPath(
    flow: _flow,
    variant: variant,
    locale: _uk,
  );
}

String? _readCommit(TestAtlasRoot root, String variant) {
  return AtlasHeadless.tryReadSnapshotCommit(
    root.paths,
    _snapshotPath(root, variant),
  );
}

Future<void> _runSourceCommit(TestAtlasRoot root, String snapshotPath) {
  return AtlasRun(
    ['source-commit', _snapshotOption, snapshotPath],
    root.project,
    rootPath: root.paths.rootPath,
  ).run();
}

void _writeFlow(TestAtlasRoot root) {
  root.writeFlow(_flow, {
    'variants': {
      for (final variant in [_firstVariant, _secondVariant])
        variant: {
          'items': [
            {
              'action': 'tap',
              'label': 'open the search',
              'finder': {'by': 'valueKey', 'value': 'open'},
            },
          ],
        },
    },
  });
}

Future<bool> _captureBothVariants(TestAtlasRoot root) {
  return AtlasCapture(
    root.paths,
    _uk,
    mockReplay: const _SameMockReplay(),
    headlessPass: (_) async => true,
  ).captureWalks(
    AtlasDefinitions.read(root.paths).variants,
    device: testAtlasDevice,
    walker: _FakeWalker(),
  );
}

final class _FakeWalker implements AtlasWalker {
  @override
  Future<Map<String, Object?>> walk(
    AtlasVariantDefinition variant,
    AtlasStageScope scope,
    Directory captureDirectory,
  ) async {
    return {
      'flow': variant.flow,
      'variant': variant.name,
      'ok': true,
      'steps': [
        {
          'label': 'open the search',
          'action': 'tap',
          'ok': true,
          'journal': <Object?>[],
        },
      ],
      'manifest': <String>[],
    };
  }

  @override
  Future<void> stop() => Future.value();
}

final class _SameMockReplay implements AtlasMockReplay {
  const _SameMockReplay();

  @override
  Map<String, AtlasMockReplayOutcome> replay(
    List<AtlasMockReplayInput> inputs,
  ) {
    return const {};
  }
}
