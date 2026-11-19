import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';

import 'test_utils/add_test_headless_hashes.dart';
import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/test_atlas_root.dart';

const _flow = 'settings_atlas';
const _variant = 'profileEdited';
const _anchor = '2026-10-06T09:00:00.000Z';
const _launchedAt = '2026-10-06T13:00:44.058Z';
const _laterLaunchedAt = '2026-10-06T14:12:05.310Z';
final _uk = fakeAtlasLocales.first;
const _scrollDurationMs = 300;
const _scrollFrequency = 30;
const _scrollDy = -200;
const _tapFinder = {'by': 'valueKey', 'value': 'main_nav.tab.settings'};
const _sourcePath = 'lib/settings/settings_view.dart';
const _recordedSource = 'class SettingsView {}';
const _changedSource = 'class SettingsView { int a = 0; }';
const _otherSourcePath = 'lib/settings/settings_owner.dart';
const _appSetupPath = 'lib/app/app_setup.dart';
const _validatorPath = 'lib/app/input_validator.dart';
const _devEntryPath = 'lib/entries/main_alt.dart';
const _mainPath = 'lib/main.dart';
const _stubFlutterVersion = '9.9.9';
const _flutterVersionStub =
    '''
#!/bin/sh
echo '{"frameworkVersion": "$_stubFlutterVersion"}'
''';
const _missingMainAnchor = 'AppSetup.schedulePostStartupTasks();';
const _mainWithoutPostStartupTasks = '''
void main(List<String> entryArg) async {
  await AppSetup.initialize(flavor);
  runApp(const App());
}
''';
final _recordedManifest = {
  _sourcePath: testSourceHash.hashSource(_recordedSource),
};
final _changedManifest = {
  ..._recordedManifest,
  _otherSourcePath: testSourceHash.hashSource(_recordedSource),
};
const _firstStageHash = '712bd761ea00';
const _frameHashes = [_firstStageHash, '8af1ab1383cb'];
const _endFrameHash = 'd9549e29368d';
const _launchRecord = {
  'kind': 'launch',
  'features': ['profile'],
};
const _startupRecord = {'kind': 'state', 'owner': 'AppOwner'};
const _screenViewRecord = {'kind': 'analytics', 'name': 'screen_opened'};
const _profileRecord = {
  'kind': 'request',
  'method': 'GET',
  'path': '/users/current',
  'acceptLanguage': 'uk',
  'status': 200,
};
const _report = AtlasHeadlessReport(
  frameHashes: _frameHashes,
  endFrameHash: _endFrameHash,
  error: null,
  journals: [
    [_startupRecord],
    [_screenViewRecord],
    [_profileRecord],
  ],
  launch: _launchRecord,
);
const _stage = AtlasStage(
  label: 'settings tab',
  action: 'tap',
  journal: [],
  ok: true,
  target: _tapFinder,
  block: null,
  targetRect: null,
  screen: 'carts-route',
  designScreen: 'home/buyer',
  shot: null,
  error: null,
);

