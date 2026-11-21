import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_check.dart';
import 'package:flutter_automation_atlas/src/run_atlas.dart';

import 'test_utils/add_test_headless_hashes.dart';
import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/recording_stdout.dart';
import 'test_utils/test_atlas_root.dart';
import 'test_utils/write_published_journals.dart';

const _capture = ['capture', 'shop_flow', 'shopFromSearch'];
const _flow = 'settings_atlas';
const _unwalkedVariant = 'profileEdited';
const _walkedVariant = 'profileOpened';
const _freshVariant = 'settingsOpened';
const _mainPath = 'lib/main.dart';
const _mainSource = 'void main() {}';
const _endFrameHash = 'd4e5f6a1b2c3';
final _manifest = {_mainPath: testSourceHash.hashSource(_mainSource)};
const _tapStep = {
  'action': 'tap',
  'label': 'settings tab',
  'finder': {'by': 'text', 'value': 'settings tab'},
};

void main() {
  group('AtlasRun Tests', () {
    _atlasCatalogue_should_rejectStagesThatAreNotIndexes();
    _atlasCatalogue_should_rejectStagesWithoutAValue();
    _atlasCatalogue_should_rejectStagesWithoutOneVariant();
    _atlasCatalogue_should_rejectStagesBesideStale();
    _atlasCatalogue_should_rejectBaselineBesideRecord();
    _atlasCatalogue_should_rejectPublishedOnHeadless();
    _atlasCatalogue_should_rejectNoWalkOnCaptureWithoutStale();
    _atlasCatalogue_should_walkStaleVariantsWithoutCurrentReport();
    _atlasCatalogue_should_walkNothingWithNoWalk();
    _atlasCatalogue_should_walkNothingWithoutPublished();
    _atlasRun_should_failTheExitCodeOfStaleWithRequireFreshOnAStaleVariant();
    _atlasRun_should_keepTheExitCodeOfStaleWithRequireFreshWhenEachIsFresh();
    _atlasRun_should_keepTheExitCodeOfStaleWithoutRequireFresh();
    _atlasCatalogue_should_recordHashesOfVariantsCheckedAfterTheWalk();
    _atlasRun_should_handStorePathToProjectReports();
    _atlasRun_should_keepSourceLabelOnRunOptions();
    _atlasRun_should_rejectSourceLabelWithoutAValue();
    _atlasRun_should_rejectSourceCommitWithoutSnapshot();
    _atlasRun_should_takeLocalesFromProject();
    _atlasRun_should_printTheChecksAndFailTheExitCodeOnAFailure();
  });
}

void _atlasCatalogue_should_rejectStagesThatAreNotIndexes() {
  test('AtlasRun should reject stages that are not indexes', () {
    for (final stages in ['1,a', '-1', '1,,2']) {
      expect(
        AtlasRun([..._capture, '--stages', stages], FakeAtlasProject()).run,
        throwsA(isA<AtlasException>()),
      );
    }
  });
}

void _atlasCatalogue_should_rejectStagesWithoutAValue() {
  test('AtlasRun should reject stages without a value', () {
    expect(
      AtlasRun([..._capture, '--stages'], FakeAtlasProject()).run,
      throwsA(isA<AtlasException>()),
    );
  });
}

void _atlasCatalogue_should_rejectStagesWithoutOneVariant() {
  test('AtlasRun should reject stages without one variant', () {
    for (final args in [
      ['capture', 'shop_flow', '--stages', '1'],
      [..._capture, 'shopFromExistingItem', '--stages', '1'],
    ]) {
      expect(
        AtlasRun(args, FakeAtlasProject()).run,
        throwsA(isA<AtlasException>()),
      );
    }
  });
}

void _atlasCatalogue_should_rejectStagesBesideStale() {
  test('AtlasRun should reject stages beside stale', () {
    expect(
      AtlasRun(['capture', '--stale', '--stages', '1'], FakeAtlasProject()).run,
      throwsA(isA<AtlasException>()),
    );
  });
}

