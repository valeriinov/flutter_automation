import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';

/// {@category Utils}
///
/// Moves the screenshots of a capture into the shots directory, each named by
/// its content hash.
///
/// A frame of the same action as the previous snapshot keeps the previous hash
/// while no cell of the frame changed, so capturing an unchanged variant again
/// changes no file. The frames are compared cell by cell rather than as a
/// whole: palette noise scatters a few differing pixels over many cells, while
/// an edited word or a looping illustration packs them into a few.
///
/// A stage with no same-action stage in the previous snapshot is compared
/// with the frame of the main variant's stage walking the same steps, so a new
/// variant takes the shots of the start it shares with the main variant.
final class AtlasShotStore {
  static const _cellSize = 8;
  static const _changedCellDifferingPixels = 24;
  static const _channelTolerance = 16;

  final AtlasLocations _paths;

  const AtlasShotStore(this._paths);

  /// Stores the screenshots [captured] names, and returns it naming their
  /// content hashes instead.
  ///
  /// The [captured] parameter is the snapshot whose shots name files of the
  /// [captureDirectory] parameter, the [previous] parameter is the snapshot
  /// the variant held before the capture, and the [mainVariantShots]
  /// parameter holds, by stage index, the shot of the main variant's stage
  /// walking the same steps, `null` where the steps differ.
  AtlasSnapshot store({
    required AtlasSnapshot captured,
    required AtlasSnapshot? previous,
    required String captureDirectory,
    List<String?> mainVariantShots = const [],
  }) {
    return captured.copyWithStages(
      stages: [
        for (final (index, stage) in captured.stages.indexed)
          stage.copyWithShot(
            _storeShot(
              captureDirectory: captureDirectory,
              fileName: stage.shot,
              previousShot:
                  previous?.tryFindSameActionStage(index, stage)?.shot ??
                  mainVariantShots.elementAtOrNull(index),
            ),
          ),
      ],
      end: captured.end.copyWithShot(
        _storeShot(
          captureDirectory: captureDirectory,
          fileName: captured.end.shot,
          previousShot: previous?.end.shot,
        ),
      ),
    );
  }

  String? _storeShot({
    required String captureDirectory,
    required String? fileName,
    required String? previousShot,
  }) {
    if (fileName == null) {
      return null;
    }

    final bytes = _readCapturedFile(captureDirectory, fileName);
    final shot = AtlasContentHash.hashBytes(bytes);

    if (_isSameAsPreviousShot(bytes, shot, previousShot)) {
      return previousShot;
    }

    final file = File(_paths.resolveShotPath(shot));

    if (!file.existsSync()) {
      file
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }

    return shot;
  }

  Uint8List _readCapturedFile(String captureDirectory, String fileName) {
    final file = File(p.join(captureDirectory, fileName));

    if (!file.existsSync()) {
      throw AtlasException(
        'The capture report names ${file.path}, which is not there.',
      );
    }

    return file.readAsBytesSync();
  }

  bool _isSameAsPreviousShot(
    Uint8List bytes,
    String shot,
    String? previousShot,
  ) {
    if (previousShot == null || previousShot == shot) {
      return false;
    }

    final previousFile = File(_paths.resolveShotPath(previousShot));

    if (!previousFile.existsSync()) {
      return false;
    }

    return _isSameFrame(
      image.decodePng(bytes),
      image.decodePng(previousFile.readAsBytesSync()),
    );
  }

  bool _isSameFrame(image.Image? current, image.Image? previous) {
    if (current == null || previous == null) {
      return false;
    }

    if (current.width != previous.width || current.height != previous.height) {
      return false;
    }

    final differingPixelsByCell = current
        .where(
          (pixel) =>
              _isPixelDifferent(pixel, previous.getPixel(pixel.x, pixel.y)),
        )
        .groupFoldBy<(int, int), int>(
          (pixel) => (pixel.x ~/ _cellSize, pixel.y ~/ _cellSize),
          (count, _) => (count ?? 0) + 1,
        );

    return differingPixelsByCell.values.every(
      (count) => count < _changedCellDifferingPixels,
    );
  }

  bool _isPixelDifferent(image.Pixel current, image.Pixel previous) {
    return (current.r - previous.r).abs() > _channelTolerance ||
        (current.g - previous.g).abs() > _channelTolerance ||
        (current.b - previous.b).abs() > _channelTolerance ||
        (current.a - previous.a).abs() > _channelTolerance;
  }
}
