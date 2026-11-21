import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_id.dart';

const _bytes = [1, 2, 3, 4];
const _sha256OfBytes =
    '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a';
const _sha1PrefixOfBytes = '12dada1fff4d';

void main() {
  group('AtlasShotId Tests', () {
    _atlasShotId_should_nameEqualBytesByTheSameSha256();
    _atlasShotId_should_acceptOnly64LowercaseHexDigits();
    _atlasContentHash_should_keepItsShortHash();
  });
}

void _atlasShotId_should_nameEqualBytesByTheSameSha256() {
  test('AtlasShotId should name equal bytes by the same sha256', () {
    final first = AtlasShotId.hashBytes(_bytes);
    final second = AtlasShotId.hashBytes(List.of(_bytes));

    expect(first, _sha256OfBytes);
    expect(second, first);
    expect(AtlasShotId.hashBytes(const [4, 3, 2, 1]), isNot(first));
  });
}

void _atlasShotId_should_acceptOnly64LowercaseHexDigits() {
  test('AtlasShotId should accept only 64 lowercase hex digits', () {
    expect(AtlasShotId.isValid(_sha256OfBytes), isTrue);
    expect(AtlasShotId.isValid(_sha1PrefixOfBytes), isFalse);
    expect(AtlasShotId.isValid(_sha256OfBytes.toUpperCase()), isFalse);
    expect(AtlasShotId.isValid('${_sha256OfBytes}0'), isFalse);
  });
}

void _atlasContentHash_should_keepItsShortHash() {
  test('AtlasContentHash should keep its short hash', () {
    expect(AtlasContentHash.hashBytes(_bytes), _sha1PrefixOfBytes);
  });
}