void main() {
  group('AtlasHeadless Tests', () {
    _atlasHeadlessInput_should_takeMomentsOfFirstStoredStage();
    _atlasHeadlessInput_should_keepFinderAndScrollTiming();
    _atlasHeadlessReport_should_matchBaselineOfSameHashes();
    _atlasHeadlessReport_should_notMatchBaselineOfOtherHash();
    _atlasHeadlessReport_should_readStageJournalAfterStageFrame();
    _atlasHeadlessReport_should_assembleStagesFromReportsOfTheir();
    _atlasHeadlessReport_should_assembleErrorOfFirstFailedMoments();
    _atlasHeadlessReport_should_leaveErrorPastStageOfMoments();
    _atlasHeadlessReport_should_notMatchStageWithoutFrame();
    _atlasHeadlessReport_should_readWhatItWrote();
    _atlasHeadless_should_walkEveryGroupOfStageMoments();
    _atlasHeadless_should_walkSnapshotWithoutStagesOnFixedMoments();
    _atlasHeadless_should_handWalkTextsSnapshotRecorded();
    _atlasHeadless_should_handWalkImagesMockChooserGave();
    _atlasHeadless_should_handNoPickedImagesWhenDevicePicked();
    _atlasHeadless_should_handNoPickedImagesWhenMockChooserGaveNone();
    _atlasHeadlessInput_should_readPickedImagesItWrote();
    _atlasHeadless_should_dropStagesWhoseSourcesBaselineHolds();
    _atlasHeadless_should_keepStagesOfMatchedSourcesBesideManifest();
    _atlasHeadless_should_dropEndOfStagelessSnapshotBaselineHolds();
    _atlasHeadless_should_keepEndOfStagelessSnapshotBaselineHoldsAsRecorded();
    _atlasHeadlessReport_should_dropEndFrameOfUncomparableEnd();
    _atlasHeadless_should_tellStubbedDeclarations();
    _atlasHeadless_should_readShotCommitPastJournalRewrites();
    _atlasHeadless_should_readShotCommitPastHeadlessHashRewrites();
    _atlasHeadless_should_readRendererOfPinnedFlutter();
    _atlasHeadless_should_readRendererWithoutFvmConfig();
    _atlasHeadless_should_readNewestAncestorHoldingRecordedSources();
    _atlasHeadless_should_keepShotCommitWhenNoAncestorHoldsSources();
    _atlasHeadless_should_failWhenMainLacksAnchorOfPatch();
  });
}

void _atlasHeadlessInput_should_takeMomentsOfFirstStoredStage() {
  test(
    'AtlasHeadlessInput should take moments of first stored stage',
    () async {
      await TestAtlasRoot.run((root) {
        _writeFlow(root);
        AtlasSnapshotStore(root.paths).write(
          createAtlasSnapshot(
            flow: _flow,
            variant: _variant,
            stages: [_withMoments(_stage)],
          ),
        );

        final input = _readInput(root);

        expect(input.anchor, _anchor);
        expect(input.launchedAt, _launchedAt);
        expect(
          input.reportPath,
          p.absolute(
            root.paths.resolveHeadlessReportPath(
              flow: _flow,
              variant: _variant,
              locale: _uk,
            ),
          ),
        );
      });
    },
  );
}

void _atlasHeadlessInput_should_keepFinderAndScrollTiming() {
  test('AtlasHeadlessInput should keep finder and scroll timing', () async {
    await TestAtlasRoot.run((root) {
      _writeFlow(root);

      final input = _readInput(root);
      final [tap, scroll] = input.steps;

      expect(input.anchor, isNull);
      expect(tap['finder'], _tapFinder);
      expect(scroll['durationMs'], _scrollDurationMs);
      expect(scroll['frequency'], _scrollFrequency);
    });
  });
}

void _atlasHeadlessReport_should_matchBaselineOfSameHashes() {
  test('AtlasHeadlessReport should match baseline of same hashes', () {
    const baseline = AtlasHeadlessReport(
      frameHashes: _frameHashes,
      endFrameHash: _endFrameHash,
      error: null,
    );
    final isStageMatched = _report.hasSameFrame(baseline, 1);
    final isEndMatched = _report.hasSameEndFrame(baseline);

    expect(isStageMatched, isTrue);
    expect(isEndMatched, isTrue);
  });
}

void _atlasHeadlessReport_should_notMatchBaselineOfOtherHash() {
  test('AtlasHeadlessReport should not match baseline of other hash', () {
    final baseline = AtlasHeadlessReport(
      frameHashes: [_firstStageHash, 'ffffffffffff'],
      endFrameHash: null,
      error: 'Step "settings tab" failed',
    );
    final isStageMatched = _report.hasSameFrame(baseline, 1);
    final isEndMatched = _report.hasSameEndFrame(baseline);

    expect(isStageMatched, isFalse);
    expect(isEndMatched, isFalse);
  });
}

