import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_app.dart';
import 'package:flutter_automation_atlas/src/run_atlas_headless_suite.dart';

import 'test_utils/fake_atlas_project.dart';

const _input = AtlasHeadlessInput(
  id: 'shop_flow/shopFromSearch',
  flow: 'shop_flow',
  variant: 'shopFromSearch',
  scenario: {'mode': 'full'},
  steps: [],
  reportPath: 'unused/report.json',
  anchor: null,
  launchedAt: null,
  locale: 'uk',
);

void main() {
  group('AtlasHeadlessLaunch Tests', () {
    _atlasHeadlessLaunch_should_answerWidgetOfRunApp();
    _atlasHeadlessLaunch_should_runAfterMainAfterMain();
    _atlasHeadlessLaunch_should_throwWhenMainRunsNoApp();
    _atlasHeadlessLaunch_should_setLaunchedAtRightBeforeMain();
  });
  group('walkAtlasHeadlessInput Tests', () {
    _walkAtlasHeadlessInput_should_closeWalkWhenWalkThrows();
  });
}

void _atlasHeadlessLaunch_should_answerWidgetOfRunApp() {
  testWidgets('AtlasHeadlessLaunch should answer the widget of runApp', (
    tester,
  ) async {
    const app = SizedBox();

    final root = await _createLaunch().runMain(tester, () async {
      AtlasHeadlessLaunch.runApp(app);
    });

    expect(root, same(app));
  });
}

void _atlasHeadlessLaunch_should_runAfterMainAfterMain() {
  testWidgets('AtlasHeadlessLaunch should run afterMain after main', (
    tester,
  ) async {
    final calls = <String>[];

    await _createLaunch().runMain(tester, () async {
      calls.add('main');
      AtlasHeadlessLaunch.runApp(const SizedBox());
    }, afterMain: () async => calls.add('afterMain'));

    expect(calls, ['main', 'afterMain']);
  });
}

void _atlasHeadlessLaunch_should_throwWhenMainRunsNoApp() {
  testWidgets('AtlasHeadlessLaunch should throw when main runs no app', (
    tester,
  ) async {
    AtlasHeadlessLaunch.runApp(const SizedBox());

    await expectLater(
      _createLaunch().runMain(tester, () async {}),
      throwsStateError,
    );
  });
}

void _atlasHeadlessLaunch_should_setLaunchedAtRightBeforeMain() {
  testWidgets('AtlasHeadlessLaunch should set launchedAt right before main', (
    tester,
  ) async {
    final launch = _createLaunch();
    final created = launch.launchedAt;
    DateTime? launchedAtInMain;

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await launch.runMain(tester, () async {
      launchedAtInMain = launch.launchedAt;

      AtlasHeadlessLaunch.runApp(const SizedBox());
    });

    expect(launchedAtInMain?.isAfter(created), isTrue);
    expect(launch.launchedAt, launchedAtInMain);
  });
}

void _walkAtlasHeadlessInput_should_closeWalkWhenWalkThrows() {
  testWidgets('walkAtlasHeadlessInput should close the walk when the walk '
      'throws', (tester) async {
    bool isClosed = false;
    final app = AtlasHeadlessApp(
      schema: fakeAtlasJournalSchema,
      device: const AtlasHeadlessDevice(
        size: Size(390, 844),
        pixelRatio: 3,
        topInset: 47,
        bottomInset: 34,
        keyboardHeight: 336,
        platform: TargetPlatform.iOS,
      ),
      launch: (tester, launch) async => throw StateError('launch failure'),
      mock: () => throw StateError('no mock'),
      readScreenName: () => null,
      textEntryPause: (_) => Duration.zero,
      close: () => isClosed = true,
    );

    await expectLater(
      walkAtlasHeadlessInput(tester, _input, app),
      throwsStateError,
    );

    expect(isClosed, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

AtlasHeadlessLaunch _createLaunch() {
  return AtlasHeadlessLaunch(
    scenario: const {},
    moments: null,
    recordedValues: null,
  );
}
