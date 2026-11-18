import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_page_blobs.dart';

final _cover = 'a' * AtlasPageBlobs.minLength;
final _image = 'b' * AtlasPageBlobs.minLength;
final _shortText = 'c' * (AtlasPageBlobs.minLength - 1);
final _onceText = 'd' * AtlasPageBlobs.minLength;

void main() {
  group('AtlasPageBlobs Tests', () {
    _atlasPageBlobs_should_storeRepeatedLongStringsOnce();
    _atlasPageBlobs_should_keepShortAndUniqueStringsInPlace();
    _atlasPageBlobs_should_leaveDataWithoutRepeatsUntouched();
  });
}

void _atlasPageBlobs_should_storeRepeatedLongStringsOnce() {
  test('AtlasPageBlobs should store repeated long strings once', () {
    final data = {
      'flows': [
        {
          'cover': {'minBase64': _cover},
          'images': [_image, _cover],
        },
        {'image': _image},
      ],
    };
    final extracted = AtlasPageBlobs.extract(data);

    expect(extracted, {
      'flows': [
        {
          'cover': {
            'minBase64': {AtlasPageBlobs.referenceKey: 0},
          },
          'images': [
            {AtlasPageBlobs.referenceKey: 1},
            {AtlasPageBlobs.referenceKey: 0},
          ],
        },
        {
          'image': {AtlasPageBlobs.referenceKey: 1},
        },
      ],
      AtlasPageBlobs.blobsKey: [_cover, _image],
    });
  });
}

void _atlasPageBlobs_should_keepShortAndUniqueStringsInPlace() {
  test('AtlasPageBlobs should keep short and unique strings in place', () {
    final data = {
      'texts': [_shortText, _shortText, _onceText, _cover, _cover],
    };
    final extracted = AtlasPageBlobs.extract(data);

    expect(extracted['texts'], [
      _shortText,
      _shortText,
      _onceText,
      {AtlasPageBlobs.referenceKey: 0},
      {AtlasPageBlobs.referenceKey: 0},
    ]);
    expect(extracted[AtlasPageBlobs.blobsKey], [_cover]);
  });
}

void _atlasPageBlobs_should_leaveDataWithoutRepeatsUntouched() {
  test('AtlasPageBlobs should leave data without repeats untouched', () {
    final data = {
      'texts': [_shortText, _onceText],
    };
    final extracted = AtlasPageBlobs.extract(data);

    expect(identical(extracted, data), isTrue);
  });
}
