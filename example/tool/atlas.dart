import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';

import 'example_atlas_project.dart';

/// Entry point of the atlas: `fvm dart run tool/atlas.dart stale`.
Future<void> main(List<String> args) {
  return runAtlas(args, const ExampleAtlasProject());
}
