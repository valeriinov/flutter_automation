/// The mock replay of a project: the body of the `flutter test` file that
/// `AtlasProject.mockReplayEntry` names.
///
/// The library reaches the mock of the app, which imports Flutter, so only
/// that test file imports it. The entry file of the atlas imports
/// `flutter_automation_atlas.dart`, which runs in the Dart VM.
library;

export 'package:flutter_automation_atlas/src/atlas_mock_session.dart';
export 'package:flutter_automation_atlas/src/run_atlas_mock_replay.dart'
    show AtlasMockApisBuilder, isAtlasMockReplayRun, runAtlasMockReplay;
