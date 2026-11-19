import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_diff.dart';

import 'test_utils/create_atlas_snapshot.dart';

void main() {
  group('AtlasSnapshotDiff Tests', () {
    _atlasSnapshotDiff_should_describeEndTextsChange();
    _atlasSnapshotDiff_should_describeNoChangesForEqualEndTexts();
  });
}

void _atlasSnapshotDiff_should_describeEndTextsChange() {
  test('AtlasSnapshotDiff should describe end texts change', () {
    final lines = AtlasSnapshotDiff.describe(
      previous: _createSnapshot(const ['Кошики']),
      next: _createSnapshot(const ['Кошики', 'Кошик → Оплата']),
    );

    expect(lines, ['~ end: texts']);
  });
}

void _atlasSnapshotDiff_should_describeNoChangesForEqualEndTexts() {
  test('AtlasSnapshotDiff should describe no changes for equal end texts', () {
    final lines = AtlasSnapshotDiff.describe(
      previous: _createSnapshot(const ['Кошики']),
      next: _createSnapshot(const ['Кошики']),
    );

    expect(lines, ['no changes']);
  });
}

AtlasSnapshot _createSnapshot(List<String> endTexts) {
  return createAtlasSnapshot(
    flow: 'cart_search',
    variant: 'cartsFound',
    end: AtlasEnd(
      screen: 'carts-route',
      designScreen: null,
      shot: null,
      texts: endTexts,
    ),
  );
}