void _atlasHeadlessReport_should_readStageJournalAfterStageFrame() {
  test('AtlasHeadlessReport should read stage journal after stage frame', () {
    const report = AtlasHeadlessReport(
      frameHashes: _frameHashes,
      endFrameHash: _endFrameHash,
      error: null,
      journals: [
        [_startupRecord],
        [_screenViewRecord],
        [_profileRecord],
      ],
      launch: _launchRecord,
    );
    final firstJournal = report.tryReadStageJournal(0);
    final lastJournal = report.tryReadStageJournal(1);
    final missingJournal = report.tryReadStageJournal(2);

    expect(firstJournal, [_launchRecord, _screenViewRecord]);
    expect(lastJournal, [_profileRecord]);
    expect(missingJournal, isNull);
  });
}

void _atlasHeadlessReport_should_assembleStagesFromReportsOfTheir() {
  test('AtlasHeadlessReport should assemble stages from reports of their', () {
    const firstMoments = AtlasHeadlessReport(
      frameHashes: [_firstStageHash, 'aaaaaaaaaaaa'],
      endFrameHash: 'bbbbbbbbbbbb',
      error: null,
      journals: [
        [_startupRecord],
        [_screenViewRecord],
        [],
      ],
      launch: _launchRecord,
    );
    const secondMoments = AtlasHeadlessReport(
      frameHashes: ['cccccccccccc', 'dddddddddddd'],
      endFrameHash: _endFrameHash,
      error: null,
      journals: [
        [],
        [],
        [_profileRecord],
      ],
    );
    final report = AtlasHeadlessReport.assemble([firstMoments, secondMoments]);

    expect(report.frameHashes, [_firstStageHash, 'dddddddddddd']);
    expect(report.endFrameHash, _endFrameHash);
    expect(report.tryReadStageJournal(0), [_launchRecord, _screenViewRecord]);
    expect(report.tryReadStageJournal(1), [_profileRecord]);
  });
}

void _atlasHeadlessReport_should_assembleErrorOfFirstFailedMoments() {
  test('AtlasHeadlessReport should assemble error of first failed moments', () {
    const failedError = 'step 1 tap: no main_nav.tab.settings';
    const firstMoments = AtlasHeadlessReport(
      frameHashes: [],
      endFrameHash: null,
      error: failedError,
    );
    const secondMoments = AtlasHeadlessReport(
      frameHashes: ['cccccccccccc', 'dddddddddddd'],
      endFrameHash: _endFrameHash,
      error: null,
    );
    final report = AtlasHeadlessReport.assemble([firstMoments, secondMoments]);

    expect(report.error, failedError);
    expect(report.frameHashes, [null, 'dddddddddddd']);
  });
}

void _atlasHeadlessReport_should_notMatchStageWithoutFrame() {
  test('AtlasHeadlessReport should not match stage without frame', () {
    const baseline = AtlasHeadlessReport(
      frameHashes: [null],
      endFrameHash: _endFrameHash,
      error: null,
    );
    const current = AtlasHeadlessReport(
      frameHashes: [null],
      endFrameHash: _endFrameHash,
      error: null,
    );
    final isMissingMatched = _report.hasSameFrame(baseline, 2);
    final isNullMatched = current.hasSameFrame(baseline, 0);

    expect(isMissingMatched, isFalse);
    expect(isNullMatched, isFalse);
  });
}

void _atlasHeadlessReport_should_readWhatItWrote() {
  test('AtlasHeadlessReport should read what it wrote', () async {
    await TestAtlasRoot.run((root) {
      final path = root.paths.resolveHeadlessReportPath(
        flow: _flow,
        variant: _variant,
        locale: _uk,
        isBaseline: true,
      );

      root.writeHeadlessReport(
        _report,
        flow: _flow,
        variant: _variant,
        isBaseline: true,
      );

      final report = AtlasHeadlessReport.tryReadFile(path);

      expect(report?.frameHashes, _frameHashes);
      expect(report?.endFrameHash, _endFrameHash);
      expect(report?.error, isNull);
      expect(report?.journals, _report.journals);
      expect(report?.launch, _launchRecord);
    });
  });
}

