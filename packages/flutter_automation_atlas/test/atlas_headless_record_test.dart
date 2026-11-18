import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_record.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_source_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_check.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/recording_stdout.dart';
import 'test_utils/test_atlas_root.dart';

const _flow = 'settings_atlas';
const _freshVariant = 'profileOpened';
const _staleVariant = 'profileEdited';
final _uk = fakeAtlasLocales.first;
const _labels = ['settings tab', 'open the profile'];
const _mainPath = 'lib/main.dart';
const _mainSource = 'void main() {}';
const _changedMainSource = 'void main() { runApp(); }';
const _incompleteReportLine =
    '$_flow $_freshVariant headless hashes left: '
    'the current headless report is incomplete';
const _frameHashes = ['712bd761ea00', '897d6e27d98b'];
const _endFrameHash = 'd9549e29368d';
const _launch = {
  'kind': 'launch',
  'features': ['profile'],
};
const _profileState = {
  'kind': 'state',
  'owner': 'ProfileOwner',
  'status': 'ProfileStatusProfileLoaded',
};
const _stageJournals = [
  [_profileState],
  <Object?>[],
];

void main() {
  group('AtlasHeadlessRecord Tests', () {
    _atlasHeadlessRecord_should_writeHashesOfFreshVariant();
    _atlasHeadlessRecord_should_leaveStaleVariant();
    _atlasHeadlessRecord_should_leaveVariantWithReportOfOtherCode();
    _atlasHeadlessRecord_should_leaveVariantWithIncompleteReport();
    _atlasHeadlessRecord_should_leaveVariantWithoutStageJournal();
    _atlasHeadlessRecord_should_leaveVariantWithoutEndFrameHash();
    _atlasHeadlessRecord_should_leaveVariantWithoutSnapshot();
  });
}

void _atlasHeadlessRecord_should_writeHashesOfFreshVariant() {
  test('AtlasHeadlessRecord should write hashes of fresh variant', () async {
    await TestAtlasRoot.run((root) {
      final [fresh, _] = _writeVariants(root);

      AtlasHeadlessRecord(
        root.paths,
      ).run([AtlasStaleness.variant(fresh, AtlasStaleReason.fresh)]);

      final snapshot = _readSnapshot(root, _freshVariant);

      expect(
        snapshot.stages.map((stage) => stage.headlessFrameHash),
        _frameHashes,
      );
      expect(snapshot.stages.map((stage) => stage.headlessJournalHash), [
        testJournalComparison.hash(const [_launch, _profileState]),
        testJournalComparison.hash(const []),
      ]);
      expect(snapshot.end.headlessFrameHash, _endFrameHash);
      expect(snapshot.headlessRenderer, AtlasHeadless.readRenderer(root.paths));
    });
  });
}

void _atlasHeadlessRecord_should_leaveStaleVariant() {
  test('AtlasHeadlessRecord should leave stale variant', () async {
    await TestAtlasRoot.run((root) {
      final [_, stale] = _writeVariants(root);
      final staleness = AtlasStaleness(
        variant: stale,
        reason: AtlasStaleReason.stageCode,
        changedPaths: const [_mainPath],
        changedTranslationKeys: const [],
        stages: const [0, 1],
        attributedPaths: const {},
      );

      AtlasHeadlessRecord(root.paths).run([staleness]);

      final snapshot = _readSnapshot(root, _staleVariant);

      expect(snapshot.stages.map((stage) => stage.headlessFrameHash), [
        null,
        null,
      ]);
      expect(snapshot.end.headlessFrameHash, isNull);
      expect(snapshot.headlessRenderer, isNull);
    });
  });
}

void _atlasHeadlessRecord_should_leaveVariantWithReportOfOtherCode() {
  test(
    'AtlasHeadlessRecord should leave variant with report of other code',
    () async {
      await TestAtlasRoot.run((root) {
        final [fresh, _] = _writeVariants(root);

        root.writeSource(_mainPath, _changedMainSource);
        AtlasHeadlessRecord(
          root.paths,
        ).run([AtlasStaleness.variant(fresh, AtlasStaleReason.fresh)]);
        expect(_readSnapshot(root, _freshVariant).headlessRenderer, isNull);
      });
    },
  );
}

void _atlasHeadlessRecord_should_leaveVariantWithIncompleteReport() {
  test(
    'AtlasHeadlessRecord should leave variant with incomplete report',
    () async {
      await TestAtlasRoot.run((root) async {
        final [fresh, _] = _writeVariants(root);

        _writeReport(
          root,
          _freshVariant,
          frameHashes: _frameHashes.take(1).toList(),
        );

        final lines = await _recordFresh(root, fresh);

        expect(lines, [_incompleteReportLine]);
        expect(_readSnapshot(root, _freshVariant).headlessRenderer, isNull);
      });
    },
  );
}

