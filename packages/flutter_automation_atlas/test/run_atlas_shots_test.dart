import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_id.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/run_atlas.dart';

import 'test_utils/create_shot_snapshot.dart';
import 'test_utils/fake_atlas_shot_storage.dart';
import 'test_utils/test_atlas_root.dart';
import 'test_utils/test_git.dart';

const _storeShot =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _otherStoreShot =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _branchShot =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _pageShot =
    '4444444444444444444444444444444444444444444444444444444444444444';
const _strandedShot =
    '5555555555555555555555555555555555555555555555555555555555555555';
const _shotBytes = [1, 2, 3];
const _cachedShotBytes = [4, 5, 6];

final _heldShot = AtlasShotId.hashBytes(_shotBytes);
final _cachedShot = AtlasShotId.hashBytes(_cachedShotBytes);

void main() {
  group('AtlasRun Shots Tests', () {
    _atlasRun_should_deleteShotNoFileOfTheRepositoryNames();
    _atlasRun_should_refuseToDeleteShotOfAnotherStoreFolder();
    _atlasRun_should_refuseToDeleteShotOfARemoteBranch();
    _atlasRun_should_refuseToDeleteShotOfASitePage();
    _atlasRun_should_rejectDeleteShotsOfMalformedId();
    _atlasRun_should_uploadOnlyShotsTheStorageDoesNotHold();
    _atlasRun_should_readShotsCacheTheOptionNames();
    _atlasRun_should_uploadNoFileThatHoldsOtherBytesThanItsName();
    _atlasRun_should_stopShotCommandsWithoutStorage();
    _atlasRun_should_migrateShotsOfTheStore();
  });
}

void _atlasRun_should_deleteShotNoFileOfTheRepositoryNames() {
  test('AtlasRun should delete shot no file of the repository names', () async {
    await _runInRepository((root, storage) async {
      storage.files[_strandedShot] = _shotBytes;

      await _runIn(root, ['delete-shots', _strandedShot]);

      expect(storage.deletions, [
        [_strandedShot],
      ]);
    });
  });
}

void _atlasRun_should_refuseToDeleteShotOfAnotherStoreFolder() {
  test(
    'AtlasRun should refuse to delete shot of another store folder',
    () async {
      await _runInRepository((root, storage) async {
        root.writeText(
          p.join(root.directory.path, 'prod/data/shop_flow/a.uk.json'),
          jsonEncode({
            'end': {'shot': _otherStoreShot},
          }),
        );

        await _expectRefusal(root, storage, _otherStoreShot);
      });
    },
  );
}

void _atlasRun_should_refuseToDeleteShotOfARemoteBranch() {
  test('AtlasRun should refuse to delete shot of a remote branch', () async {
    await _runInRepository((root, storage) async {
      final branchSnapshot = p.join(root.paths.dataPath, 'branch.uk.json');

      commitTestGit(root.directory.path, 'main');
      root.writeText(
        branchSnapshot,
        jsonEncode({
          'end': {'shot': _branchShot},
        }),
      );
      runTestGit(root.directory.path, [
        'update-ref',
        'refs/remotes/origin/capture',
        commitTestGit(root.directory.path, 'capture'),
      ]);
      runTestGit(root.directory.path, ['reset', '--quiet', '--hard', 'HEAD~1']);

      await _expectRefusal(root, storage, _branchShot);

      expect(File(branchSnapshot).existsSync(), isFalse);
    });
  });
}

void _atlasRun_should_refuseToDeleteShotOfASitePage() {
  test('AtlasRun should refuse to delete shot of a site page', () async {
    await _runInRepository((root, storage) async {
      root.writeText(
        p.join(root.directory.path, 'site/test/index.html'),
        '<script type="application/json" id="atlas-shots">'
        '{"shotUrls":{"0123456789ab":"https://shots.example/$_pageShot.png"}}'
        '</script>',
      );

      await _expectRefusal(root, storage, _pageShot);
    });
  });
}

void _atlasRun_should_rejectDeleteShotsOfMalformedId() {
  test('AtlasRun should reject delete-shots of malformed id', () async {
    await _runInRepository((root, storage) async {
      await expectLater(
        _runIn(root, ['delete-shots', '0123456789ab']),
        throwsA(isA<AtlasException>()),
      );

      expect(storage.deletions, isEmpty);
    });
  });
}

