import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_id.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_shot_storage.dart';
import 'test_utils/recording_stdout.dart';
import 'test_utils/test_atlas_root.dart';

const _frameSize = 100;
const _narrowFrameWidth = 90;
const _cellSize = 8;
const _cellSpacing = 16;
const _changedCellPixels = 24;
const _noisyCellPixels = 20;
const _noisyCellCount = 5;
const _whiteChannel = 255;
const _capturedFileName = 'shop_flow_shopFromExistingItem_2.png';
const _label = 'open cart details';
const _targetRect = {'left': 0.05, 'top': 0.4, 'right': 0.95, 'bottom': 0.55};

void main() {
  group('AtlasShotStore Tests', () {
    _atlasShotStore_should_keepPreviousShotWhenNoCellChanged();
    _atlasShotStore_should_replaceShotWhenOneCellChanged();
    _atlasShotStore_should_replaceShotOfAnotherAction();
    _atlasShotStore_should_replaceShotOfAnotherSize();
    _atlasShotStore_should_takeMainVariantShotOfTheSameSteps();
    _atlasShotStore_should_replaceMainVariantShotWhenOneCellChanged();
    _atlasShotStore_should_replaceShotWhereMainVariantStepsDiffer();
    _atlasShotStore_should_keepPreviousShotReadFromTheStorage();
    _atlasShotStore_should_replaceShotTheStorageDoesNotHoldWithAWarning();
    _atlasShotStore_should_stopOnAnotherAnswerOfTheStorageWithItsCode();
    _atlasShotStore_should_stopOnOtherBytesThanThePreviousShotNames();
  });
}

void _atlasShotStore_should_keepPreviousShotWhenNoCellChanged() {
  test(
    'AtlasShotStore should keep previous shot when no cell changed',
    () async {
      await TestAtlasRoot.run((root) async {
        final previousShot = _writePreviousShot(root);

        final stored = await _store(
          root,
          capturedFrame: _encodeFrame(
            changedCells: _noisyCellCount,
            pixelsPerCell: _noisyCellPixels,
          ),
          previous: _createSnapshot(label: _label, shot: previousShot),
        );

        expect(stored.stages.single.shot, previousShot);
        expect(stored.stages.single.targetRect, _targetRect);
        expect(stored.end.shot, previousShot);
        expect(Directory(root.paths.shotsPath).listSync(), hasLength(1));
      });
    },
  );
}

void _atlasShotStore_should_replaceShotWhenOneCellChanged() {
  test('AtlasShotStore should replace shot when one cell changed', () async {
    await TestAtlasRoot.run((root) async {
      final previousShot = _writePreviousShot(root);
      final capturedFrame = _encodeFrame(
        changedCells: 1,
        pixelsPerCell: _changedCellPixels,
      );
      final capturedShot = AtlasShotId.hashBytes(capturedFrame);

      final stored = await _store(
        root,
        capturedFrame: capturedFrame,
        previous: _createSnapshot(label: _label, shot: previousShot),
      );

      expect(stored.stages.single.shot, capturedShot);
      expect(
        File(root.paths.resolveShotPath(capturedShot)).existsSync(),
        isTrue,
      );
    });
  });
}

void _atlasShotStore_should_replaceShotOfAnotherAction() {
  test('AtlasShotStore should replace shot of another action', () async {
    await TestAtlasRoot.run((root) async {
      final previousShot = _writePreviousShot(root);
      final capturedFrame = _encodeFrame(
        changedCells: 1,
        pixelsPerCell: _noisyCellPixels,
      );

      final stored = await _store(
        root,
        capturedFrame: capturedFrame,
        previous: _createSnapshot(
          label: 'open item details',
          shot: previousShot,
        ),
      );

      expect(stored.stages.single.shot, AtlasShotId.hashBytes(capturedFrame));
    });
  });
}

