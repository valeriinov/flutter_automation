import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';

void main() {
  group('AtlasTable Tests', () {
    _atlasTable_should_groupStageIndexesByVariant();
    _atlasTable_should_giveNoStagesEntryWithoutStages();
  });
}

void _atlasTable_should_groupStageIndexesByVariant() {
  test('AtlasTable should group stage indexes by variant', () {
    final data = AtlasTable.stagesData(const [
      (variantId: 'shop/search', index: 0),
      (variantId: 'shop/cart', index: 2),
      (variantId: 'shop/search', index: 1),
    ]);

    expect(data, {
      'stages': {
        'shop/search': [0, 1],
        'shop/cart': [2],
      },
    });
  });
}

void _atlasTable_should_giveNoStagesEntryWithoutStages() {
  test('AtlasTable should give no stages entry without stages', () {
    expect(AtlasTable.stagesData(const []), isEmpty);
  });
}
