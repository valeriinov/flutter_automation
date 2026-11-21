import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_page_renderer.dart';
import 'package:flutter_automation_atlas/src/atlas_prune.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_versions.dart';

import 'test_utils/create_shot_snapshot.dart';
import 'test_utils/fake_atlas_shot_storage.dart';
import 'test_utils/test_atlas_root.dart';
import 'test_utils/test_git.dart';

const _storeShot =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _prodShot =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _branchShot =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _pageShot =
    '4444444444444444444444444444444444444444444444444444444444444444';
const _versionShot =
    '5555555555555555555555555555555555555555555555555555555555555555';
const _youngShot =
    '6666666666666666666666666666666666666666666666666666666666666666';
const _strandedShot =
    '432f17ef04f7432f17ef04f7432f17ef04f7432f17ef04f7432f17ef04f7432f';
const _shortShot = '0123456789ab';
const _shotBytes = [1, 2, 3];
const _oldAge = Duration(days: 8);
const _youngAge = Duration(days: 6);
const _firstLabel = 'v1';
const _secondLabel = 'v2';
const _firstPosition = 10;
const _secondPosition = 20;
const _thirdLabel = 'v3';
const _thirdPosition = 30;
const _firstTag = 'test-v1';
const _secondTag = 'test-v2';
const _unpublishedTag = 'test-v9';
const _sitePath = 'site/test';
const _liteSitePath = 'site/lite';
const _refusedLabelPosition = 1;
const _retention = {'keptVersions': 1, 'versionTagTemplate': 'test-{version}'};
const _untaggedRetention = {'keptVersions': 5};

void main() {
  group('AtlasPrune Tests', () {
    _atlasPrune_should_deleteNothingWhenTheFetchFails();
    _atlasPrune_should_stopOnEmptyNeededSet();
    _atlasPrune_should_keepShotOfAnOpenPullRequest();
    _atlasPrune_should_keepShotOfAnotherStoreFolder();
    _atlasPrune_should_keepShotOfASitePageOnTheMainBranch();
    _atlasPrune_should_keepShotThatOnlyVersionDataNames();
    _atlasPrune_should_keepUnnamedShotYoungerThanSevenDays();
    _atlasPrune_should_deleteStrandedShotOnlyWithApply();
    _atlasPrune_should_deleteVersionFoldersPastTheRetentionOnlyWithApply();
    _atlasPrune_should_deleteTagOnlyAfterTheFolderLeavesTheMainBranch();
    _atlasPrune_should_keepToThePartOfItsScope();
    _atlasPrune_should_skipStoragePartWithoutShotStorage();
    _atlasPrune_should_refuseSiteFolderOutsideTheRepository();
    _atlasPrune_should_stopOnMalformedRetention();
    _atlasPrune_should_deleteNothingOnVersionRowWhoseLabelIsNoFolderName();
    _atlasPrune_should_deleteTagThatOriginLostWithoutAPush();
    _atlasPrune_should_keepVersionFolderWhenOriginRefusesTheTagDeletion();
    _atlasPrune_should_keepShotOfABranchOutsideTheRefspecOfTheClone();
    _atlasPrune_should_stopWithoutTheMainBranchAndWithoutASiteFolder();
    _atlasPrune_should_keepTagOfAVersionThatAnotherSiteHolds();
    _atlasPrune_should_keepTagOfAVersionThatASiteOutsideTheRunHolds();
    _atlasPrune_should_reportOverALocalTagThatOriginHoldsElsewhere();
    _atlasPrune_should_deleteTagOfTwoSitesOnce();
  });
}

void _atlasPrune_should_deleteNothingWhenTheFetchFails() {
  test('AtlasPrune should delete nothing when the fetch fails', () async {
    await _runInRepository((root, storage) async {
      _publishVersions(root);
      runTestGit(root.directory.path, [
        'remote',
        'set-url',
        'origin',
        p.join(root.directory.path, 'no-origin'),
      ]);

      await expectLater(
        AtlasPrune(root.paths).run(isApplied: true),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('fetch'),
          ),
        ),
      );

      expect(storage.deletions, isEmpty);
      expect(storage.listCalls, 0);
      expect(_hasVersionFolder(root, _firstLabel), isTrue);
    });
  });
}