void _atlasHeadless_should_walkEveryGroupOfStageMoments() {
  test('AtlasHeadless should walk every group of stage moments', () async {
    await TestAtlasRoot.run((root) {
      _writeFlow(root);
      AtlasSnapshotStore(root.paths).write(
        createAtlasSnapshot(
          flow: _flow,
          variant: _variant,
          stages: [
            _withMoments(_stage),
            _withMoments(_stage, launchedAt: _laterLaunchedAt),
            _withMoments(_stage),
          ],
        ),
      );

      final [first, second] = _readInputs(root);

      expect(first.launchedAt, _launchedAt);
      expect(first.momentsIndex, 0);
      expect(second.anchor, _anchor);
      expect(second.launchedAt, _laterLaunchedAt);
      expect(second.momentsIndex, 1);
      expect(second.reportPath, '${first.framesDirectory}.moments1.json');
      expect(second.walkName, '${first.id} on $_laterLaunchedAt');
    });
  });
}

void _atlasHeadless_should_walkSnapshotWithoutStagesOnFixedMoments() {
  test(
    'AtlasHeadless should walk snapshot without stages on fixed moments',
    () async {
      await TestAtlasRoot.run((root) {
        _writeFlow(root);
        AtlasSnapshotStore(root.paths).write(
          createAtlasSnapshot(flow: _flow, variant: _variant, stages: []),
        );

        final input = _readInput(root);

        expect(input.anchor, AtlasHeadless.stagelessMoments.anchor);
        expect(input.launchedAt, AtlasHeadless.stagelessMoments.launchedAt);
      });
    },
  );
}

void _atlasHeadless_should_dropStagesWhoseSourcesBaselineHolds() {
  test(
    'AtlasHeadless should drop stages whose sources baseline holds',
    () async {
      await TestAtlasRoot.run((root) {
        root.writeSource(_sourcePath, _changedSource);

        final frames = AtlasHeadless.baseline(root.paths)
            .readUncomparableFrames(
              _createSourcedSnapshot(manifest: const {}),
              baselineRootPath: root.paths.rootPath,
            );

        expect(frames.stages, {1});
        expect(frames.isEndUncomparable, isFalse);
      });
    },
  );
}

void _atlasHeadless_should_keepStagesOfMatchedSourcesBesideManifest() {
  test(
    'AtlasHeadless should keep stages of matched sources beside manifest',
    () async {
      await TestAtlasRoot.run((root) {
        root
          ..writeSource(_sourcePath, _recordedSource)
          ..writeSource(_otherSourcePath, _changedSource);

        final frames = AtlasHeadless.baseline(root.paths)
            .readUncomparableFrames(
              _createSourcedSnapshot(manifest: _changedManifest),
              baselineRootPath: root.paths.rootPath,
            );

        expect(frames.stages, isEmpty);
      });
    },
  );
}

void _atlasHeadless_should_dropEndOfStagelessSnapshotBaselineHolds() {
  test(
    'AtlasHeadless should drop end of stageless snapshot baseline holds',
    () async {
      await TestAtlasRoot.run((root) {
        root.writeSource(_sourcePath, _changedSource);

        final frames = AtlasHeadless.baseline(root.paths)
            .readUncomparableFrames(
              _createStagelessSnapshot(),
              baselineRootPath: root.paths.rootPath,
            );

        expect(frames.isEndUncomparable, isTrue);
      });
    },
  );
}

void _atlasHeadless_should_keepEndOfStagelessSnapshotBaselineHoldsAsRecorded() {
  test('AtlasHeadless should keep end of stageless snapshot baseline holds as '
      'recorded', () async {
    await TestAtlasRoot.run((root) {
      root.writeSource(_sourcePath, _recordedSource);

      final frames = AtlasHeadless.baseline(root.paths).readUncomparableFrames(
        _createStagelessSnapshot(),
        baselineRootPath: root.paths.rootPath,
      );

      expect(frames.isEndUncomparable, isFalse);
    });
  });
}

void _atlasHeadlessReport_should_dropEndFrameOfUncomparableEnd() {
  test('AtlasHeadlessReport should drop end frame of uncomparable end', () {
    final report = _report.withoutFrames(
      (stages: const {}, isEndUncomparable: true),
      sourceHashes: null,
      commit: 'c0ffee000000',
    );

    expect(report.endFrameHash, isNull);
    expect(report.frameHashes, _frameHashes);
  });
}

