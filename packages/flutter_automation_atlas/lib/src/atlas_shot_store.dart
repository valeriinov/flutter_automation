import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_remote_shots.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_id.dart';

/// {@category Utils}
///
/// Moves the screenshots of a capture into the shots directory
/// ([AtlasLocations.shotsPath]), each named by its [AtlasShotId].
///
/// With a remote storage, the shots directory is the cache folder. A previous
/// frame that the cache does not hold comes from the storage. A previous
/// frame that the storage does not hold either counts as another frame, with
/// a warning.
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
  final AtlasRemoteShots? _remoteShots;

  /// The [remoteShots] parameter reads a previous frame from the remote
  /// storage. It is the storage of the project by default, and `null` when
  /// the store folder keeps the screenshots.
  AtlasShotStore(this._paths, {AtlasRemoteShots? remoteShots})
    : _remoteShots = remoteShots ?? AtlasRemoteShots.tryCreate(_paths);

  /// Stores the screenshots [captured] names, and returns it naming their
  /// content hashes instead.
  ///
  /// The [captured] parameter is the snapshot whose shots name files of the
  /// [captureDirectory] parameter, the [previous] parameter is the snapshot
  /// the variant held before the capture, and the [mainVariantShots]
  /// parameter holds, by stage index, the shot of the main variant's stage
  /// walking the same steps, `null` where the steps differ.
  Future<AtlasSnapshot> store({
    required AtlasSnapshot captured,
    required AtlasSnapshot? previous,
    required String captureDirectory,
    List<String?> mainVariantShots = const [],
  }) async {
    return captured.copyWithStages(
      stages: [
        for (final (index, stage) in captured.stages.indexed)
          stage.copyWithShot(
            await _storeShot(
              captureDirectory: captureDirectory,
              fileName: stage.shot,
              previousShot:
                  previous?.tryFindSameActionStage(index, stage)?.shot ??
                  mainVariantShots.elementAtOrNull(index),
            ),
          ),
      ],
      end: captured.end.copyWithShot(
        await _storeShot(
          captureDirectory: captureDirectory,
          fileName: captured.end.shot,
          previousShot: previous?.end.shot,
        ),
      ),
    );
  }

  Future<String?> _storeShot({
    required String captureDirectory,
    required String? fileName,
    required String? previousShot,
  }) async {
    if (fileName == null) {
      return null;
    }

    final bytes = _readCapturedFile(captureDirectory, fileName);
    final shot = AtlasShotId.hashBytes(bytes);

    if (await _isSameAsPreviousShot(bytes, shot, previousShot)) {
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

  Future<bool> _isSameAsPreviousShot(
    Uint8List bytes,
    String shot,
    String? previousShot,
  ) async {
    if (previousShot == null || previousShot == shot) {
      return false;
    }

    final previousFile = File(_paths.resolveShotPath(previousShot));

    if (!previousFile.existsSync() && !await _tryDownload(previousShot)) {
      return false;
    }

    return _isSameFrame(
      image.decodePng(bytes),
      image.decodePng(previousFile.readAsBytesSync()),
    );
  }

  Future<bool> _tryDownload(String previousShot) async {
    final remoteShots = _remoteShots;

    if (remoteShots == null) {
      return false;
    }

    final isDownloaded = await remoteShots.tryDownload(previousShot);

    if (!isDownloaded) {
      stderr.writeln(
        'The shot storage holds no previous shot $previousShot; the frame '
        'counts as another frame.',
      );
    }

    return isDownloaded;
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