void _atlasPrune_should_stopOnEmptyNeededSet() {
  test('AtlasPrune should stop on empty needed set', () async {
    await _runInRepository(storeShot: _shortShot, (root, storage) async {
      await expectLater(
        AtlasPrune(root.paths).run(isApplied: true),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('needed set'),
          ),
        ),
      );

      expect(storage.deletions, isEmpty);
    });
  });
}

void _atlasPrune_should_keepShotOfAnOpenPullRequest() {
  test('AtlasPrune should keep shot of an open pull request', () async {
    await _runInRepository((root, storage) async {
      final path = root.directory.path;
      final branchSnapshot = p.join(root.paths.dataPath, 'branch.uk.json');

      runTestGit(path, ['checkout', '--quiet', '-b', 'capture']);
      _writeSnapshot(root, branchSnapshot, _branchShot);
      commitTestGit(path, 'capture');
      pushTestGit(path, 'capture');
      runTestGit(path, ['checkout', '--quiet', 'main']);
      expect(File(branchSnapshot).existsSync(), isFalse);

      await _expectOnlyStrandedShotDeleted(root, storage, kept: _branchShot);
    });
  });
}

void _atlasPrune_should_keepShotOfAnotherStoreFolder() {
  test('AtlasPrune should keep shot of another store folder', () async {
    await _runInRepository((root, storage) async {
      _writeSnapshot(
        root,
        p.join(root.directory.path, 'prod/data/shop_flow/a.uk.json'),
        _prodShot,
      );

      await _expectOnlyStrandedShotDeleted(root, storage, kept: _prodShot);
    });
  });
}

void _atlasPrune_should_keepShotOfASitePageOnTheMainBranch() {
  test(
    'AtlasPrune should keep shot of a site page on the main branch',
    () async {
      await _runInRepository((root, storage) async {
        final path = root.directory.path;
        final page = p.join(path, _sitePath, 'index.html');

        root.writeText(
          page,
          '<script type="application/json" id="atlas-shots">'
          '{"shotUrls":{"$_shortShot":"https://shots.example/$_pageShot.png"}}'
          '</script>',
        );
        commitTestGit(path, 'page');
        pushTestGit(path, 'main');
        File(page).deleteSync();

        await _expectOnlyStrandedShotDeleted(root, storage, kept: _pageShot);
      });
    },
  );
}

void _atlasPrune_should_keepShotThatOnlyVersionDataNames() {
  test('AtlasPrune should keep shot that only version data names', () async {
    await _runInRepository((root, storage) async {
      File(
          p.join(
            root.directory.path,
            _sitePath,
            _firstLabel,
            AtlasVersions.dataFileName,
          ),
        )
        ..createSync(recursive: true)
        ..writeAsBytesSync(_encodeVersionData(_versionShot));

      await _expectOnlyStrandedShotDeleted(root, storage, kept: _versionShot);
    });
  });
}

void _atlasPrune_should_keepUnnamedShotYoungerThanSevenDays() {
  test('AtlasPrune should keep unnamed shot younger than seven days', () async {
    await _runInRepository((root, storage) async {
      await _expectOnlyStrandedShotDeleted(
        root,
        storage,
        kept: _youngShot,
        keptAge: _youngAge,
      );
    });
  });
}

void _atlasPrune_should_deleteStrandedShotOnlyWithApply() {
  test('AtlasPrune should delete stranded shot only with apply', () async {
    await _runInRepository((root, storage) async {
      final report = await AtlasPrune(root.paths).run();

      expect(report.shots, [_strandedShot]);
      expect(report.isApplied, isFalse);
      expect(report.describe().first, contains(_strandedShot));
      expect(storage.deletions, isEmpty);

      await AtlasPrune(root.paths).run(isApplied: true);

      expect(storage.deletions, [
        [_strandedShot],
      ]);
    });
  });
}

void _atlasPrune_should_deleteVersionFoldersPastTheRetentionOnlyWithApply() {
  test('AtlasPrune should delete version folders past the retention only '
      'with apply', () async {
    await _runInRepository((root, storage) async {
      _publishVersions(root);

      final report = await AtlasPrune(
        root.paths,
      ).run(scope: AtlasPruneScope.repository);

      expect(report.versionFolders.map(p.basename), [_firstLabel]);
      expect(_hasVersionFolder(root, _firstLabel), isTrue);

      await AtlasPrune(
        root.paths,
      ).run(scope: AtlasPruneScope.repository, isApplied: true);

      expect(_hasVersionFolder(root, _firstLabel), isFalse);
      expect(_hasVersionFolder(root, _secondLabel), isTrue);
      expect(_readVersionLabels(root), [_secondLabel]);
    });
  });
}