void _atlasCatalogue_should_rejectBaselineBesideRecord() {
  test('AtlasRun should reject baseline beside record', () async {
    await TestAtlasRoot.run((root) async {
      _writeVariants(root);

      final catalogue = _createCatalogue(
        root,
        const ['headless', '--baseline', '--record'],
        [],
        [],
      );

      await expectLater(catalogue.run, throwsA(isA<AtlasException>()));
    });
  });
}

void _atlasCatalogue_should_rejectPublishedOnHeadless() {
  test('AtlasRun should reject published on headless', () async {
    await TestAtlasRoot.run((root) async {
      _writeVariants(root);

      final catalogue = _createCatalogue(
        root,
        const ['headless', '--published'],
        [],
        [],
      );

      await expectLater(catalogue.run, throwsA(isA<AtlasException>()));
    });
  });
}

void _atlasCatalogue_should_rejectNoWalkOnCaptureWithoutStale() {
  test('AtlasRun should reject no walk on capture without stale', () async {
    await TestAtlasRoot.run((root) async {
      _writeVariants(root);

      final catalogue = _createCatalogue(
        root,
        const ['capture', _flow, _walkedVariant, '--no-walk'],
        [],
        [],
      );

      await expectLater(catalogue.run, throwsA(isA<AtlasException>()));
    });
  });
}

void _atlasCatalogue_should_walkStaleVariantsWithoutCurrentReport() {
  test('AtlasRun should walk stale variants without current report', () async {
    await TestAtlasRoot.run((root) async {
      final walks = <List<String>>[];
      final checks = <List<String>>[];

      _writeVariants(root);

      final lines = await RecordingStdout.captureLines(
        _createCatalogue(
          root,
          const ['stale', '--published'],
          walks,
          checks,
        ).run,
      );

      expect(lines, [
        '$_flow $_unwalkedVariant fresh',
        '$_flow $_walkedVariant stage code 0 $_mainPath',
        '$_flow $_freshVariant fresh',
      ]);
      expect(walks, [
        ['$_flow $_unwalkedVariant'],
      ]);
      expect(checks, [
        [
          '$_flow $_unwalkedVariant',
          '$_flow $_walkedVariant',
          '$_flow $_freshVariant',
        ],
        ['$_flow $_unwalkedVariant'],
      ]);
    });
  });
}

void _atlasCatalogue_should_walkNothingWithNoWalk() {
  test('AtlasRun should walk nothing with no walk', () async {
    await TestAtlasRoot.run((root) async {
      final walks = <List<String>>[];
      final checks = <List<String>>[];

      _writeVariants(root);

      await _createCatalogue(
        root,
        const ['stale', '--published', '--no-walk'],
        walks,
        checks,
      ).run();

      expect(walks, isEmpty);
      expect(checks, hasLength(1));
    });
  });
}

void _atlasCatalogue_should_walkNothingWithoutPublished() {
  test('AtlasRun should walk nothing without published', () async {
    await TestAtlasRoot.run((root) async {
      final walks = <List<String>>[];
      final checks = <List<String>>[];

      _writeVariants(root);

      await _createCatalogue(root, const ['stale'], walks, checks).run();

      expect(walks, isEmpty);
      expect(checks, hasLength(1));
    });
  });
}

void _atlasRun_should_failTheExitCodeOfStaleWithRequireFreshOnAStaleVariant() {
  test('AtlasRun should fail the exit code of stale with require fresh on a '
      'stale variant', () async {
    await TestAtlasRoot.run((root) async {
      _writeVariants(root);

      final lines = await RecordingStdout.captureLines(
        _createCatalogue(
          root,
          const ['stale', '--require-fresh', _flow],
          [],
          [],
        ).run,
      );

      expect(lines, [
        '$_flow $_unwalkedVariant stage code 0 $_mainPath',
        '$_flow $_walkedVariant stage code 0 $_mainPath',
        '$_flow $_freshVariant fresh',
      ]);
      expect(exitCode, 1);

      exitCode = 0;
    });
  });
}