AtlasSnapshot _createStagelessSnapshot() {
  return createAtlasSnapshot(
    flow: _flow,
    variant: _variant,
    manifest: _recordedManifest,
  );
}

void _atlasHeadless_should_tellStubbedDeclarations() {
  test('AtlasHeadless should tell stubbed declarations', () {
    final isInitializeStubbed = fakeAtlasHeadlessSettings.isStubbedDeclaration(
      _appSetupPath,
      'AppSetup.initialize',
    );
    final isStartLanguageStubbed = fakeAtlasHeadlessSettings
        .isStubbedDeclaration(_appSetupPath, 'AppSetup.resolveLanguage');
    final isParseStubbed = fakeAtlasHeadlessSettings.isStubbedDeclaration(
      _validatorPath,
      'InputValidator.parse',
    );
    final isValidStubbed = fakeAtlasHeadlessSettings.isStubbedDeclaration(
      _validatorPath,
      'InputValidator.isValid',
    );
    final isEntryStubbed = fakeAtlasHeadlessSettings.isStubbedDeclaration(
      _devEntryPath,
      'main',
    );

    expect(isInitializeStubbed, isTrue);
    expect(isStartLanguageStubbed, isFalse);
    expect(isParseStubbed, isTrue);
    expect(isValidStubbed, isFalse);
    expect(isEntryStubbed, isTrue);
  });
}

AtlasSnapshot _createSourcedSnapshot({required Map<String, String> manifest}) {
  return createAtlasSnapshot(
    flow: _flow,
    variant: _variant,
    manifest: manifest,
    stages: [
      _stage,
      AtlasStage(
        label: _stage.label,
        action: _stage.action,
        journal: _stage.journal,
        ok: _stage.ok,
        target: _stage.target,
        block: _stage.block,
        targetRect: _stage.targetRect,
        screen: _stage.screen,
        designScreen: _stage.designScreen,
        shot: _stage.shot,
        error: _stage.error,
        sources: _recordedManifest,
      ),
    ],
  );
}

void _atlasHeadless_should_failWhenMainLacksAnchorOfPatch() {
  test('AtlasHeadless should fail when main lacks anchor of patch', () async {
    await TestAtlasRoot.run((root) async {
      _writeFlow(root);
      root.writeSource(_mainPath, _mainWithoutPostStartupTasks);

      final walk = AtlasHeadless(
        root.paths,
      ).run(AtlasDefinitions.read(root.paths).variants);

      await expectLater(
        walk,
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('finds no "$_missingMainAnchor"'),
          ),
        ),
      );
    });
  });
}

void _writeFlow(TestAtlasRoot root) {
  root.writeFlow(_flow, {
    'scenario': {'latency': 'fast'},
    'variants': {
      _variant: {
        'items': [
          {'action': 'tap', 'label': 'settings tab', 'finder': _tapFinder},
          {
            'action': 'scroll',
            'label': 'scroll the settings',
            'finder': {'by': 'valueKey', 'value': 'settings.screen.root'},
            'dx': 0,
            'dy': _scrollDy,
            'durationMs': _scrollDurationMs,
            'frequency': _scrollFrequency,
          },
        ],
      },
    },
  });
}

AtlasHeadlessInput _readInput(TestAtlasRoot root) {
  return _readInputs(root).single;
}

List<AtlasHeadlessInput> _readInputs(TestAtlasRoot root) {
  final variants = AtlasDefinitions.read(root.paths).variants;

  return AtlasHeadless(root.paths).readInputs(variants);
}

