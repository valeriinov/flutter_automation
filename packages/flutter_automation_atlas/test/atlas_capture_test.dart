import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_capture.dart';
import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replay.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_stage_scope.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_check.dart';

import 'test_utils/add_test_headless_hashes.dart';
import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/read_test_package_config.dart';
import 'test_utils/recording_stdout.dart';
import 'test_utils/test_atlas_root.dart';
import 'test_utils/test_automation_pubspec.dart';

final _uk = fakeAtlasLocales.first;
const _en = 'en';
const _flow = 'shop_flow';
const _stoppedVariant = 'shopFromExistingItem';
const _walkedVariant = 'shopFromSearch';
const _shotFileName = 'shop_flow_shot_0.png';
const _frameSize = 16;
const _failedLoadScenario = {
  'cart': {'failedLoadCount': 1},
};
const _runnerError = 'The app rejected the mock configuration';
const _walkFailure = 'The runner printed no report: Cannot connect.';
const _mainPath = 'lib/main.dart';
const _firstScreenPath = 'lib/first_screen.dart';
const _secondScreenPath = 'lib/second_screen.dart';
const _stagedLabels = ['open the search', 'open the cart', 'quote an item'];
const _addedLabels = [..._stagedLabels, 'send the quote'];
const _themePath = 'lib/theme/ui_sizes_ext.dart';
const _packageConfigPath = '.dart_tool/package_config.json';
const _analysisTimeout = Timeout(Duration(minutes: 2));
const _stageWidgets = ['FirstScreen', 'FirstScreen', 'SecondScreen'];
const _themedSecondScreenSource = '''
import 'package:flutter/widgets.dart';
import 'package:sample/theme/ui_sizes_ext.dart';

class SecondScreen extends StatelessWidget {
  const SecondScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: context.uiSizesExt.gapLg);
  }
}
''';
const _themeSource = '''
import 'package:flutter/widgets.dart';

class UiSizesExt {
  final double gapLg;

  const UiSizesExt({required this.gapLg});
}

extension UiSizesExtBuildContext on BuildContext {
  UiSizesExt get uiSizesExt => throw UnimplementedError();
}
''';
const _snapshotCommit = 'c0ffee000000';
const _frameHashes = ['a1b2c3d4e5f6', 'b2c3d4e5f6a1', 'c3d4e5f6a1b2'];
const _lastStageChangedFrameHashes = [
  'a1b2c3d4e5f6',
  'b2c3d4e5f6a1',
  'ffffffffffff',
];
const _endFrameHash = 'd4e5f6a1b2c3';
const _otherRenderer = 'Flutter 3.41.0 · linux_x64';
const _shotFrameHashes = ['a0a0a0a0a0a0', 'b0b0b0b0b0b0', 'c0c0c0c0c0c0'];
const _reshotFrameHashes = ['a1a1a1a1a1a1', 'b1b1b1b1b1b1', 'c1c1c1c1c1c1'];
const _reshotEndFrameHash = 'e1e1e1e1e1e1';
const _shotRecord = {'kind': 'analytics', 'name': 'shot'};
const _reshotRecord = {'kind': 'analytics', 'name': 'reshot'};
const _stagedScreens = [
  'first-route',
  'second-route',
  'second-route',
  'second-route',
];

void main() {
  group('AtlasCapture Tests', () {
    _atlasCapture_should_walkOnPastAReportNamingAnError();
    _atlasCapture_should_walkOnPastAWalkThatThrew();
    _atlasCapture_should_passWhenEveryWalkPassed();
    _atlasCapture_should_mergeShotStagesSoNothingIsStaleAfter();
    _atlasCapture_should_takeHashOfFileWidgetsPlaceOnShotStages();
    _atlasCapture_should_walkWholeWhenShotStagesDoNotLineUp();
    _atlasCapture_should_walkWholeWhenEveryStageIsSelected();
    _atlasCapture_should_keepStagesAfterTheCutAndTheirHashes();
    _atlasCapture_should_storeWalksOfALocaleBesideTheDefaultOnes();
    _atlasCapture_should_walkWholeWhenTheCutMissesAShotStageSource();
    _atlasCapture_should_mergeStagesAddedAtTheEnd();
    _atlasCapture_should_takeShotsOfTheDefaultVariantWalkedAlike();
    _atlasCapture_should_takeShotsOfTheStateOfVariantWalkedAlike();
    _atlasCapture_should_shootAnewWhereTheMainVariantStepsDiffer();
    _atlasCapture_should_rebaseStagesStaleFoundFreshSoNothingIsStale();
    _atlasCapture_should_keepHashesOfUnshotStagesNotFoundFresh();
    _atlasCapture_should_writeHeadlessHashesOfShotStagesOnly();
    _atlasCapture_should_writeNoHeadlessHashesOfReportOnOtherSources();
    _atlasCapture_should_writeNoHeadlessHashesOfStagesReportDoesNotHold();
    _atlasCapture_should_dropHeadlessHashesOfAnotherRenderer();
    _atlasCapture_should_walkNoHeadlessPassInAnotherLocale();
    _atlasCapture_should_walkWholeWhenTheMockAnswersAMergeOtherwise();
  });
}

