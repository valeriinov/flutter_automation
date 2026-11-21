import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_id.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_migration.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';

import 'test_utils/create_shot_snapshot.dart';
import 'test_utils/fake_atlas_shot_storage.dart';
import 'test_utils/test_atlas_root.dart';

const _flow = 'shop_flow';
const _variant = 'shopFromSearch';
const _stageName = 'aaaaaaaaaaaa';
const _endName = 'bbbbbbbbbbbb';
const _fileLessName = 'cccccccccccc';
const _stageBytes = [1, 2, 3];
const _endBytes = [4, 5, 6];

final _stageShot = AtlasShotId.hashBytes(_stageBytes);
final _endShot = AtlasShotId.hashBytes(_endBytes);

void main() {
  group('AtlasShotMigration Tests', () {
    _atlasShotMigration_should_renameShotsAndRewriteOnlyShotFields();
    _atlasShotMigration_should_changeNothingOnSecondRun();
    _atlasShotMigration_should_stopOnShotFieldWithoutFile();
    _atlasShotMigration_should_storeShotsInTheRemoteStorage();
    _atlasShotMigration_should_stopWhenTheStorageHoldsNoMigratedShot();
    _atlasShotMigration_should_renameShotsOfAStoppedRun();
    _atlasShotMigration_should_keepShotsWhenAnOldNameSortsBeforeMisnamedFile();
    _atlasShotMigration_should_keepShotsWhenAnOldNameSortsAfterMisnamedFile();
    _atlasShotMigration_should_placeShotsThatAStoppedRunMoved();
  });
}

void _atlasShotMigration_should_renameShotsAndRewriteOnlyShotFields() {
  test(
    'AtlasShotMigration should rename shots and rewrite only shot fields',
    () async {
      await TestAtlasRoot.run((root) async {
        final snapshot = _writeStore(root);
        final previousText = snapshot.readAsStringSync();

        final result = await AtlasShotMigration(root.paths).run();

        final migrated = AtlasSnapshotStore(
          root.paths,
        ).tryRead(flow: _flow, variant: _variant, locale: 'uk');

        expect(result, (
          renamedShots: 2,
          rewrittenSnapshots: 1,
          storedShots: 0,
        ));
        expect(migrated?.stages.single.shot, _stageShot);
        expect(migrated?.end.shot, _endShot);
        expect(
          snapshot.readAsStringSync(),
          previousText
              .replaceAll(_stageName, _stageShot)
              .replaceAll(_endName, _endShot),
        );
        expect(_listStoreShots(root), {'$_stageShot.png', '$_endShot.png'});
      });
    },
  );
}

void _atlasShotMigration_should_changeNothingOnSecondRun() {
  test('AtlasShotMigration should change nothing on second run', () async {
    await TestAtlasRoot.run((root) async {
      final snapshot = _writeStore(root);

      await AtlasShotMigration(root.paths).run();

      final migratedText = snapshot.readAsStringSync();

      final result = await AtlasShotMigration(root.paths).run();

      expect(result, (renamedShots: 0, rewrittenSnapshots: 0, storedShots: 0));
      expect(snapshot.readAsStringSync(), migratedText);
      expect(_listStoreShots(root), {'$_stageShot.png', '$_endShot.png'});
    });
  });
}

void _atlasShotMigration_should_stopOnShotFieldWithoutFile() {
  test('AtlasShotMigration should stop on shot field without file', () async {
    await TestAtlasRoot.run((root) async {
      final snapshot = _writeStore(root, endName: _fileLessName);
      final previousText = snapshot.readAsStringSync();

      await expectLater(
        AtlasShotMigration(root.paths).run(),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains(_fileLessName),
          ),
        ),
      );

      expect(snapshot.readAsStringSync(), previousText);
      expect(_listStoreShots(root), {'$_stageName.png', '$_endName.png'});
    });
  });
}

void _atlasShotMigration_should_storeShotsInTheRemoteStorage() {
  test('AtlasShotMigration should store shots in the remote storage', () async {
    await TestAtlasRoot.run((root) async {
      final storage = await startFakeAtlasShotStorage(root);

      _writeStore(root);

      final result = await AtlasShotMigration(root.paths).run();

      expect(result.storedShots, 2);
      expect(storage.files, {_stageShot: _stageBytes, _endShot: _endBytes});
      expect(storage.requestedShots.toSet(), {_stageShot, _endShot});
      expect(_listStoreShots(root), {'$_stageShot.png', '$_endShot.png'});
    });
  });
}

