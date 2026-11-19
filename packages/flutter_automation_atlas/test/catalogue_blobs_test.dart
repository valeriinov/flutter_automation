import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_mock/mock_catalogue.dart';

final _cover = 'a' * CatalogueBlobs.minLength;
final _image = 'b' * CatalogueBlobs.minLength;
final _shortText = 'c' * (CatalogueBlobs.minLength - 1);
final _onceText = 'd' * CatalogueBlobs.minLength;

void main() {
  group('CatalogueBlobs Tests', () {
    _catalogueBlobs_should_storeRepeatedLongStringsOnce();
    _catalogueBlobs_should_keepShortAndUniqueStringsInPlace();
    _catalogueBlobs_should_leaveDataWithoutRepeatsUntouched();
  });
}

void _catalogueBlobs_should_storeRepeatedLongStringsOnce() {
  test('CatalogueBlobs should store repeated long strings once', () {
    final data = {
      'flows': [
        {
          'cover': {'minBase64': _cover},
          'images': [_image, _cover],
        },
        {'image': _image},
      ],
    };
    final extracted = CatalogueBlobs.extract(data);

    expect(extracted, {
      'flows': [
        {
          'cover': {
            'minBase64': {CatalogueBlobs.referenceKey: 0},
          },
          'images': [
            {CatalogueBlobs.referenceKey: 1},
            {CatalogueBlobs.referenceKey: 0},
          ],
        },
        {
          'image': {CatalogueBlobs.referenceKey: 1},
        },
      ],
      CatalogueBlobs.blobsKey: [_cover, _image],
    });
  });
}

void _catalogueBlobs_should_keepShortAndUniqueStringsInPlace() {
  test('CatalogueBlobs should keep short and unique strings in place', () {
    final data = {
      'texts': [_shortText, _shortText, _onceText, _cover, _cover],
    };
    final extracted = CatalogueBlobs.extract(data);

    expect(extracted['texts'], [
      _shortText,
      _shortText,
      _onceText,
      {CatalogueBlobs.referenceKey: 0},
      {CatalogueBlobs.referenceKey: 0},
    ]);
    expect(extracted[CatalogueBlobs.blobsKey], [_cover]);
  });
}

void _catalogueBlobs_should_leaveDataWithoutRepeatsUntouched() {
  test('CatalogueBlobs should leave data without repeats untouched', () {
    final data = {
      'texts': [_shortText, _onceText],
    };
    final extracted = CatalogueBlobs.extract(data);

    expect(identical(extracted, data), isTrue);
  });
}