void _atlasRun_should_uploadOnlyShotsTheStorageDoesNotHold() {
  test('AtlasRun should upload only shots the storage does not hold', () async {
    await _runInRepository((root, storage) async {
      _writeShot(root.paths.storeShotsPath, _heldShot);
      _writeShot(root.paths.storeShotsPath, 'not-a-shot');
      _writeShot(root.paths.shotsCachePath, _cachedShot, _cachedShotBytes);

      storage.files[_heldShot] = _shotBytes;

      await _runIn(root, ['upload-shots']);

      expect(storage.uploads, [
        [_cachedShot],
      ]);
    });
  });
}

void _atlasRun_should_readShotsCacheTheOptionNames() {
  test('AtlasRun should read shots cache the option names', () async {
    await _runInRepository((root, storage) async {
      final cache = p.join(root.directory.path, 'kept_cache');

      _writeShot(cache, _cachedShot, _cachedShotBytes);

      await _runIn(root, ['upload-shots', '--shots-cache', cache]);

      expect(storage.uploads, [
        [_cachedShot],
      ]);
    });
  });
}

void _atlasRun_should_uploadNoFileThatHoldsOtherBytesThanItsName() {
  test(
    'AtlasRun should upload no file that holds other bytes than its name',
    () async {
      await _runInRepository((root, storage) async {
        _writeShot(root.paths.shotsCachePath, _cachedShot);

        await expectLater(
          _runIn(root, ['upload-shots']),
          throwsA(
            isA<AtlasException>().having(
              (error) => error.message,
              'message',
              contains(_cachedShot),
            ),
          ),
        );

        expect(storage.uploads, isEmpty);
      });
    },
  );
}

void _atlasRun_should_stopShotCommandsWithoutStorage() {
  test('AtlasRun should stop shot commands without storage', () async {
    await TestAtlasRoot.run((root) async {
      for (final command in [
        ['upload-shots'],
        ['delete-shots', _strandedShot],
      ]) {
        await expectLater(
          _runIn(root, command),
          throwsA(
            isA<AtlasException>().having(
              (error) => error.message,
              'message',
              contains('shotStorage'),
            ),
          ),
        );
      }
    });
  });
}

void _atlasRun_should_migrateShotsOfTheStore() {
  test('AtlasRun should migrate shots of the store', () async {
    await TestAtlasRoot.run((root) async {
      _writeShot(root.paths.storeShotsPath, 'aaaaaaaaaaaa');
      AtlasSnapshotStore(
        root.paths,
      ).write(createShotSnapshot(stageShot: 'aaaaaaaaaaaa', endShot: null));

      await _runIn(root, ['migrate-shots']);

      expect(
        Directory(root.paths.storeShotsPath).listSync().single.path,
        isNot(contains('aaaaaaaaaaaa')),
      );
    });
  });
}

Future<void> _runInRepository(
  Future<void> Function(TestAtlasRoot root, FakeAtlasShotStorage storage) body,
) {
  return TestAtlasRoot.run((root) async {
    final storage = await startFakeAtlasShotStorage(root);

    initTestGit(root.directory.path);
    AtlasSnapshotStore(
      root.paths,
    ).write(createShotSnapshot(stageShot: _storeShot, endShot: null));

    await body(root, storage);
  });
}

Future<void> _expectRefusal(
  TestAtlasRoot root,
  FakeAtlasShotStorage storage,
  String shot,
) async {
  await expectLater(
    _runIn(root, ['delete-shots', _strandedShot, shot]),
    throwsA(
      isA<AtlasException>().having(
        (error) => error.message,
        'message',
        allOf(contains(shot), isNot(contains(_strandedShot))),
      ),
    ),
  );

  expect(storage.deletions, isEmpty);
}

Future<void> _runIn(TestAtlasRoot root, List<String> args) {
  return AtlasRun(args, root.project, rootPath: root.directory.path).run();
}

void _writeShot(String directory, String name, [List<int> bytes = _shotBytes]) {
  File(p.join(directory, '$name.png'))
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
}