void _atlasCapture_should_walkOnPastAReportNamingAnError() {
  test('AtlasCapture should walk on past a report naming an error', () async {
    await TestAtlasRoot.run((root) async {
      _writeFlow(root);
      root.writeFlutterConfig();

      final walked = <String>[];

      final isOk = await _capture(root, (variant, _, _) async {
        walked.add(variant.name);

        return _buildReport(
          variant.name,
          fields: variant.name == _stoppedVariant
              ? const {'error': _runnerError}
              : const {},
        );
      });

      expect(isOk, isFalse);
      expect(walked, [_stoppedVariant, _walkedVariant]);
      _expectOnlyTheWalkedVariantStored(root);
    });
  });
}

void _atlasCapture_should_walkOnPastAWalkThatThrew() {
  test('AtlasCapture should walk on past a walk that threw', () async {
    await TestAtlasRoot.run((root) async {
      _writeFlow(root);
      root.writeFlutterConfig();

      final walked = <String>[];

      final isOk = await _capture(root, (variant, _, _) async {
        walked.add(variant.name);

        if (variant.name == _stoppedVariant) {
          throw const AtlasException(_walkFailure);
        }

        return _buildReport(variant.name);
      });

      expect(isOk, isFalse);
      expect(walked, [_stoppedVariant, _walkedVariant]);
      _expectOnlyTheWalkedVariantStored(root);
    });
  });
}

void _atlasCapture_should_passWhenEveryWalkPassed() {
  test('AtlasCapture should pass when every walk passed', () async {
    await TestAtlasRoot.run((root) async {
      _writeFlow(root);
      root.writeFlutterConfig();

      final isOk = await _capture(
        root,
        (variant, _, _) async => _buildReport(variant.name),
      );

      final store = AtlasSnapshotStore(root.paths);

      expect(isOk, isTrue);
      expect(
        store.tryRead(flow: _flow, variant: _stoppedVariant, locale: _uk)?.ok,
        isTrue,
      );
      expect(
        store.tryRead(flow: _flow, variant: _walkedVariant, locale: _uk)?.ok,
        isTrue,
      );
    });
  });
}

void _atlasCapture_should_mergeShotStagesSoNothingIsStaleAfter() {
  test(
    'AtlasCapture should merge shot stages so nothing is stale after',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        root.writeFlutterConfig();
        _writeStagedSources(root);

        await _captureStaged(root, (_, _, _) async => _buildStagedReport());

        final previous = _readStaged(root);

        root.writeSource(
          _secondScreenPath,
          'class SecondScreen { int a = 0; }',
        );

        final staleness = await _checkStaged(root);

        final scopes = <List<String>>[];

        final isOk = await _captureStaged(
          root,
          _recordScopes(scopes),
          stages: staleness.stages,
        );

        final merged = _readStaged(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [1, 2]);
        expect(isOk, isTrue);
        expect(scopes, [
          ['--shoot', '1,2'],
        ]);
        expect(
          merged?.stages.firstOrNull?.toJson(),
          previous?.stages.firstOrNull?.toJson(),
        );
        expect(
          merged?.manifest[_secondScreenPath],
          isNot(previous?.manifest[_secondScreenPath]),
        );
        expect((await _checkStaged(root)).reason, AtlasStaleReason.fresh);
      });
    },
  );
}

void _atlasCapture_should_takeHashOfFileWidgetsPlaceOnShotStages() {
  test(
    'AtlasCapture should take hash of file widgets place on shot stages',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        root.writeFlutterConfig();
        _writeStagedSources(root);
        _writeThemedSources(root);

        await _captureStaged(root, (_, _, _) async => _buildThemedReport());

        final previous = _readStaged(root);

        root
          ..writeSource(_themePath, _themeSource.replaceAll('gapLg', 'gapXl'))
          ..writeSource(
            _secondScreenPath,
            _themedSecondScreenSource.replaceAll('gapLg', 'gapXl'),
          );

        final staleness = await _checkStaged(root);

        await _createCapture(root).captureWalks(
          AtlasDefinitions.read(root.paths).variants,
          device: testAtlasDevice,
          walker: _FakeWalker((_, _, _) async => _buildThemedReport()),
          stageSelections: {
            staleness.variant.id: (
              stages: staleness.stages,
              attributedPaths: staleness.attributedPaths,
              freshStages: staleness.freshStages,
            ),
          },
        );

        expect(staleness.stages, [1, 2]);
        expect(
          _readStaged(root)?.manifest[_themePath],
          isNot(previous?.manifest[_themePath]),
        );
        expect((await _checkStaged(root)).reason, AtlasStaleReason.fresh);
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasCapture_should_walkWholeWhenShotStagesDoNotLineUp() {
  test(
    'AtlasCapture should walk whole when shot stages do not line up',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        root.writeFlutterConfig();
        _writeStagedSources(root);

        await _captureStaged(root, (_, _, _) async => _buildStagedReport());

        root.writeSource(_firstScreenPath, 'class FirstScreen { int a = 0; }');

        final staleness = await _checkStaged(root);

        final scopes = <List<String>>[];

        await _captureStaged(
          root,
          _recordScopes(scopes, partialWalkFirstLabel: 'open the item'),
          stages: staleness.stages,
        );

        expect(staleness.stages, [0, 1]);
        expect(scopes, [
          ['--shoot', '0,1', '--until', '1'],
          <String>[],
        ]);
        expect((await _checkStaged(root)).reason, AtlasStaleReason.fresh);
      });
    },
  );
}