void _atlasPrune_should_deleteTagOnlyAfterTheFolderLeavesTheMainBranch() {
  test('AtlasPrune should delete tag only after the folder leaves the main '
      'branch', () async {
    await _runInRepository((root, storage) async {
      final path = root.directory.path;
      final prune = AtlasPrune(root.paths, sites: [p.join(path, _sitePath)]);

      _publishVersions(root);
      commitTestGit(path, 'versions');
      pushTestGit(path, 'main');

      for (final tag in [_firstTag, _secondTag, _unpublishedTag]) {
        runTestGit(path, ['tag', tag]);
        pushTestGit(path, tag);
      }

      await prune.run(scope: AtlasPruneScope.repository, isApplied: true);

      final keptReport = await prune.run(
        scope: AtlasPruneScope.repository,
        isApplied: true,
      );

      expect(_hasVersionFolder(root, _firstLabel), isFalse);
      expect(keptReport.tags, isEmpty);
      expect(_readOriginTags(path), contains(_firstTag));
      commitTestGit(path, 'retention');
      pushTestGit(path, 'main');

      final report = await prune.run(
        scope: AtlasPruneScope.repository,
        isApplied: true,
      );

      expect(report.tags, [_firstTag]);
      expect(_readOriginTags(path), isNot(contains(_firstTag)));
      expect(
        _readOriginTags(path),
        allOf(contains(_secondTag), contains(_unpublishedTag)),
      );
      expect(
        runTestGit(path, ['tag', '--list']),
        '$_secondTag\n$_unpublishedTag',
      );
    });
  });
}

void _atlasPrune_should_keepToThePartOfItsScope() {
  test('AtlasPrune should keep to the part of its scope', () async {
    await _runInRepository((root, storage) async {
      _publishVersions(root);

      final report = await AtlasPrune(
        root.paths,
      ).run(scope: AtlasPruneScope.storage, isApplied: true);

      expect(report.versionFolders, isEmpty);
      expect(_hasVersionFolder(root, _firstLabel), isTrue);
      expect(storage.deletions, [
        [_strandedShot],
      ]);
    });
  });
}

void _atlasPrune_should_skipStoragePartWithoutShotStorage() {
  test('AtlasPrune should skip storage part without shot storage', () async {
    await _runInRepository((root, storage) async {
      root.project.storage = null;

      final report = await AtlasPrune(root.paths).run(isApplied: true);

      expect(report.isStorageSkipped, isTrue);
      expect(report.shots, isEmpty);
      expect(storage.listCalls, 0);
      expect(storage.deletions, isEmpty);
    });
  });
}

void _atlasPrune_should_refuseSiteFolderOutsideTheRepository() {
  test('AtlasPrune should refuse site folder outside the repository', () async {
    await _runInRepository((root, storage) async {
      final outside = await Directory.systemTemp.createTemp('atlas-outside-');

      addTearDown(() => outside.delete(recursive: true));

      await expectLater(
        AtlasPrune(root.paths, sites: [outside.path]).run(isApplied: true),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('outside the repository'),
          ),
        ),
      );

      expect(storage.deletions, isEmpty);
    });
  });
}

void _atlasPrune_should_stopOnMalformedRetention() {
  test('AtlasPrune should stop on malformed retention', () async {
    await _runInRepository((root, storage) async {
      _publishVersions(root, retention: const {'keptVersions': 0});

      await expectLater(
        AtlasPrune(root.paths).run(isApplied: true),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('keptVersions'),
          ),
        ),
      );

      expect(_hasVersionFolder(root, _firstLabel), isTrue);
      expect(storage.deletions, isEmpty);
    });
  });
}

