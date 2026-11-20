/// The headless walk of a project: the body of the `flutter test` entry that
/// `AtlasHeadlessSettings.entryMain` names.
///
/// The library reaches `flutter_test`, so only that entry imports it. The
/// entry file of the atlas imports `flutter_automation_atlas.dart`, which runs
/// in the Dart VM.
library;

export 'package:flutter_automation_atlas/src/atlas_headless_app.dart';
export 'package:flutter_automation_atlas/src/run_atlas_headless_suite.dart'
    show runAtlasHeadlessSuite;