void _atlasCapture_should_walkWholeWhenEveryStageIsSelected() {
  test('AtlasCapture should walk whole when every stage is selected', () async {
    await TestAtlasRoot.run((root) async {
      _writeStagedFlow(root);
      root.writeFlutterConfig();
      _writeStagedSources(root);

      await _captureStaged(root, (_, _, _) async => _buildStagedReport());

      final scopes = <List<String>>[];

      await _captureStaged(root, _recordScopes(scopes), stages: [0, 1, 2]);

      expect(scopes, [<String>[]]);
    });
  });
}

void _atlasCapture_should_storeWalksOfALocaleBesideTheDefaultOnes() {
  test('AtlasCapture should store walks of a locale beside the default '
      'ones', () async {
    await TestAtlasRoot.run((root) async {
      _writeStagedFlow(root);
      root.writeFlutterConfig();
      _writeStagedSources(root);

      await _captureStaged(root, (_, _, _) async => _buildStagedReport());

      final ukSnapshot = _readStaged(root)?.toJson();

      final staleBeforeEnWalk = await _checkStaged(root, locale: _en);

      await _captureStaged(
        root,
        (_, _, _) async => _buildStagedReport(),
        locale: _en,
      );

      root.writeSource(_secondScreenPath, 'class SecondScreen { int a = 0; }');

      final enStaleness = await _checkStaged(root, locale: _en);

      final scopes = <List<String>>[];

      await _captureStaged(
        root,
        _recordScopes(scopes),
        stages: enStaleness.stages,
        locale: _en,
      );

      expect(staleBeforeEnWalk.reason, AtlasStaleReason.noSnapshot);
      expect(enStaleness.reason, AtlasStaleReason.stageCode);
      expect(scopes, [
        ['--shoot', '1,2'],
      ]);
      expect(_readStaged(root, locale: _en)?.locale, _en);
      expect(
        (await _checkStaged(root, locale: _en)).reason,
        AtlasStaleReason.fresh,
      );
      expect(_readStaged(root)?.toJson(), ukSnapshot);
      expect((await _checkStaged(root)).reason, AtlasStaleReason.stageCode);
    });
  });
}

void _atlasCapture_should_mergeStagesAddedAtTheEnd() {
  test('AtlasCapture should merge stages added at the end', () async {
    await TestAtlasRoot.run((root) async {
      _writeStagedFlow(root);
      root.writeFlutterConfig();
      _writeStagedSources(root);

      await _captureStaged(root, (_, _, _) async => _buildStagedReport());

      final previous = _readStaged(root);

      _writeStagedFlow(root, labels: _addedLabels);

      final staleness = await _checkStaged(root);

      final scopes = <List<String>>[];

      final isOk = await _captureStaged(root, (_, scope, _) async {
        scopes.add(scope.runnerArguments);

        return _buildStagedReport(labels: _addedLabels);
      }, stages: staleness.stages);

      final merged = _readStaged(root);

      expect(staleness.stages, [2, 3]);
      expect(isOk, isTrue);
      expect(scopes, [
        ['--shoot', '2,3'],
      ]);
      expect(merged?.stages.map((stage) => stage.label), _addedLabels);
      expect(
        merged?.stages.firstOrNull?.toJson(),
        previous?.stages.firstOrNull?.toJson(),
      );
      expect((await _checkStaged(root)).reason, AtlasStaleReason.fresh);
    });
  });
}

void _atlasCapture_should_takeShotsOfTheDefaultVariantWalkedAlike() {
  test(
    'AtlasCapture should take shots of the default variant walked alike',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeFlow(root, defaultVariant: _stoppedVariant);
        root.writeFlutterConfig();

        final (:mainShot, :walkedShot) = await _captureShotsOfBothVariants(
          root,
        );

        expect(mainShot, isNotNull);
        expect(walkedShot, mainShot);
      });
    },
  );
}

void _atlasCapture_should_takeShotsOfTheStateOfVariantWalkedAlike() {
  test(
    'AtlasCapture should take shots of the state of variant walked alike',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeFlow(
          root,
          walkedStateOf: _stoppedVariant,
          walkedScenario: _failedLoadScenario,
        );
        root.writeFlutterConfig();

        final (:mainShot, :walkedShot) = await _captureShotsOfBothVariants(
          root,
        );

        expect(mainShot, isNotNull);
        expect(walkedShot, mainShot);
      });
    },
  );
}