void _atlasShotMigration_should_stopWhenTheStorageHoldsNoMigratedShot() {
  test('AtlasShotMigration should stop when the storage holds no migrated '
      'shot', () async {
    await TestAtlasRoot.run((root) async {
      await startFakeAtlasShotStorage(root);

      _writeStore(root);

      await AtlasShotMigration(root.paths).run();

      File(root.paths.resolveStoreShotPath(_endShot)).deleteSync();

      root.project.storage = await startFakeAtlasShotStorage(root);
      await expectLater(
        AtlasShotMigration(root.paths).run(),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            allOf(contains(_endShot), isNot(contains(_stageShot))),
          ),
        ),
      );
    });
  });
}

void _atlasShotMigration_should_renameShotsOfAStoppedRun() {
  test('AtlasShotMigration should rename shots of a stopped run', () async {
    await TestAtlasRoot.run((root) async {
      _writeStore(root);
      AtlasSnapshotStore(
        root.paths,
      ).write(createShotSnapshot(stageShot: _stageShot, endShot: _endShot));

      final result = await AtlasShotMigration(root.paths).run();

      expect(result, (renamedShots: 2, rewrittenSnapshots: 0, storedShots: 0));
      expect(_listStoreShots(root), {'$_stageShot.png', '$_endShot.png'});
    });
  });
}

void
_atlasShotMigration_should_keepShotsWhenAnOldNameSortsBeforeMisnamedFile() {
  test('AtlasShotMigration should keep shots when an old name sorts before '
      'misnamed file', () async {
    await TestAtlasRoot.run((root) async {
      _writeMisnamedStore(
        root,
        stageName: '000000000000',
        endName: '000000000001',
      );

      await AtlasShotMigration(root.paths).run();

      _expectEachShotHoldsItsBytes(root);
    });
  });
}

void _atlasShotMigration_should_keepShotsWhenAnOldNameSortsAfterMisnamedFile() {
  test('AtlasShotMigration should keep shots when an old name sorts after '
      'misnamed file', () async {
    await TestAtlasRoot.run((root) async {
      _writeMisnamedStore(
        root,
        stageName: 'ffffffffffff',
        endName: 'eeeeeeeeeeee',
      );

      await AtlasShotMigration(root.paths).run();

      _expectEachShotHoldsItsBytes(root);
    });
  });
}

void _atlasShotMigration_should_placeShotsThatAStoppedRunMoved() {
  test(
    'AtlasShotMigration should place shots that a stopped run moved',
    () async {
      await TestAtlasRoot.run((root) async {
        File('${root.paths.resolveStoreShotPath(_stageShot)}.moved')
          ..createSync(recursive: true)
          ..writeAsBytesSync(_stageBytes);

        AtlasSnapshotStore(
          root.paths,
        ).write(createShotSnapshot(stageShot: _stageShot, endShot: null));

        await AtlasShotMigration(root.paths).run();

        expect(_listStoreShots(root), {'$_stageShot.png'});
      });
    },
  );
}

// A store whose file under the stage identifier holds the bytes of the end.
void _writeMisnamedStore(
  TestAtlasRoot root, {
  required String stageName,
  required String endName,
}) {
  _writeStoreShot(root, stageName, _stageBytes);
  _writeStoreShot(root, endName, _endBytes);
  _writeStoreShot(root, _stageShot, _endBytes);
  AtlasSnapshotStore(
    root.paths,
  ).write(createShotSnapshot(stageShot: stageName, endShot: endName));
}

void _expectEachShotHoldsItsBytes(TestAtlasRoot root) {
  expect(_listStoreShots(root), {'$_stageShot.png', '$_endShot.png'});
  expect(
    File(root.paths.resolveStoreShotPath(_stageShot)).readAsBytesSync(),
    _stageBytes,
  );
  expect(
    File(root.paths.resolveStoreShotPath(_endShot)).readAsBytesSync(),
    _endBytes,
  );
}

File _writeStore(TestAtlasRoot root, {String endName = _endName}) {
  _writeStoreShot(root, _stageName, _stageBytes);
  _writeStoreShot(root, _endName, _endBytes);
  AtlasSnapshotStore(
    root.paths,
  ).write(createShotSnapshot(stageShot: _stageName, endShot: endName));

  return File(
    root.paths.resolveSnapshotPath(
      flow: _flow,
      variant: _variant,
      locale: 'uk',
    ),
  );
}

void _writeStoreShot(TestAtlasRoot root, String name, List<int> bytes) {
  File(root.paths.resolveStoreShotPath(name))
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
}

Set<String> _listStoreShots(TestAtlasRoot root) {
  return {
    for (final file in Directory(root.paths.storeShotsPath).listSync())
      file.uri.pathSegments.last,
  };
}
