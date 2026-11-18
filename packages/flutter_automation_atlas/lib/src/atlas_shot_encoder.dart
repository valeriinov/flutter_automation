import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';

/// {@category Utils}
///
/// Turns stored shots into the sheet the bundle page shows them from.
abstract interface class AtlasShotEncoder {
  /// The sheet holding the shots named by the [shots] content hashes, in
  /// their order.
  AtlasShotSheet encodeSheet(List<String> shots);
}

/// {@category Utils}
///
/// One image holding several shots, with the place of each on it.
final class AtlasShotSheet {
  /// The data URI of the sheet image.
  final String dataUri;

  /// The place of each shot on the sheet, by its content hash.
  final Map<String, AtlasShotCell> cells;

  const AtlasShotSheet({required this.dataUri, required this.cells});
}

/// {@category Utils}
///
/// The pixel rectangle one shot takes on its sheet.
final class AtlasShotCell {
  final int left;
  final int top;
  final int width;
  final int height;

  const AtlasShotCell({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// The rectangle as the page data holds it: left, top, width, height.
  List<int> toPageData() => [left, top, width, height];
}

/// {@category Utils}
///
/// Lays the shots of a sheet out row by row, [_columns] per row, each in a
/// cell as large as the largest of them, reduces the sheet to one palette of
/// 256 colours and encodes it as lossless WebP with `cwebp`,
/// keeping every encode under [AtlasLocations.bundleShotCachePath] by the
/// hash of its shots, so a bundle built again encodes only the sheets it has
/// not seen.
///
/// Throws a [AtlasException] naming `brew install webp` when `cwebp`
/// is not on the path, one naming the shot that is not a PNG and one naming
/// the sheet when an encode fails.
final class AtlasShotWebpEncoder implements AtlasShotEncoder {
  static const _columns = 4;
  static const _executable = 'cwebp';
  static const _dataUriPrefix = 'data:image/webp;base64,';
  static const _webpExtension = '.webp';
  static const _pngExtension = '.png';

  final AtlasLocations _paths;

  const AtlasShotWebpEncoder(this._paths);

  @override
  AtlasShotSheet encodeSheet(List<String> shots) {
    final sizes = shots.map(_readShotSize).toList();
    final cellWidth = sizes.map((size) => size.width).max;
    final cellHeight = sizes.map((size) => size.height).max;
    final cells = {
      for (final (index, shot) in shots.indexed)
        shot: AtlasShotCell(
          left: index % _columns * cellWidth,
          top: index ~/ _columns * cellHeight,
          width: sizes[index].width,
          height: sizes[index].height,
        ),
    };
    final cached = File(
      p.join(_paths.bundleShotCachePath, '${_nameSheet(shots)}$_webpExtension'),
    );

    if (!cached.existsSync()) {
      _encode(cells, cached);
    }

    return AtlasShotSheet(
      dataUri: '$_dataUriPrefix${base64Encode(cached.readAsBytesSync())}',
      cells: cells,
    );
  }

  ({int width, int height}) _readShotSize(String shot) {
    final info = img.PngDecoder().startDecode(_readShotBytes(shot));

    if (info == null) {
      throw AtlasException('The shot $shot is not a PNG.');
    }

    return (width: info.width, height: info.height);
  }

  String _nameSheet(List<String> shots) {
    return sha1.convert(utf8.encode(shots.join(','))).toString();
  }

  void _encode(Map<String, AtlasShotCell> cells, File target) {
    final sheet = _composeSheet(cells);
    final png = File('${target.path}$_pngExtension');

    png
      ..createSync(recursive: true)
      ..writeAsBytesSync(
        img.encodePng(img.quantize(sheet, method: img.QuantizeMethod.octree)),
      );

    final result = _runEncoder([
      '-quiet',
      '-lossless',
      png.path,
      '-o',
      target.path,
    ]);

    png.deleteSync();

    if (result.exitCode != 0) {
      throw AtlasException(
        '$_executable could not encode the sheet ${target.path}: '
        '${result.stderr}',
      );
    }
  }

  img.Image _composeSheet(Map<String, AtlasShotCell> cells) {
    final rectangles = cells.values;
    final sheet = img.Image(
      width: rectangles.map((cell) => cell.left + cell.width).max,
      height: rectangles.map((cell) => cell.top + cell.height).max,
    );

    for (final MapEntry(key: shot, value: cell) in cells.entries) {
      img.compositeImage(
        sheet,
        _decodeShot(shot),
        dstX: cell.left,
        dstY: cell.top,
        blend: img.BlendMode.direct,
      );
    }

    return sheet;
  }

  ProcessResult _runEncoder(List<String> arguments) {
    try {
      return Process.runSync(_executable, arguments);
    } on ProcessException {
      throw const AtlasException(
        'No $_executable on the path to encode the shots of the bundle: '
        'brew install webp.',
      );
    }
  }

  img.Image _decodeShot(String shot) {
    final image = img.decodePng(_readShotBytes(shot));

    if (image == null) {
      throw AtlasException('The shot $shot is not a PNG.');
    }

    return image.convert(numChannels: 3);
  }

  Uint8List _readShotBytes(String shot) {
    return File(_paths.resolveShotPath(shot)).readAsBytesSync();
  }
}