void _atlasHeadless_should_readShotCommitPastJournalRewrites() {
  test('AtlasHeadless should read shot commit past journal rewrites', () async {
    await TestAtlasRoot.run((root) {
      final snapshotPath = root.paths.resolveSnapshotPath(
        flow: _flow,
        variant: _variant,
        locale: _uk,
      );

      _runGit(root, ['init', '--quiet']);
      _writeJournaledSnapshot(root, journal: const [], shot: 'a.png');

      final shotCommit = _commit(root, 'capture');

      _writeJournaledSnapshot(root, journal: _journal, shot: 'a.png');
      _commit(root, 'rewrite the journal');

      final committedCommit = AtlasHeadless.tryReadSnapshotCommit(
        root.paths,
        snapshotPath,
      );

      _writeJournaledSnapshot(root, journal: const [], shot: 'a.png');

      final rewrittenCommit = AtlasHeadless.tryReadSnapshotCommit(
        root.paths,
        snapshotPath,
      );

      _writeJournaledSnapshot(root, journal: _journal, shot: 'b.png');

      final reshotCommit = AtlasHeadless.tryReadSnapshotCommit(
        root.paths,
        snapshotPath,
      );

      expect(committedCommit, shotCommit);
      expect(rewrittenCommit, shotCommit);
      expect(reshotCommit, isNull);
    });
  });
}

void _atlasHeadless_should_readShotCommitPastHeadlessHashRewrites() {
  test(
    'AtlasHeadless should read shot commit past headless hash rewrites',
    () async {
      await TestAtlasRoot.run((root) {
        final store = AtlasSnapshotStore(root.paths);

        _runGit(root, ['init', '--quiet']);
        _writeJournaledSnapshot(root, journal: const [], shot: 'a.png');

        final shotCommit = _commit(root, 'capture');

        store.write(addTestHeadlessHashes(_readSnapshot(store)));
        _commit(root, 'record the headless hashes');

        final commit = AtlasHeadless.tryReadSnapshotCommit(
          root.paths,
          _resolveSnapshotPath(root),
        );

        expect(commit, shotCommit);
      });
    },
  );
}

AtlasSnapshot _readSnapshot(AtlasSnapshotStore store) {
  final snapshot = store.tryRead(flow: _flow, variant: _variant, locale: _uk);

  if (snapshot == null) {
    throw StateError('No snapshot of $_flow $_variant');
  }

  return snapshot;
}

void _atlasHeadless_should_readRendererOfPinnedFlutter() {
  test('AtlasHeadless should read renderer of pinned flutter', () async {
    await TestAtlasRoot.run((root) {
      root.writeFlutterConfig();

      final renderer = AtlasHeadless.readRenderer(root.paths);

      expect(renderer, 'Flutter $testFlutterVersion · ${Abi.current()}');
    });
  });
}

void _atlasHeadless_should_readRendererWithoutFvmConfig() {
  test('AtlasHeadless should read renderer without fvm config', () async {
    final scriptDirectory = Directory.systemTemp.createTempSync(
      'atlas-flutter-',
    );
    final script = File(p.join(scriptDirectory.path, 'flutter_stub'))
      ..writeAsStringSync(_flutterVersionStub);

    Process.runSync('chmod', ['+x', script.path]);

    try {
      await TestAtlasRoot.runWith(
        project: FakeAtlasProject(commandPrefix: [script.path]),
        (root) {
          final renderer = AtlasHeadless.readRenderer(root.paths);

          expect(renderer, 'Flutter $_stubFlutterVersion · ${Abi.current()}');
        },
      );
    } finally {
      scriptDirectory.deleteSync(recursive: true);
    }
  });
}

void _atlasHeadless_should_readNewestAncestorHoldingRecordedSources() {
  test(
    'AtlasHeadless should read newest ancestor holding recorded sources',
    () async {
      await TestAtlasRoot.run((root) {
        _runGit(root, ['init', '--quiet']);
        root.writeSource(_sourcePath, _recordedSource);
        _commit(root, 'add the view');
        root.writeSource(_otherSourcePath, _recordedSource);

        final sourcesCommit = _commit(root, 'add the owner');

        root.writeSource(_sourcePath, _changedSource);
        _commit(root, 'change the view');
        _writeJournaledSnapshot(
          root,
          journal: const [],
          shot: 'a.png',
          sources: _recordedManifest,
        );
        _commit(root, 'capture');

        final commit = AtlasHeadless.tryReadSnapshotCommit(
          root.paths,
          _resolveSnapshotPath(root),
        );

        expect(commit, sourcesCommit);
      });
    },
  );
}

