import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';

import 'create_shot_snapshot.dart';
import 'test_atlas_root.dart';

const _tapStep = {
  'action': 'tap',
  'label': 'open',
  'finder': {'by': 'text', 'value': 'open'},
};

void writeShotStore(
  TestAtlasRoot root, {
  required String stageShot,
  required String? endShot,
}) {
  root
    ..writePublishedVariants({
      'shop_flow': ['shopFromSearch'],
    })
    ..writeFlow('shop_flow', {
      'title': {'en': 'Shop', 'uk': 'Магазин'},
      'variants': {
        'shopFromSearch': {
          'items': [_tapStep],
        },
      },
    });

  AtlasSnapshotStore(
    root.paths,
  ).write(createShotSnapshot(stageShot: stageShot, endShot: endShot));
}