void _atlasRun_should_keepTheExitCodeOfStaleWithRequireFreshWhenEachIsFresh() {
  test('AtlasRun should keep the exit code of stale with require fresh when '
      'each is fresh', () async {
    await TestAtlasRoot.run((root) async {
      _writeVariants(root);

      final lines = await RecordingStdout.captureLines(
        AtlasRun(
          const ['stale', '--require-fresh'],
          root.project,
          rootPath: root.directory.path,
          readStalenesses: (variants) async {
            return variants.map(_createFresh).toList();
          },
        ).run,
      );

      expect(lines, [
        '$_flow $_unwalkedVariant fresh',
        '$_flow $_walkedVariant fresh',
        '$_flow $_freshVariant fresh',
      ]);
      expect(exitCode, 0);
    });
  });
}

void _atlasRun_should_keepTheExitCodeOfStaleWithoutRequireFresh() {
  test(
    'AtlasRun should keep the exit code of stale without require fresh',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeVariants(root);

        final lines = await RecordingStdout.captureLines(
          _createCatalogue(root, const ['stale'], [], []).run,
        );

        expect(
          lines,
          contains('$_flow $_walkedVariant stage code 0 $_mainPath'),
        );
        expect(exitCode, 0);
      });
    },
  );
}

void _atlasCatalogue_should_recordHashesOfVariantsCheckedAfterTheWalk() {
  test(
    'AtlasRun should record hashes of variants checked after the walk',
    () async {
      await TestAtlasRoot.run((root) async {
        final calls = <String>[];

        _writeVariants(root);
        AtlasSnapshotStore(root.paths).write(
          createAtlasSnapshot(
            flow: _flow,
            variant: _freshVariant,
            manifest: _manifest,
          ),
        );

        await _createRecordingCatalogue(root, calls).run();

        final snapshot = AtlasSnapshotStore(root.paths).tryRead(
          flow: _flow,
          variant: _freshVariant,
          locale: root.paths.defaultLocale,
        );

        expect(calls, [
          'walk ($_flow $_freshVariant)',
          'check ($_flow $_freshVariant)',
        ]);
        expect(snapshot?.end.headlessFrameHash, _endFrameHash);
        expect(snapshot?.headlessRenderer, testHeadlessRenderer);
      });
    },
  );
}

void _writeVariants(TestAtlasRoot root) {
  root
    ..writeFlow(_flow, {
      'variants': {
        for (final variant in [_unwalkedVariant, _walkedVariant, _freshVariant])
          variant: {
            'items': [_tapStep],
          },
      },
    })
    ..writeSource(_mainPath, _mainSource)
    ..writeFlutterConfig()
    ..writePublishedVariants({
      _flow: [_unwalkedVariant, _walkedVariant, _freshVariant],
    });

  AtlasSnapshotStore(root.paths)
    ..write(
      addTestHeadlessHashes(
        createAtlasSnapshot(
          flow: _flow,
          variant: _unwalkedVariant,
          manifest: _manifest,
        ),
      ),
    )
    ..write(
      createAtlasSnapshot(
        flow: _flow,
        variant: _walkedVariant,
        manifest: _manifest,
      ),
    );

  root.writeHeadlessReport(
    AtlasHeadlessReport(
      frameHashes: const [],
      endFrameHash: null,
      error: null,
      sourceHashes: _manifest,
    ),
    flow: _flow,
    variant: _walkedVariant,
  );
}

void _writeCompleteReport(TestAtlasRoot root, String variant) {
  root.writeHeadlessReport(
    AtlasHeadlessReport(
      frameHashes: const [],
      endFrameHash: _endFrameHash,
      error: null,
      sourceHashes: _manifest,
    ),
    flow: _flow,
    variant: variant,
  );
}

AtlasRun _createCatalogue(
  TestAtlasRoot root,
  List<String> args,
  List<List<String>> walks,
  List<List<String>> checks,
) {
  return AtlasRun(
    args,
    root.project,
    rootPath: root.directory.path,
    readStalenesses: (variants) async {
      checks.add([for (final variant in variants) variant.id]);

      return variants
          .map(checks.length > 1 ? _createFresh : _createStaleness)
          .toList();
    },
    headlessPass: (variants) async {
      walks.add([for (final variant in variants) variant.id]);

      return true;
    },
  );
}