void _atlasHeadlessRecord_should_leaveVariantWithoutStageJournal() {
  test(
    'AtlasHeadlessRecord should leave variant without stage journal',
    () async {
      await TestAtlasRoot.run((root) async {
        final [fresh, _] = _writeVariants(root);

        _writeReport(
          root,
          _freshVariant,
          journals: [const [], ..._stageJournals.take(1)],
        );

        final lines = await _recordFresh(root, fresh);

        expect(lines, [_incompleteReportLine]);
        expect(_readSnapshot(root, _freshVariant).headlessRenderer, isNull);
      });
    },
  );
}

void _atlasHeadlessRecord_should_leaveVariantWithoutEndFrameHash() {
  test(
    'AtlasHeadlessRecord should leave variant without end frame hash',
    () async {
      await TestAtlasRoot.run((root) async {
        final [fresh, _] = _writeVariants(root);

        _writeReport(root, _freshVariant, endFrameHash: null);

        final lines = await _recordFresh(root, fresh);

        expect(lines, [_incompleteReportLine]);
        expect(_readSnapshot(root, _freshVariant).headlessRenderer, isNull);
      });
    },
  );
}

void _atlasHeadlessRecord_should_leaveVariantWithoutSnapshot() {
  test('AtlasHeadlessRecord should leave variant without snapshot', () async {
    await TestAtlasRoot.run((root) async {
      final [fresh, _] = _writeVariants(root);
      final snapshotFile = File(
        root.paths.resolveSnapshotPath(
          flow: _flow,
          variant: _freshVariant,
          locale: _uk,
        ),
      );

      snapshotFile.deleteSync();

      final lines = await _recordFresh(root, fresh);

      expect(lines, [
        '$_flow $_freshVariant headless hashes left: no snapshot',
      ]);
      expect(snapshotFile.existsSync(), isFalse);
    });
  });
}

List<AtlasVariantDefinition> _writeVariants(TestAtlasRoot root) {
  root
    ..writeFlow(_flow, {
      'variants': {
        for (final variant in [_freshVariant, _staleVariant])
          variant: {
            'items': [
              for (final label in _labels)
                {
                  'action': 'tap',
                  'label': label,
                  'finder': {'by': 'text', 'value': label},
                },
            ],
          },
      },
    })
    ..writeSource(_mainPath, _mainSource)
    ..writeFlutterConfig();

  final variants = AtlasDefinitions.read(root.paths).variants;

  for (final variant in variants) {
    AtlasSnapshotStore(root.paths).write(_createSnapshot(variant));
    _writeReport(root, variant.name);
  }

  return variants;
}

AtlasSnapshot _createSnapshot(AtlasVariantDefinition variant) {
  return createAtlasSnapshot(
    flow: _flow,
    variant: variant.name,
    defHash: variant.defHash,
    manifest: {_mainPath: AtlasSourceHash.hashSource(_mainSource)},
    stages: [
      for (final (index, label) in _labels.indexed)
        AtlasStage(
          label: label,
          action: 'tap',
          journal: _stageJournals[index],
          ok: true,
          target: {'by': 'text', 'value': label},
          block: null,
          targetRect: null,
          screen: null,
          designScreen: null,
          shot: null,
          error: null,
          stepHash: variant.stageStepHashes[index],
        ),
    ],
  );
}

void _writeReport(
  TestAtlasRoot root,
  String variant, {
  List<String> frameHashes = _frameHashes,
  List<List<Object?>> journals = const [[], ..._stageJournals, []],
  String? endFrameHash = _endFrameHash,
}) {
  root.writeHeadlessReport(
    AtlasHeadlessReport(
      frameHashes: frameHashes,
      journals: journals,
      launch: _launch,
      endFrameHash: endFrameHash,
      error: null,
      sourceHashes: {_mainPath: AtlasSourceHash.hashSource(_mainSource)},
    ),
    flow: _flow,
    variant: variant,
  );
}

Future<List<String>> _recordFresh(
  TestAtlasRoot root,
  AtlasVariantDefinition fresh,
) {
  return RecordingStdout.captureLines(
    () => AtlasHeadlessRecord(
      root.paths,
    ).run([AtlasStaleness.variant(fresh, AtlasStaleReason.fresh)]),
  );
}

AtlasSnapshot _readSnapshot(TestAtlasRoot root, String variant) {
  final snapshot = AtlasSnapshotStore(
    root.paths,
  ).tryRead(flow: _flow, variant: variant, locale: _uk);

  if (snapshot == null) {
    throw StateError('No snapshot of $_flow $variant');
  }

  return snapshot;
}