void _atlasHeadless_should_keepShotCommitWhenNoAncestorHoldsSources() {
  test(
    'AtlasHeadless should keep shot commit when no ancestor holds sources',
    () async {
      await TestAtlasRoot.run((root) {
        _runGit(root, ['init', '--quiet']);
        root.writeSource(_sourcePath, _changedSource);
        _commit(root, 'add the view');
        _writeJournaledSnapshot(
          root,
          journal: const [],
          shot: 'a.png',
          sources: _recordedManifest,
        );

        final shotCommit = _commit(root, 'capture');
        final commit = AtlasHeadless.tryReadSnapshotCommit(
          root.paths,
          _resolveSnapshotPath(root),
        );

        expect(commit, shotCommit);
      });
    },
  );
}

String _resolveSnapshotPath(TestAtlasRoot root) {
  return root.paths.resolveSnapshotPath(
    flow: _flow,
    variant: _variant,
    locale: _uk,
  );
}

void _atlasHeadless_should_handWalkImagesMockChooserGave() {
  test('AtlasHeadless should hand walk images mock chooser gave', () async {
    await TestAtlasRoot.run((root) {
      _writeFlow(root);
      _writePickedImagesSnapshot(root, pick: _mockPick);

      final input = _readInput(root);

      expect(input.recordedUploads?.toJson(), _recordedUploads.toJson());
    });
  });
}

void _atlasHeadless_should_handNoPickedImagesWhenDevicePicked() {
  test(
    'AtlasHeadless should hand no picked images when device picked',
    () async {
      await TestAtlasRoot.run((root) {
        _writeFlow(root);
        _writePickedImagesSnapshot(root, pick: _devicePick);

        final input = _readInput(root);

        expect(input.recordedUploads, isNull);
      });
    },
  );
}

void _atlasHeadless_should_handNoPickedImagesWhenMockChooserGaveNone() {
  test(
    'AtlasHeadless should hand no picked images when mock chooser gave none',
    () async {
      await TestAtlasRoot.run((root) {
        _writeFlow(root);
        _writePickedImagesSnapshot(root, pick: _emptyMockPick);

        final input = _readInput(root);

        expect(input.recordedUploads, isNull);
      });
    },
  );
}

void _atlasHeadlessInput_should_readPickedImagesItWrote() {
  test('AtlasHeadlessInput should read picked images it wrote', () {
    final input = AtlasHeadlessInput(
      id: '$_flow $_variant',
      flow: _flow,
      variant: _variant,
      scenario: {},
      steps: [],
      locale: _uk,
      reportPath: 'report.json',
      anchor: _anchor,
      launchedAt: _launchedAt,
      recordedUploads: _recordedUploads,
    );
    final read = AtlasHeadlessInput.fromJson(
      jsonDecode(jsonEncode(input.toJson())) as Map<String, Object?>,
    );

    expect(read.recordedUploads?.toJson(), _recordedUploads.toJson());
  });
}

const _mockPick = {
  'kind': 'device',
  'call': 'pickGalleryImages',
  'answer': 2,
  'limit': 6,
  'isDeviceAnswer': false,
};
const _emptyMockPick = {
  'kind': 'device',
  'call': 'pickGalleryImages',
  'answer': 0,
  'limit': 6,
  'isDeviceAnswer': false,
};
const _devicePick = {
  'kind': 'device',
  'call': 'pickGalleryImages',
  'answer': 2,
  'limit': 6,
  'isDeviceAnswer': true,
};
const _recordedUploads = AtlasHeadlessUploads(
  uploads: [
    (original: 160045, preview: 96032, width: 1200, height: 1600),
    (original: 164033, preview: 98101, width: 1600, height: 1200),
  ],
);