void _atlasCapture_should_shootAnewWhereTheMainVariantStepsDiffer() {
  test(
    'AtlasCapture should shoot anew where the main variant steps differ',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeFlow(
          root,
          walkedStateOf: _stoppedVariant,
          walkedLabel: 'quote a cart',
        );
        root.writeFlutterConfig();

        final (:mainShot, :walkedShot) = await _captureShotsOfBothVariants(
          root,
        );

        expect(walkedShot, isNot(mainShot));
      });
    },
  );
}

void _atlasCapture_should_rebaseStagesStaleFoundFreshSoNothingIsStale() {
  test(
    'AtlasCapture should rebase stages stale found fresh so nothing is stale',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        root.writeFlutterConfig();
        _writeStagedSources(root);

        await _captureStaged(root, _recordScopes([]));

        root.writeSource(_mainPath, 'void main() { print(0); }');
        _writeStagedHeadlessReports(
          root,
          currentFrameHashes: _lastStageChangedFrameHashes,
        );

        final staleness = await _checkStaged(
          root,
          snapshotCommit: _snapshotCommit,
        );

        await _captureStaged(
          root,
          _recordScopes([]),
          stages: staleness.stages,
          freshStages: staleness.freshStages,
        );

        expect(staleness.stages, [2]);
        expect(staleness.freshStages, [0, 1]);
        expect(staleness.unattributedPaths, [_mainPath]);
        expect((await _checkStaged(root)).reason, AtlasStaleReason.fresh);
      });
    },
  );
}

void _atlasCapture_should_keepHashesOfUnshotStagesNotFoundFresh() {
  test(
    'AtlasCapture should keep hashes of unshot stages not found fresh',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        root.writeFlutterConfig();
        _writeStagedSources(root);

        await _captureStaged(root, _recordScopes([]));

        final previous = _readStaged(root);

        root
          ..writeSource(_firstScreenPath, 'class FirstScreen { int a = 0; }')
          ..writeSource(_secondScreenPath, 'class SecondScreen { int b = 0; }');

        await _captureStaged(
          root,
          _recordScopes([]),
          stages: [0],
          freshStages: [2],
        );

        final merged = _readStaged(root);

        final staleness = await _checkStaged(root);

        expect(
          merged?.manifest[_firstScreenPath],
          previous?.manifest[_firstScreenPath],
        );
        expect(
          merged?.stages.lastOrNull?.sources[_secondScreenPath],
          merged?.manifest[_secondScreenPath],
        );
        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0, 1]);
        expect(staleness.changedPaths, [_firstScreenPath]);
      });
    },
  );
}

void _atlasCapture_should_writeNoHeadlessHashesOfReportOnOtherSources() {
  test(
    'AtlasCapture should write no headless hashes of report on other sources',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        root.writeFlutterConfig();
        _writeStagedSources(root);

        final lines = await RecordingStdout.captureLines(
          () => _captureStaged(
            root,
            _recordScopes([]),
            headlessPass: _writeHeadlessReportsThenChangeMain(root),
          ),
        );

        final snapshot = _readStaged(root);

        expect(snapshot?.stages.map((stage) => stage.headlessFrameHash), [
          null,
          null,
          null,
        ]);
        expect(snapshot?.stages.map((stage) => stage.headlessJournalHash), [
          null,
          null,
          null,
        ]);
        expect(snapshot?.end.headlessFrameHash, isNull);
        expect(snapshot?.headlessRenderer, testHeadlessRenderer);
        expect(
          lines,
          contains(
            '$_flow $_walkedVariant headless hashes left: '
            'no current headless report',
          ),
        );
      });
    },
  );
}

void _atlasCapture_should_writeNoHeadlessHashesOfStagesReportDoesNotHold() {
  test('AtlasCapture should write no headless hashes of stages report does not '
      'hold', () async {
    await TestAtlasRoot.run((root) async {
      _writeStagedFlow(root);
      root.writeFlutterConfig();
      _writeStagedSources(root);

      final lines = await RecordingStdout.captureLines(
        () => _captureStaged(
          root,
          _recordScopes([]),
          headlessPass: _writeHeadlessReports(
            root,
            frameHashes: _shotFrameHashes.take(1).toList(),
            endFrameHash: _endFrameHash,
            record: _shotRecord,
          ),
        ),
      );

      final snapshot = _readStaged(root);

      expect(snapshot?.stages.map((stage) => stage.headlessFrameHash), [
        _shotFrameHashes.firstOrNull,
        null,
        null,
      ]);
      expect(snapshot?.stages.map((stage) => stage.headlessJournalHash), [
        testJournalComparison.hash(const [_shotRecord]),
        null,
        null,
      ]);
      expect(snapshot?.end.headlessFrameHash, _endFrameHash);
      expect(
        lines,
        contains(
          '$_flow $_walkedVariant headless hashes left: '
          'the current headless report is incomplete',
        ),
      );
    });
  });
}

