import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';

import 'test_utils/create_atlas_snapshot.dart';
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
      final capturedShot = AtlasContentHash.hashBytes(capturedFrame);

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

      expect(
        stored.stages.single.shot,
        AtlasContentHash.hashBytes(capturedFrame),
      );
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

      expect(
        stored.stages.single.shot,
        AtlasContentHash.hashBytes(capturedFrame),
      );
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

        expect(
          stored.stages.single.shot,
          AtlasContentHash.hashBytes(capturedFrame),
        );
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

        expect(
          stored.stages.single.shot,
          AtlasContentHash.hashBytes(capturedFrame),
        );
      });
    },
  );
}

String _writePreviousShot(TestAtlasRoot root) {
  final bytes = _encodeFrame();
  final shot = AtlasContentHash.hashBytes(bytes);

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