void _atlasPrune_should_deleteNothingOnVersionRowWhoseLabelIsNoFolderName() {
  test('AtlasPrune should delete nothing on version row whose label is no '
      'folder name', () async {
    await _runInRepository((root, storage) async {
      final outside = Directory.systemTemp.createTempSync('atlas-outside-');
      final site = Directory(p.join(root.directory.path, _sitePath));

      addTearDown(() => _deleteFolder(outside));
      _publishVersions(root);

      for (final label in ['', '..', outside.path]) {
        _addVersionRow(root, label);

        await expectLater(
          AtlasPrune(root.paths).run(isApplied: true),
          throwsA(isA<AtlasException>()),
          reason: label,
        );

        expect(site.existsSync(), isTrue, reason: label);
        expect(outside.existsSync(), isTrue, reason: label);
        expect(_hasVersionFolder(root, _firstLabel), isTrue, reason: label);
        expect(storage.deletions, isEmpty, reason: label);
      }
    });
  });
}

void _atlasPrune_should_deleteTagThatOriginLostWithoutAPush() {
  test(
    'AtlasPrune should delete tag that origin lost without a push',
    () async {
      await _runInRepository((root, storage) async {
        final path = root.directory.path;
        final prune = AtlasPrune(root.paths);

        _publishVersions(root);
        _pushVersionsWithTags(path, [_firstTag, _secondTag]);

        await prune.run(scope: AtlasPruneScope.repository, isApplied: true);

        commitTestGit(path, 'retention');
        pushTestGit(path, 'main');
        runTestGit(cloneTestGit(_readOriginPath(path)), [
          'push',
          '--quiet',
          'origin',
          '--delete',
          'refs/tags/$_firstTag',
        ]);

        final report = await prune.run(isApplied: true);

        expect(report.tags, [_firstTag]);
        expect(runTestGit(path, ['tag', '--list']), _secondTag);
        expect(_readOriginTags(path), contains(_secondTag));
        expect(storage.deletions, [
          [_strandedShot],
        ]);
      });
    },
  );
}

void _atlasPrune_should_keepVersionFolderWhenOriginRefusesTheTagDeletion() {
  test('AtlasPrune should keep version folder when origin refuses the tag '
      'deletion', () async {
    await _runInRepository((root, storage) async {
      final path = root.directory.path;
      final prune = AtlasPrune(root.paths);

      _publishVersions(root);
      _pushVersionsWithTags(path, [_firstTag]);

      await prune.run(scope: AtlasPruneScope.repository, isApplied: true);

      commitTestGit(path, 'retention');
      pushTestGit(path, 'main');
      _publishVersion(_readSite(root, _sitePath), _thirdLabel, _thirdPosition);
      _refusePushes(_readOriginPath(path));

      await expectLater(
        prune.run(isApplied: true),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('push'),
          ),
        ),
      );

      expect(_hasVersionFolder(root, _secondLabel), isTrue);
      expect(runTestGit(path, ['tag', '--list']), _firstTag);
      expect(storage.deletions, isEmpty);
    });
  });
}

void _atlasPrune_should_keepShotOfABranchOutsideTheRefspecOfTheClone() {
  test('AtlasPrune should keep shot of a branch outside the refspec of the '
      'clone', () async {
    await _runInRepository((root, storage) async {
      final path = root.directory.path;
      final clone = TestAtlasRoot(
        Directory(
          cloneTestGit(
            _readOriginPath(path),
            options: ['--single-branch', '--branch', 'main'],
          ),
        ),
        root.project,
      );

      runTestGit(path, ['checkout', '--quiet', '-b', 'capture']);
      _writeSnapshot(
        root,
        p.join(root.paths.dataPath, 'branch.uk.json'),
        _branchShot,
      );
      commitTestGit(path, 'capture');
      pushTestGit(path, 'capture');
      _storeShotFile(storage, _branchShot, _oldAge);

      final report = await AtlasPrune(
        clone.paths,
      ).run(scope: AtlasPruneScope.storage, isApplied: true);

      expect(report.shots, [_strandedShot]);
      expect(storage.files.keys, contains(_branchShot));
    });
  });
}

void _atlasPrune_should_stopWithoutTheMainBranchAndWithoutASiteFolder() {
  test('AtlasPrune should stop without the main branch and without a site '
      'folder', () async {
    await _runInRepository((root, storage) async {
      final path = root.directory.path;

      runTestGit(path, ['remote', 'remove', 'origin']);
      addTestGitOrigin(path);

      await expectLater(
        AtlasPrune(
          root.paths,
        ).run(scope: AtlasPruneScope.storage, isApplied: true),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('origin/main'),
          ),
        ),
      );

      expect(storage.deletions, isEmpty);
    });
  });
}