void _atlasCapture_should_writeHeadlessHashesOfShotStagesOnly() {
  test(
    'AtlasCapture should write headless hashes of shot stages only',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        root.writeFlutterConfig();
        _writeStagedSources(root);

        await _captureStaged(
          root,
          _recordScopes([]),
          headlessPass: _writeHeadlessReports(
            root,
            frameHashes: _shotFrameHashes,
            endFrameHash: _endFrameHash,
            record: _shotRecord,
          ),
        );

        final previous = _readStaged(root);

        await _captureStaged(
          root,
          _recordScopes([]),
          stages: [0],
          headlessPass: _writeHeadlessReports(
            root,
            frameHashes: _reshotFrameHashes,
            endFrameHash: _reshotEndFrameHash,
            record: _reshotRecord,
          ),
        );

        final merged = _readStaged(root);

        expect(previous?.stages.map((stage) => stage.headlessFrameHash), [
          ..._shotFrameHashes,
        ]);
        expect(merged?.stages.map((stage) => stage.headlessFrameHash), [
          _reshotFrameHashes.firstOrNull,
          ..._shotFrameHashes.skip(1),
        ]);
        expect(merged?.stages.map((stage) => stage.headlessJournalHash), [
          testJournalComparison.hash(const [_reshotRecord]),
          testJournalComparison.hash(const [_shotRecord]),
          testJournalComparison.hash(const [_shotRecord]),
        ]);
        expect(merged?.end.headlessFrameHash, _endFrameHash);
        expect(
          merged?.headlessRenderer,
          AtlasHeadless.readRenderer(root.paths),
        );
      });
    },
  );
}

void _atlasCapture_should_dropHeadlessHashesOfAnotherRenderer() {
  test(
    'AtlasCapture should drop headless hashes of another renderer',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        root.writeFlutterConfig();
        _writeStagedSources(root);

        await _captureStaged(
          root,
          _recordScopes([]),
          headlessPass: _writeHeadlessReports(
            root,
            frameHashes: _shotFrameHashes,
            endFrameHash: _endFrameHash,
            record: _shotRecord,
          ),
        );

        _writeStagedRenderer(root, _otherRenderer);

        await _captureStaged(
          root,
          _recordScopes([]),
          stages: [0],
          headlessPass: _writeHeadlessReports(
            root,
            frameHashes: _reshotFrameHashes,
            endFrameHash: _reshotEndFrameHash,
            record: _reshotRecord,
          ),
        );

        final merged = _readStaged(root);

        expect(merged?.stages.map((stage) => stage.headlessFrameHash), [
          _reshotFrameHashes.firstOrNull,
          null,
          null,
        ]);
        expect(merged?.stages.map((stage) => stage.headlessJournalHash), [
          testJournalComparison.hash(const [_reshotRecord]),
          null,
          null,
        ]);
        expect(merged?.end.headlessFrameHash, isNull);
        expect(
          merged?.headlessRenderer,
          AtlasHeadless.readRenderer(root.paths),
        );
      });
    },
  );
}

void _atlasCapture_should_walkNoHeadlessPassInAnotherLocale() {
  test('AtlasCapture should walk no headless pass in another locale', () async {
    await TestAtlasRoot.run((root) async {
      _writeStagedFlow(root);
      _writeStagedSources(root);

      final passedVariants = <String>[];

      await _captureStaged(
        root,
        _recordScopes([]),
        locale: _en,
        headlessPass: _recordPassedVariants(passedVariants),
      );

      final snapshot = _readStaged(root, locale: _en);

      expect(passedVariants, isEmpty);
      expect(snapshot?.headlessRenderer, isNull);
      expect(
        snapshot?.stages.map((stage) => stage.headlessFrameHash),
        everyElement(isNull),
      );
      expect(snapshot?.end.headlessFrameHash, isNull);
    });
  });
}

void _atlasCapture_should_walkWholeWhenTheMockAnswersAMergeOtherwise() {
  test('AtlasCapture should walk whole when the mock answers a merge '
      'otherwise', () async {
    await TestAtlasRoot.run((root) async {
      _writeStagedFlow(root);
      root.writeFlutterConfig();
      _writeStagedSources(root);

      await _captureStaged(root, _recordScopes([]));

      final scopes = <List<String>>[];
      final passedVariants = <String>[];

      final isOk = await _captureStaged(
        root,
        _recordScopes(scopes),
        stages: [0],
        mockReplay: const _DifferentMockReplay(),
        headlessPass: _recordPassedVariants(passedVariants),
      );

      expect(isOk, isTrue);
      expect(scopes, [
        ['--shoot', '0', '--until', '0'],
        <String>[],
      ]);
      expect(passedVariants, ['$_flow $_walkedVariant']);
    });
  });
}

