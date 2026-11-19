import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_encoder.dart';

import 'test_utils/test_atlas_root.dart';

const _tallShot = '000000000000';
const _firstSmallShot = '111111111111';
const _secondSmallShot = '222222222222';
const _thirdSmallShot = '333333333333';
const _wrappedSmallShot = '444444444444';
const _smallShots = [
  _firstSmallShot,
  _secondSmallShot,
  _thirdSmallShot,
  _wrappedSmallShot,
];
const _shots = [_tallShot, ..._smallShots];
const _tallShotWidth = 2;
const _tallShotHeight = 3;
const _notPng = [1, 2, 3, 4];
const _webpDataUriPrefix = 'data:image/webp;base64,';
const _cachedWebp = [5, 6, 7, 8];
const _webpFormatStart = 8;
const _webpFormatEnd = 12;
const _sheetWidth = 7;
const _sheetHeight = 4;

final _hasEncoder = _findEncoder();

void main() {
  group('AtlasShotWebpEncoder Tests', () {
    _atlasShotWebpEncoder_should_layShotsOutRowByRow();
    _atlasShotWebpEncoder_should_encodeSheetAsWebpDataUri();
    _atlasShotWebpEncoder_should_answerFromCache();
    _atlasShotWebpEncoder_should_nameShotThatIsNotPng();
  });
}

void _atlasShotWebpEncoder_should_layShotsOutRowByRow() {
  test('AtlasShotWebpEncoder should lay shots out row by row', () async {
    await TestAtlasRoot.run((root) {
      _writeShots(root);
      root.writeText(_resolveCachePath(root), '');

      final sheet = AtlasShotWebpEncoder(root.paths).encodeSheet(_shots);

      expect(
        sheet.cells.map((shot, cell) => MapEntry(shot, cell.toPageData())),
        {
          _tallShot: [0, 0, _tallShotWidth, _tallShotHeight],
          _firstSmallShot: [2, 0, 1, 1],
          _secondSmallShot: [4, 0, 1, 1],
          _thirdSmallShot: [6, 0, 1, 1],
          _wrappedSmallShot: [0, 3, 1, 1],
        },
      );
    });
  });
}

void _atlasShotWebpEncoder_should_encodeSheetAsWebpDataUri() {
  test('AtlasShotWebpEncoder should encode sheet as webp data uri', () async {
    await TestAtlasRoot.run((root) {
      _writeShots(root);

      final sheet = AtlasShotWebpEncoder(root.paths).encodeSheet(_shots);
      final webp = base64Decode(
        sheet.dataUri.substring(_webpDataUriPrefix.length),
      );
      final image = img.decodeWebP(webp);

      expect(sheet.dataUri, startsWith(_webpDataUriPrefix));
      expect(
        ascii.decode(webp.sublist(_webpFormatStart, _webpFormatEnd)),
        'WEBP',
      );
      expect(image?.width, _sheetWidth);
      expect(image?.height, _sheetHeight);
      expect(File(_resolveCachePath(root)).readAsBytesSync(), webp);
      expect(File('${_resolveCachePath(root)}.png').existsSync(), isFalse);
    });
  }, skip: !_hasEncoder);
}

void _atlasShotWebpEncoder_should_answerFromCache() {
  test('AtlasShotWebpEncoder should answer from cache', () async {
    await TestAtlasRoot.run((root) {
      _writeShots(root);
      root.writeText(_resolveCachePath(root), '');
      File(_resolveCachePath(root)).writeAsBytesSync(_cachedWebp);

      final sheet = AtlasShotWebpEncoder(root.paths).encodeSheet(_shots);

      expect(sheet.dataUri, '$_webpDataUriPrefix${base64Encode(_cachedWebp)}');
      expect(sheet.bytes, _cachedWebp);
      expect(sheet.fileName, '${sha1.convert(_cachedWebp)}.webp');
    });
  });
}

void _atlasShotWebpEncoder_should_nameShotThatIsNotPng() {
  test('AtlasShotWebpEncoder should name shot that is not png', () async {
    await TestAtlasRoot.run((root) {
      root.writeShot(_tallShot, _notPng);
      expect(
        () => AtlasShotWebpEncoder(root.paths).encodeSheet([_tallShot]),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            'The shot $_tallShot is not a PNG.',
          ),
        ),
      );
    });
  }, skip: !_hasEncoder);
}

void _writeShots(TestAtlasRoot root) {
  root.writeShot(
    _tallShot,
    img.encodePng(img.Image(width: _tallShotWidth, height: _tallShotHeight)),
  );

  for (final shot in _smallShots) {
    root.writeShot(shot, img.encodePng(img.Image(width: 1, height: 1)));
  }
}

String _resolveCachePath(TestAtlasRoot root) {
  final sheet = sha1.convert(utf8.encode(_shots.join(','))).toString();

  return p.join(root.paths.bundleShotCachePath, '$sheet.webp');
}

bool _findEncoder() {
  try {
    return Process.runSync('cwebp', ['-version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}