void _atlasPrune_should_keepTagOfAVersionThatAnotherSiteHolds() {
  test(
    'AtlasPrune should keep tag of a version that another site holds',
    () async {
      await _runInRepository((root, storage) async {
        final path = root.directory.path;
        final prune = AtlasPrune(root.paths);

        _publishVersions(root);
        _publishVersions(
          root,
          sitePath: _liteSitePath,
          retention: _untaggedRetention,
        );
        _pushVersionsWithTags(path, [_firstTag]);

        await prune.run(scope: AtlasPruneScope.repository, isApplied: true);

        commitTestGit(path, 'retention');
        pushTestGit(path, 'main');

        final report = await prune.run(
          scope: AtlasPruneScope.repository,
          isApplied: true,
        );

        expect(_hasVersionFolder(root, _firstLabel), isFalse);
        expect(report.tags, isEmpty);
        expect(_readOriginTags(path), contains(_firstTag));
        expect(runTestGit(path, ['tag', '--list']), _firstTag);
      });
    },
  );
}

void _atlasPrune_should_keepTagOfAVersionThatASiteOutsideTheRunHolds() {
  test(
    'AtlasPrune should keep tag of a version that a site outside the run holds',
    () async {
      await _runInRepository((root, storage) async {
        final path = root.directory.path;
        final prune = AtlasPrune(root.paths, sites: [p.join(path, _sitePath)]);

        _publishVersions(root);
        _publishVersions(
          root,
          sitePath: _liteSitePath,
          retention: _untaggedRetention,
        );
        _pushVersionsWithTags(path, [_firstTag]);

        await prune.run(scope: AtlasPruneScope.repository, isApplied: true);

        commitTestGit(path, 'retention');
        pushTestGit(path, 'main');

        final report = await prune.run(
          scope: AtlasPruneScope.repository,
          isApplied: true,
        );

        expect(_hasVersionFolder(root, _firstLabel), isFalse);
        expect(report.tags, isEmpty);
        expect(_readOriginTags(path), contains(_firstTag));
      });
    },
  );
}

void _atlasPrune_should_reportOverALocalTagThatOriginHoldsElsewhere() {
  test(
    'AtlasPrune should report over a local tag that origin holds elsewhere',
    () async {
      await _runInRepository((root, storage) async {
        final path = root.directory.path;

        _publishVersions(root);
        _pushVersionsWithTags(path, [_firstTag]);
        runTestGit(path, ['commit', '--allow-empty', '-m', 'later']);
        runTestGit(path, ['tag', '--force', _firstTag]);

        final report = await AtlasPrune(
          root.paths,
        ).run(scope: AtlasPruneScope.repository);

        expect(report.isApplied, isFalse);
      });
    },
  );
}

void _atlasPrune_should_deleteTagOfTwoSitesOnce() {
  test('AtlasPrune should delete tag of two sites once', () async {
    await _runInRepository((root, storage) async {
      final path = root.directory.path;
      final prune = AtlasPrune(root.paths);

      _publishVersions(root);
      _publishVersions(root, sitePath: _liteSitePath);
      _pushVersionsWithTags(path, [_firstTag]);

      await prune.run(scope: AtlasPruneScope.repository, isApplied: true);

      commitTestGit(path, 'retention');
      pushTestGit(path, 'main');

      final report = await prune.run(
        scope: AtlasPruneScope.repository,
        isApplied: true,
      );

      expect(report.tags, [_firstTag]);
      expect(_readOriginTags(path), isEmpty);
      expect(runTestGit(path, ['tag', '--list']), isEmpty);
    });
  });
}

Future<void> _runInRepository(
  Future<void> Function(TestAtlasRoot root, FakeAtlasShotStorage storage)
  body, {
  String storeShot = _storeShot,
}) {
  return TestAtlasRoot.run((root) async {
    final storage = await startFakeAtlasShotStorage(root);

    final path = root.directory.path;

    initTestGit(path);
    addTestGitOrigin(path);
    AtlasSnapshotStore(
      root.paths,
    ).write(createShotSnapshot(stageShot: storeShot, endShot: null));
    commitTestGit(path, 'main');
    pushTestGit(path, 'main');
    _storeShotFile(storage, _storeShot, _oldAge);
    _storeShotFile(storage, _strandedShot, _oldAge);

    await body(root, storage);
  });
}