void _atlasShotStore_should_replaceShotOfAnotherSize() {
  test('AtlasShotStore should replace shot of another size', () async {
    await TestAtlasRoot.run((root) async {
      final previousShot = _writePreviousShot(root);
      final capturedFrame = _encodeFrame(width: _narrowFrameWidth);

      final stored = await _store(
        root,
        capturedFrame: capturedFrame,
        previous: _createSnapshot(label: _label, shot: previousShot),
      );

      expect(stored.stages.single.shot, AtlasShotId.hashBytes(capturedFrame));
    });
  });
}

void _atlasShotStore_should_takeMainVariantShotOfTheSameSteps() {
  test(
    'AtlasShotStore should take main variant shot of the same steps',
    () async {
      await TestAtlasRoot.run((root) async {
        final mainShot = _writePreviousShot(root);

        final stored = await _store(
          root,
          capturedFrame: _encodeFrame(
            changedCells: _noisyCellCount,
            pixelsPerCell: _noisyCellPixels,
          ),
          previous: null,
          mainVariantShots: [mainShot],
        );

        expect(stored.stages.single.shot, mainShot);
      });
    },
  );
}

void _atlasShotStore_should_replaceMainVariantShotWhenOneCellChanged() {
  test(
    'AtlasShotStore should replace main variant shot when one cell changed',
    () async {
      await TestAtlasRoot.run((root) async {
        final mainShot = _writePreviousShot(root);
        final capturedFrame = _encodeFrame(
          changedCells: 1,
          pixelsPerCell: _changedCellPixels,
        );

        final stored = await _store(
          root,
          capturedFrame: capturedFrame,
          previous: null,
          mainVariantShots: [mainShot],
        );

        expect(stored.stages.single.shot, AtlasShotId.hashBytes(capturedFrame));
      });
    },
  );
}

void _atlasShotStore_should_replaceShotWhereMainVariantStepsDiffer() {
  test(
    'AtlasShotStore should replace shot where main variant steps differ',
    () async {
      await TestAtlasRoot.run((root) async {
        _writePreviousShot(root);

        final capturedFrame = _encodeFrame(
          changedCells: _noisyCellCount,
          pixelsPerCell: _noisyCellPixels,
        );

        final stored = await _store(
          root,
          capturedFrame: capturedFrame,
          previous: null,
          mainVariantShots: [null],
        );

        expect(stored.stages.single.shot, AtlasShotId.hashBytes(capturedFrame));
      });
    },
  );
}

void _atlasShotStore_should_keepPreviousShotReadFromTheStorage() {
  test(
    'AtlasShotStore should keep previous shot read from the storage',
    () async {
      await TestAtlasRoot.run((root) async {
        final storage = await startFakeAtlasShotStorage(root);

        final previousShot = _storePreviousShot(storage);

        storage.isRedirecting = true;

        final stored = await _store(
          root,
          capturedFrame: _encodeFrame(
            changedCells: _noisyCellCount,
            pixelsPerCell: _noisyCellPixels,
          ),
          previous: _createSnapshot(label: _label, shot: previousShot),
        );

        expect(stored.stages.single.shot, previousShot);
        expect(storage.requestedShots, [previousShot]);
        expect(
          File(root.paths.resolveShotPath(previousShot)).readAsBytesSync(),
          storage.files[previousShot],
        );
        expect(Directory(root.paths.storeShotsPath).existsSync(), isFalse);
      });
    },
  );
}

void _atlasShotStore_should_replaceShotTheStorageDoesNotHoldWithAWarning() {
  test('AtlasShotStore should replace shot the storage does not hold with a '
      'warning', () async {
    await TestAtlasRoot.run((root) async {
      await startFakeAtlasShotStorage(root);

      final previousShot = AtlasShotId.hashBytes(_encodeFrame());
      final capturedFrame = _encodeFrame(
        changedCells: _noisyCellCount,
        pixelsPerCell: _noisyCellPixels,
      );
      final warnings = <String>[];

      final stored = await IOOverrides.runZoned(
        () => _store(
          root,
          capturedFrame: capturedFrame,
          previous: _createSnapshot(label: _label, shot: previousShot),
        ),
        stderr: () => RecordingStdout(warnings),
      );

      expect(stored.stages.single.shot, AtlasShotId.hashBytes(capturedFrame));
      expect(warnings, contains(contains(previousShot)));
    });
  });
}

