import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';

import 'fake_atlas_project.dart';

const testAtlasDevice = 'iPhone 17 Pro · iOS 26.4';

const testAtlasDefHash = 'abcdef012345';

const _emptyEnd = AtlasEnd(screen: null, designScreen: null, shot: null);

AtlasSnapshot createAtlasSnapshot({
  required String flow,
  required String variant,
  String? locale,
  bool ok = true,
  String device = testAtlasDevice,
  String defHash = testAtlasDefHash,
  Map<String, String> manifest = const {},
  List<AtlasStage> stages = const [],
  AtlasEnd end = _emptyEnd,
}) {
  return AtlasSnapshot(
    flow: flow,
    variant: variant,
    locale: locale ?? fakeAtlasLocales.first,
    ok: ok,
    device: device,
    defHash: defHash,
    manifest: manifest,
    stages: stages,
    end: end,
  );
}
