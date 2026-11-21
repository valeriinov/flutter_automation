import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';

import 'create_atlas_snapshot.dart';

AtlasSnapshot createShotSnapshot({
  required String stageShot,
  required String? endShot,
  String flow = 'shop_flow',
  String variant = 'shopFromSearch',
}) {
  return createAtlasSnapshot(
    flow: flow,
    variant: variant,
    stages: [
      AtlasStage(
        label: 'open',
        action: 'tap',
        journal: const [],
        ok: true,
        target: null,
        block: null,
        targetRect: null,
        screen: null,
        designScreen: null,
        shot: stageShot,
        error: null,
      ),
    ],
    end: AtlasEnd(screen: null, designScreen: null, shot: endShot),
  );
}