void _atlasShotStore_should_stopOnAnotherAnswerOfTheStorageWithItsCode() {
  test('AtlasShotStore should stop on another answer of the storage with '
      'its code', () async {
    await TestAtlasRoot.run((root) async {
      final storage = await startFakeAtlasShotStorage(root);

      final previousShot = _storePreviousShot(storage);

      storage.answeredStatus = HttpStatus.serviceUnavailable;

      await expectLater(
        _store(
          root,
          capturedFrame: _encodeFrame(
            changedCells: _noisyCellCount,
            pixelsPerCell: _noisyCellPixels,
          ),
          previous: _createSnapshot(label: _label, shot: previousShot),
        ),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('${HttpStatus.serviceUnavailable}'),
          ),
        ),
      );
    });
  });
}

void _atlasShotStore_should_stopOnOtherBytesThanThePreviousShotNames() {
  test('AtlasShotStore should stop on other bytes than the previous shot '
      'names', () async {
    await TestAtlasRoot.run((root) async {
      final storage = await startFakeAtlasShotStorage(root);

      final previousShot = _storePreviousShot(storage);

      storage.files[previousShot] = const [1, 2, 3];

      await expectLater(
        _store(
          root,
          capturedFrame: _encodeFrame(
            changedCells: _noisyCellCount,
            pixelsPerCell: _noisyCellPixels,
          ),
          previous: _createSnapshot(label: _label, shot: previousShot),
        ),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains(previousShot),
          ),
        ),
      );

      expect(
        File(root.paths.resolveShotPath(previousShot)).existsSync(),
        isFalse,
      );
    });
  });
}

String _storePreviousShot(FakeAtlasShotStorage storage) {
  final bytes = _encodeFrame();
  final shot = AtlasShotId.hashBytes(bytes);

  storage.files[shot] = bytes;

  return shot;
}

String _writePreviousShot(TestAtlasRoot root) {
  final bytes = _encodeFrame();
  final shot = AtlasShotId.hashBytes(bytes);

  root.writeShot(shot, bytes);

  return shot;
}

Future<AtlasSnapshot> _store(
  TestAtlasRoot root, {
  required List<int> capturedFrame,
  required AtlasSnapshot? previous,
  List<String?> mainVariantShots = const [],
}) async {
  final captureDirectory = await root.createCaptureDirectory();

  File(
    p.join(captureDirectory.path, _capturedFileName),
  ).writeAsBytesSync(capturedFrame);

  return AtlasShotStore(root.paths).store(
    captured: _createSnapshot(label: _label, shot: _capturedFileName),
    previous: previous,
    captureDirectory: captureDirectory.path,
    mainVariantShots: mainVariantShots,
  );
}

List<int> _encodeFrame({
  int changedCells = 0,
  int pixelsPerCell = 0,
  int width = _frameSize,
}) {
  final frame = image.Image(width: width, height: _frameSize);

  for (int cell = 0; cell < changedCells; cell += 1) {
    _whitenCellPixels(frame, cell * _cellSpacing, pixelsPerCell);
  }

  return image.encodePng(frame);
}

void _whitenCellPixels(image.Image frame, int cellX, int pixelCount) {
  for (int index = 0; index < pixelCount; index += 1) {
    frame.setPixelRgb(
      cellX + index % _cellSize,
      index ~/ _cellSize,
      _whiteChannel,
      _whiteChannel,
      _whiteChannel,
    );
  }
}

AtlasSnapshot _createSnapshot({required String label, required String shot}) {
  return createAtlasSnapshot(
    flow: 'shop_flow',
    variant: 'shopFromExistingItem',
    stages: [
      AtlasStage(
        label: label,
        action: 'tap',
        journal: const [],
        ok: true,
        target: const {'by': 'valueKey', 'value': 'cart_search.card'},
        block: null,
        targetRect: _targetRect,
        screen: null,
        designScreen: null,
        shot: shot,
        error: null,
      ),
    ],
    end: AtlasEnd(screen: null, designScreen: null, shot: shot),
  );
}