Future<({String? mainShot, String? walkedShot})> _captureShotsOfBothVariants(
  TestAtlasRoot root,
) async {
  await _capture(root, (variant, _, captureDirectory) async {
    final frame = image.Image(width: _frameSize, height: _frameSize);

    if (variant.name == _walkedVariant) {
      frame.setPixelRgb(0, 0, 1, 1, 1);
    }

    File(
      p.join(captureDirectory.path, _shotFileName),
    ).writeAsBytesSync(image.encodePng(frame));

    return _buildReport(variant.name, screenshot: _shotFileName);
  });

  final store = AtlasSnapshotStore(root.paths);
  final mainShot = store
      .tryRead(flow: _flow, variant: _stoppedVariant, locale: _uk)
      ?.stages
      .single
      .shot;
  final walkedShot = store
      .tryRead(flow: _flow, variant: _walkedVariant, locale: _uk)
      ?.stages
      .single
      .shot;

  return (mainShot: mainShot, walkedShot: walkedShot);
}

void _expectOnlyTheWalkedVariantStored(TestAtlasRoot root) {
  final store = AtlasSnapshotStore(root.paths);
  final walked = store.tryRead(
    flow: _flow,
    variant: _walkedVariant,
    locale: _uk,
  );

  expect(
    store.tryRead(flow: _flow, variant: _stoppedVariant, locale: _uk),
    isNull,
  );
  expect(walked?.ok, isTrue);
  expect(walked?.device, testAtlasDevice);
}

Future<bool> _capture(TestAtlasRoot root, _Walk walk) {
  return _createCapture(root).captureWalks(
    AtlasDefinitions.read(root.paths).variants,
    device: testAtlasDevice,
    walker: _FakeWalker(walk),
  );
}

Future<bool> _captureStaged(
  TestAtlasRoot root,
  _Walk walk, {
  List<int> stages = const [],
  List<int> freshStages = const [],
  String? locale,
  AtlasMockReplay mockReplay = const _SameMockReplay(),
  AtlasHeadlessPass? headlessPass,
}) {
  return _createCapture(
    root,
    locale: locale,
    mockReplay: mockReplay,
    headlessPass: headlessPass,
  ).captureWalks(
    AtlasDefinitions.read(root.paths).variants,
    device: testAtlasDevice,
    walker: _FakeWalker(walk),
    stageSelections: {
      '$_flow $_walkedVariant': (
        stages: stages,
        attributedPaths: const {},
        freshStages: freshStages,
      ),
    },
  );
}

void _atlasCapture_should_keepStagesAfterTheCutAndTheirHashes() {
  test(
    'AtlasCapture should keep stages after the cut and their hashes',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        root.writeFlutterConfig();
        _writeStagedSources(root);

        await _captureStaged(root, _recordScopes([]));

        final previous = _readStaged(root);

        root.writeSource(_firstScreenPath, 'class FirstScreen { int a = 0; }');

        final staleness = await _checkStaged(root);

        final scopes = <List<String>>[];

        await _captureStaged(
          root,
          _recordScopes(
            scopes,
            partialWalkManifest: [_mainPath, _firstScreenPath],
          ),
          stages: staleness.stages,
        );

        final merged = _readStaged(root);

        expect(scopes, [
          ['--shoot', '0,1', '--until', '1'],
        ]);
        expect(
          merged?.stages.lastOrNull?.toJson(),
          previous?.stages.lastOrNull?.toJson(),
        );
        expect(
          merged?.manifest[_secondScreenPath],
          previous?.manifest[_secondScreenPath],
        );
        expect((await _checkStaged(root)).reason, AtlasStaleReason.fresh);
      });
    },
  );
}

void _atlasCapture_should_walkWholeWhenTheCutMissesAShotStageSource() {
  test(
    'AtlasCapture should walk whole when the cut misses a shot stage source',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        root.writeFlutterConfig();
        _writeStagedSources(root);

        await _captureStaged(root, _recordScopes([]));

        root.writeSource(_firstScreenPath, 'class FirstScreen { int a = 0; }');

        final staleness = await _checkStaged(root);

        final scopes = <List<String>>[];

        await _captureStaged(
          root,
          _recordScopes(scopes, partialWalkManifest: [_mainPath]),
          stages: staleness.stages,
        );

        expect(scopes, [
          ['--shoot', '0,1', '--until', '1'],
          <String>[],
        ]);
        expect((await _checkStaged(root)).reason, AtlasStaleReason.fresh);
      });
    },
  );
}

_Walk _recordScopes(
  List<List<String>> scopes, {
  String? partialWalkFirstLabel,
  List<String>? partialWalkManifest,
}) {
  return (_, scope, _) async {
    scopes.add(scope.runnerArguments);

    if (scope.isEveryStage) {
      return _buildStagedReport();
    }

    return _buildStagedReport(
      firstLabel: partialWalkFirstLabel,
      until: scope.until,
      manifest: partialWalkManifest,
    );
  };
}

AtlasSnapshot? _readStaged(TestAtlasRoot root, {String? locale}) {
  return AtlasSnapshotStore(
    root.paths,
  ).tryRead(flow: _flow, variant: _walkedVariant, locale: locale ?? _uk);
}