void _storeShotFile(FakeAtlasShotStorage storage, String shot, Duration age) {
  storage.files[shot] = _shotBytes;
  storage.uploadTimes[shot] = DateTime.now().subtract(age);
}

Future<void> _expectOnlyStrandedShotDeleted(
  TestAtlasRoot root,
  FakeAtlasShotStorage storage, {
  required String kept,
  Duration keptAge = _oldAge,
}) async {
  _storeShotFile(storage, kept, keptAge);

  final report = await AtlasPrune(root.paths).run(isApplied: true);

  expect(report.shots, [_strandedShot]);
  expect(storage.deletions, [
    [_strandedShot],
  ]);
  expect(storage.files.keys, containsAll([kept, _storeShot]));
}

void _writeSnapshot(TestAtlasRoot root, String path, String shot) {
  root.writeText(
    path,
    jsonEncode({
      'end': {'shot': shot},
    }),
  );
}

void _deleteFolder(Directory folder) {
  if (folder.existsSync()) {
    folder.deleteSync(recursive: true);
  }
}

void _addVersionRow(TestAtlasRoot root, String label) {
  root.writeText(
    p.join(root.directory.path, _sitePath, 'versions.json'),
    jsonEncode([
      {'version': label, 'position': _refusedLabelPosition},
      {'version': _firstLabel, 'position': _firstPosition},
      {'version': _secondLabel, 'position': _secondPosition},
    ]),
  );
}

void _pushVersionsWithTags(String path, List<String> tags) {
  commitTestGit(path, 'versions');
  pushTestGit(path, 'main');

  for (final tag in tags) {
    runTestGit(path, ['tag', tag]);
    pushTestGit(path, tag);
  }
}

void _refusePushes(String origin) {
  final hooks = Directory(p.join(origin, 'refusing-hooks'));
  final hook = File(p.join(hooks.path, 'pre-receive'));

  hook
    ..createSync(recursive: true)
    ..writeAsStringSync('#!/bin/sh\nexit 1\n');

  Process.runSync('chmod', ['+x', hook.path]);
  runTestGit(origin, ['config', 'core.hooksPath', hooks.path]);
}

String _readOriginPath(String path) {
  return runTestGit(path, ['remote', 'get-url', 'origin']);
}

void _publishVersions(
  TestAtlasRoot root, {
  String sitePath = _sitePath,
  Map<String, Object?> retention = _retention,
}) {
  final versions = _readSite(root, sitePath);

  root.writeText(
    p.join(versions.sitePath, AtlasVersions.configFileName),
    jsonEncode(retention),
  );
  _publishVersion(versions, _firstLabel, _firstPosition);
  _publishVersion(versions, _secondLabel, _secondPosition);
}

AtlasVersions _readSite(TestAtlasRoot root, String sitePath) {
  return AtlasVersions(p.join(root.directory.path, sitePath));
}

void _publishVersion(AtlasVersions versions, String label, int position) {
  versions.publish(
    AtlasVersion(label: label, position: position, builtAt: ''),
    AtlasVersionRendering(
      page: '<html></html>',
      data: _encodeVersionData(_storeShot),
      shotUrlTemplate: 'https://shots.example/{shot}.png',
      builtAt: DateTime.utc(2026, 11, 21),
    ),
  );
}

List<int> _encodeVersionData(String shot) {
  return gzip.encode(
    utf8.encode(
      jsonEncode({
        'data': {
          'flows': [
            {
              'variants': [
                {
                  'stages': [
                    {'shot': shot},
                  ],
                },
              ],
            },
          ],
        },
      }),
    ),
  );
}

bool _hasVersionFolder(TestAtlasRoot root, String label) {
  return Directory(p.join(root.directory.path, _sitePath, label)).existsSync();
}

List<String> _readVersionLabels(TestAtlasRoot root) {
  return AtlasVersions(
    p.join(root.directory.path, _sitePath),
  ).read().map((version) => version.label).toList();
}

String _readOriginTags(String path) {
  return runTestGit(path, ['ls-remote', '--tags', 'origin']);
}
