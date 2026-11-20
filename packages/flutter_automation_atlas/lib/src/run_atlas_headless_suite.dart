import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_app.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_walk.dart';

const _inputPath = String.fromEnvironment(AtlasHeadless.inputDefine);
const _encoder = JsonEncoder.withIndent('  ');

/// {@category Utils}
///
/// The body of the `flutter test` entry that [AtlasHeadless] runs. It walks
/// each input that the file named by [AtlasHeadless.inputDefine] holds in
/// [app]. It writes the headless report of each input and names a step that
/// failed in it.
///
/// The test runs on [AtlasHeadlessDevice.platform] of the [app].
void runAtlasHeadlessSuite(AtlasHeadlessApp app) {
  group('Atlas Headless Tests', () {
    for (final input in _readInputs()) {
      _atlasHeadless_should_recordEveryStage(input, app);
    }
  });
}

void _atlasHeadless_should_recordEveryStage(
  AtlasHeadlessInput input,
  AtlasHeadlessApp app,
) {
  testWidgets('Atlas headless should record every stage of ${input.walkName}', (
    tester,
  ) {
    return walkAtlasHeadlessInput(tester, input, app);
  }, variant: TargetPlatformVariant.only(app.device.platform));
}

/// {@category Utils}
///
/// Walks [input] in [app] and writes its report to
/// [AtlasHeadlessInput.reportPath]. It closes the walk whether the walk
/// succeeds or throws.
Future<void> walkAtlasHeadlessInput(
  WidgetTester tester,
  AtlasHeadlessInput input,
  AtlasHeadlessApp app,
) async {
  final walk = AtlasHeadlessWalk(tester, input, app);

  try {
    final report = await walk.walk();

    File(input.reportPath)
      ..createSync(recursive: true)
      ..writeAsStringSync(_encoder.convert(report.toJson()));
  } finally {
    await walk.close();
  }
}

List<AtlasHeadlessInput> _readInputs() {
  if (_inputPath.isEmpty) {
    return const [];
  }

  return AtlasHeadlessInput.readAll(File(_inputPath).readAsStringSync());
}