Future<AtlasStaleness> _checkStaged(
  TestAtlasRoot root, {
  String? locale,
  String? snapshotCommit,
}) async {
  final stalenesses = await AtlasStaleCheck(
    root.paths,
    locale ?? _uk,
    mockReplay: const _SameMockReplay(),
    snapshotCommitReader: (_) => snapshotCommit,
  ).check(AtlasDefinitions.read(root.paths).variants);

  return stalenesses.single;
}

void _writeFlow(
  TestAtlasRoot root, {
  String? defaultVariant,
  String? walkedStateOf,
  Map<String, Object?>? walkedScenario,
  String? walkedLabel,
}) {
  root.writeFlow(_flow, {
    'defaultVariant': ?defaultVariant,
    'variants': {
      for (final variant in [_stoppedVariant, _walkedVariant])
        variant: {
          if (variant == _walkedVariant) ...{
            'stateOf': ?walkedStateOf,
            'scenario': ?walkedScenario,
          },
          'items': [
            {
              'action': 'tap',
              'label': variant == _walkedVariant
                  ? walkedLabel ?? 'quote an item'
                  : 'quote an item',
              'finder': {
                'by': 'valueKey',
                'value': 'bottom_bar.button.primary',
              },
            },
          ],
        },
    },
  });
}

Map<String, Object?> _buildReport(
  String variant, {
  Map<String, Object?> fields = const {},
  String? screenshot,
}) {
  return {
    'flow': _flow,
    'variant': variant,
    'ok': true,
    'steps': [
      {
        'label': 'quote an item',
        'action': 'tap',
        'ok': true,
        'screenshot': ?screenshot,
        'journal': <Object?>[],
      },
    ],
    'manifest': <String>[],
    ...fields,
  };
}

void _writeStagedFlow(
  TestAtlasRoot root, {
  List<String> labels = _stagedLabels,
}) {
  root.writeFlow(_flow, {
    'variants': {
      _walkedVariant: {
        'items': [
          for (final label in labels)
            {
              'action': 'tap',
              'label': label,
              'finder': {'by': 'text', 'value': label},
            },
        ],
      },
    },
  });
}

void _writeStagedSources(TestAtlasRoot root) {
  root
    ..writeSource(_mainPath, 'void main() {}')
    ..writeSource(_firstScreenPath, 'class FirstScreen {}')
    ..writeSource(_secondScreenPath, 'class SecondScreen {}')
    ..writeSource(
      'lib/app/router.dart',
      "import 'package:sample/first_screen.dart';\n"
          "import 'package:sample/second_screen.dart';\n",
    )
    ..writeSource(
      'lib/app/router.g.dart',
      '/// [FirstScreen]\nclass FirstRoute extends GeneratedRoute<void> {}\n'
          '/// [SecondScreen]\nclass SecondRoute extends GeneratedRoute<void> {}\n',
    );
}

void _writeThemedSources(TestAtlasRoot root) {
  root
    ..writeSource('pubspec.yaml', testAutomationPubspec)
    ..writeSource(_packageConfigPath, readTestPackageConfig('sample'))
    ..writeSource(_secondScreenPath, _themedSecondScreenSource)
    ..writeSource(_themePath, _themeSource);
}

Map<String, Object?> _buildThemedReport() {
  final report = _buildStagedReport(
    manifest: [_mainPath, _firstScreenPath, _secondScreenPath, _themePath],
  );
  final steps = report['steps'] as List<Map<String, Object?>>;

  return {
    ...report,
    'steps': [
      for (final (index, step) in steps.indexed)
        {
          ...step,
          'screen': null,
          'widgets': [_stageWidgets[index]],
        },
    ],
    'endWidgets': [_stageWidgets.last],
  };
}

// A walk cut by [until] ends on the action after it, reported unshot and not
// sent, the way the runner reports a cut.
Map<String, Object?> _buildStagedReport({
  List<String> labels = _stagedLabels,
  String? firstLabel,
  int? until,
  List<String>? manifest,
}) {
  final walkedLabels = [
    for (final (index, label) in labels.indexed)
      index == 0 ? firstLabel ?? label : label,
  ];
  final walkedCount = until == null ? walkedLabels.length : until + 1;

  return {
    'flow': _flow,
    'variant': _walkedVariant,
    'ok': true,
    'steps': [
      for (final (index, label) in walkedLabels.take(walkedCount).indexed)
        {
          'label': label,
          'action': 'tap',
          'target': {'by': 'text', 'value': labels[index]},
          'ok': true,
          'screenshot': null,
          'journal': <Object?>[],
          'screen': {'screenName': _stagedScreens[index]},
        },
      if (until != null)
        {
          'label': walkedLabels[walkedCount],
          'action': 'tap',
          'target': {'by': 'text', 'value': labels[walkedCount]},
          'ok': true,
          'screenshot': null,
          'journalBeforeAction': <Object?>[],
        },
    ],
    'manifest': manifest ?? [_mainPath, _firstScreenPath, _secondScreenPath],
    'until': ?until,
  };
}