AtlasRun _createRecordingCatalogue(TestAtlasRoot root, List<String> calls) {
  return AtlasRun(
    const ['headless', '--record', _flow, _freshVariant],
    root.project,
    rootPath: root.directory.path,
    readStalenesses: (variants) async {
      calls.add('check ${variants.map((variant) => variant.id)}');

      return variants.map(_createStaleness).toList();
    },
    headlessPass: (variants) async {
      calls.add('walk ${variants.map((variant) => variant.id)}');
      _writeCompleteReport(root, _freshVariant);

      return true;
    },
  );
}

AtlasStaleness _createFresh(AtlasVariantDefinition variant) {
  return AtlasStaleness.variant(variant, AtlasStaleReason.fresh);
}

AtlasStaleness _createStaleness(AtlasVariantDefinition variant) {
  if (variant.name == _freshVariant) {
    return _createFresh(variant);
  }

  return AtlasStaleness(
    variant: variant,
    reason: AtlasStaleReason.stageCode,
    changedPaths: const [_mainPath],
    changedTranslationKeys: const [],
    stages: const [0],
    attributedPaths: const {},
  );
}

void _atlasRun_should_handStorePathToProjectReports() {
  test('AtlasRun should hand store reader of option to project reports', () {
    final project = FakeAtlasProject();
    final run = AtlasRun(['stale', '--store', 'shared/atlas'], project);

    run.writeReports();
    expect(project.reportedStores.single.isDefaultStore, isFalse);
  });
}

void _atlasRun_should_keepSourceLabelOnRunOptions() {
  test('AtlasRun should keep source label on run options', () {
    final run = AtlasRun([
      'stale',
      '--source-label',
      'release 1',
    ], FakeAtlasProject());

    expect(run.sourceLabel, 'release 1');
    expect(AtlasRun(['stale'], FakeAtlasProject()).sourceLabel, isNull);
  });
}

void _atlasRun_should_rejectSourceLabelWithoutAValue() {
  test('AtlasRun should reject source label without a value', () {
    expect(
      () =>
          AtlasRun(['stale', '--source-label'], FakeAtlasProject()).sourceLabel,
      throwsA(isA<AtlasException>()),
    );
  });
}

void _atlasRun_should_rejectSourceCommitWithoutSnapshot() {
  test('AtlasRun should reject source commit without snapshot', () {
    expect(
      AtlasRun(['source-commit'], FakeAtlasProject()).run,
      throwsA(isA<AtlasException>()),
    );
    expect(
      AtlasRun(['source-commit', '--snapshot'], FakeAtlasProject()).run,
      throwsA(isA<AtlasException>()),
    );
  });
}

void _atlasRun_should_takeLocalesFromProject() {
  test('AtlasRun should take locales from project', () {
    final run = AtlasRun([
      'stale',
    ], FakeAtlasProject(locales: const ['de', 'fr']));

    expect(run.locations.defaultLocale, 'de');
    expect(run.locations.pageLocales, ['de', 'fr']);
  });
}

void _atlasRun_should_printTheChecksAndFailTheExitCodeOnAFailure() {
  test('AtlasRun should print the checks and fail the exit code', () async {
    await TestAtlasRoot.run((root) async {
      writePublishedJournals(root, journals: const []);

      final lines = await RecordingStdout.captureLines(
        () => AtlasRun(
          ['check'],
          root.project,
          rootPath: root.directory.path,
          readStalenesses: (variants) async => const [],
        ).run(),
      );

      expect(lines.map((line) => line.split(' ').first), [
        'FAIL',
        '',
        'ok',
        'note',
        'ok',
        'skip',
        'ok',
      ]);
      expect(lines.first, startsWith('FAIL  page'));
      expect(lines[2], startsWith('ok    publishedVariants'));
      expect(lines[3], startsWith('note  storedVariants'));
      expect(lines.last, startsWith('ok    shots'));
      expect(exitCode, 1);

      exitCode = 0;
    });
  });
}
