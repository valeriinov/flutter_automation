import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';

import 'fake_atlas_project.dart';

AtlasDeclarations readTestDeclarations(String source) {
  return AtlasDeclarations.read(
    source,
    themeClassPattern: fakeAtlasStaleSettings.themeClassPattern,
    themeValueClassPattern: fakeAtlasStaleSettings.themeValueClassPattern,
  );
}