// Writes the current headless report of the staged variant, walked on its
// manifest files as they stand, and its baseline report on [_snapshotCommit],
// the baseline holding [_frameHashes]; both journal every stage as the
// snapshot does.
void _writeStagedHeadlessReports(
  TestAtlasRoot root, {
  required List<String> currentFrameHashes,
}) {
  final snapshot = _readStaged(root);
  final journals = [
    const <Object?>[],
    for (final stage in snapshot?.stages ?? const <AtlasStage>[]) stage.journal,
  ];
  final current = AtlasHeadlessReport(
    frameHashes: currentFrameHashes,
    endFrameHash: _endFrameHash,
    error: null,
    journals: journals,
    sourceHashes: {
      for (final path in snapshot?.manifest.keys ?? const <String>[])
        path: testSourceHash.tryHashFile(root.paths.resolve(path)),
    },
  );
  final baseline = AtlasHeadlessReport(
    frameHashes: _frameHashes,
    endFrameHash: _endFrameHash,
    error: null,
    journals: journals,
    commit: _snapshotCommit,
  );

  for (final (isBaseline, report) in [(false, current), (true, baseline)]) {
    root.writeHeadlessReport(
      report,
      flow: _flow,
      variant: _walkedVariant,
      isBaseline: isBaseline,
    );
  }
}

AtlasCapture _createCapture(
  TestAtlasRoot root, {
  String? locale,
  AtlasMockReplay mockReplay = const _SameMockReplay(),
  AtlasHeadlessPass? headlessPass,
}) {
  return AtlasCapture(
    root.paths,
    locale ?? _uk,
    mockReplay: mockReplay,
    headlessPass: headlessPass ?? (_) async => true,
  );
}

AtlasHeadlessPass _writeHeadlessReportsThenChangeMain(TestAtlasRoot root) {
  final writeHeadlessReports = _writeHeadlessReports(
    root,
    frameHashes: _shotFrameHashes,
    endFrameHash: _endFrameHash,
    record: _shotRecord,
  );

  return (variants) async {
    await writeHeadlessReports(variants);

    root.writeSource(_mainPath, 'void main() { runApp(); }');

    return true;
  };
}

AtlasHeadlessPass _writeHeadlessReports(
  TestAtlasRoot root, {
  required List<String> frameHashes,
  required String endFrameHash,
  required Map<String, Object?> record,
}) {
  return (variants) async {
    for (final variant in variants) {
      final snapshot = AtlasSnapshotStore(
        root.paths,
      ).tryRead(flow: variant.flow, variant: variant.name, locale: _uk);
      final report = AtlasHeadlessReport(
        frameHashes: frameHashes,
        endFrameHash: endFrameHash,
        error: null,
        journals: [
          const <Object?>[],
          for (final _ in frameHashes) [record],
        ],
        sourceHashes: {
          for (final path in snapshot?.manifest.keys ?? const <String>[])
            path: testSourceHash.tryHashFile(root.paths.resolve(path)),
        },
      );

      root.writeHeadlessReport(
        report,
        flow: variant.flow,
        variant: variant.name,
      );
    }

    return true;
  };
}

AtlasHeadlessPass _recordPassedVariants(List<String> passedVariants) {
  return (variants) async {
    passedVariants.addAll(variants.map((variant) => variant.id));

    return true;
  };
}

void _writeStagedRenderer(TestAtlasRoot root, String renderer) {
  final snapshot = _readStaged(root);

  if (snapshot == null) {
    fail('No snapshot to write the renderer into');
  }

  AtlasSnapshotStore(root.paths).write(
    addTestHeadlessHashes(
      snapshot,
      frameHashes: [
        for (final stage in snapshot.stages) stage.headlessFrameHash,
      ],
      journalHashes: [
        for (final stage in snapshot.stages) stage.headlessJournalHash,
      ],
      endFrameHash: snapshot.end.headlessFrameHash,
      renderer: renderer,
    ),
  );
}

final class _SameMockReplay implements AtlasMockReplay {
  const _SameMockReplay();

  @override
  Map<String, AtlasMockReplayOutcome> replay(
    List<AtlasMockReplayInput> inputs,
  ) {
    return const {};
  }
}

final class _DifferentMockReplay implements AtlasMockReplay {
  const _DifferentMockReplay();

  @override
  Map<String, AtlasMockReplayOutcome> replay(
    List<AtlasMockReplayInput> inputs,
  ) {
    return {
      for (final input in inputs)
        input.id: const AtlasMockReplayOutcome(
          stage: 0,
          difference: 'GET /files/1 answered 404',
        ),
    };
  }
}

typedef _Walk =
    Future<Map<String, Object?>> Function(
      AtlasVariantDefinition variant,
      AtlasStageScope scope,
      Directory captureDirectory,
    );

final class _FakeWalker implements AtlasWalker {
  final _Walk _walk;

  const _FakeWalker(this._walk);

  @override
  Future<Map<String, Object?>> walk(
    AtlasVariantDefinition variant,
    AtlasStageScope scope,
    Directory captureDirectory,
  ) {
    return _walk(variant, scope, captureDirectory);
  }

  @override
  Future<void> stop() => Future.value();
}