void _writePickedImagesSnapshot(
  TestAtlasRoot root, {
  required Map<String, Object?> pick,
}) {
  AtlasSnapshotStore(root.paths).write(
    createAtlasSnapshot(
      flow: _flow,
      variant: _variant,
      stages: [
        _withMoments(_stage, journal: [pick]),
        _withMoments(
          _stage,
          journal: [
            for (final (:original, :preview, width: _, height: _)
                in _recordedUploads.uploads.reversed)
              {
                'kind': 'request',
                'method': 'POST',
                'path': '/media/uploads',
                'body': {
                  'original': {'size': original},
                  'preview': {'size': preview},
                },
              },
            {
              'kind': 'socket',
              'method': 'POST',
              'path': '/inbox/threads/mock-cart-9001/message',
              'body': {
                'message': {
                  'attachments': [
                    for (final (:original, :width, :height, preview: _)
                        in _recordedUploads.uploads)
                      {
                        'type': 'image',
                        'size': original,
                        'width': width,
                        'height': height,
                      },
                  ],
                },
              },
            },
          ],
        ),
      ],
    ),
  );
}

AtlasStage _withMoments(
  AtlasStage stage, {
  String launchedAt = _launchedAt,
  List<String> texts = const [],
  List<Object?>? journal,
}) {
  return AtlasStage(
    label: stage.label,
    action: stage.action,
    journal: journal ?? stage.journal,
    ok: stage.ok,
    target: stage.target,
    block: stage.block,
    targetRect: stage.targetRect,
    screen: stage.screen,
    designScreen: stage.designScreen,
    shot: stage.shot,
    error: stage.error,
    anchor: _anchor,
    launchedAt: launchedAt,
    texts: texts,
  );
}

const _journal = [
  {'kind': 'request', 'method': 'GET', 'path': '/users/current', 'status': 200},
];

void _writeJournaledSnapshot(
  TestAtlasRoot root, {
  required List<Object?> journal,
  required String shot,
  Map<String, String> sources = const {},
}) {
  AtlasSnapshotStore(root.paths).write(
    createAtlasSnapshot(
      flow: _flow,
      variant: _variant,
      stages: [
        AtlasStage(
          label: _stage.label,
          action: _stage.action,
          journal: journal,
          ok: true,
          target: _tapFinder,
          block: null,
          targetRect: null,
          screen: null,
          designScreen: null,
          shot: shot,
          error: null,
          sources: sources,
        ),
      ],
    ),
  );
}

String _commit(TestAtlasRoot root, String message) {
  _runGit(root, ['add', '--all']);
  _runGit(root, [
    '-c',
    'user.name=test',
    '-c',
    'user.email=test@example.com',
    'commit',
    '--quiet',
    '--no-verify',
    '-m',
    message,
  ]);

  return _runGit(root, ['rev-parse', 'HEAD']);
}

String _runGit(TestAtlasRoot root, List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    workingDirectory: root.paths.rootPath,
  );

  expect(result.exitCode, 0, reason: '${result.stderr}');

  return '${result.stdout}'.trim();
}

void _atlasHeadless_should_handWalkTextsSnapshotRecorded() {
  test('AtlasHeadless should hand walk texts snapshot recorded', () async {
    await TestAtlasRoot.run((root) {
      _writeFlow(root);
      AtlasSnapshotStore(root.paths).write(
        createAtlasSnapshot(
          flow: _flow,
          variant: _variant,
          stages: [
            _withMoments(_stage, texts: const ['10:00']),
          ],
          end: const AtlasEnd(
            screen: null,
            designScreen: null,
            shot: null,
            texts: ['Готово'],
          ),
        ),
      );

      final input = _readInput(root);

      expect(input.recordedTexts, ['10:00', 'Готово']);
    });
  });
}

void _atlasHeadlessReport_should_leaveErrorPastStageOfMoments() {
  test('AtlasHeadlessReport should leave error past stage of moments', () {
    const firstMoments = AtlasHeadlessReport(
      frameHashes: [_firstStageHash],
      endFrameHash: null,
      error: 'step 2 tap: no main_nav.tab.settings',
    );
    const secondMoments = AtlasHeadlessReport(
      frameHashes: ['cccccccccccc', 'dddddddddddd'],
      endFrameHash: _endFrameHash,
      error: null,
    );
    final report = AtlasHeadlessReport.assemble([firstMoments, secondMoments]);

    expect(report.error, isNull);
    expect(report.frameHashes, [_firstStageHash, 'dddddddddddd']);
  });
}
