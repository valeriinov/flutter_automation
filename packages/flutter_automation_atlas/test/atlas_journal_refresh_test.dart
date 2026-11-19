import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_refresh.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replay.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_check.dart';

import 'test_utils/add_test_headless_hashes.dart';
import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/test_atlas_root.dart';

const _flow = 'settings_atlas';
const _variant = 'profileEdited';
final _uk = fakeAtlasLocales.first;
const _labels = ['settings tab', 'open the profile'];
const _mainPath = 'lib/main.dart';
const _recordedMainSource = 'void main() {}';
const _changedMainSource = 'void main() { runApp(); }';
const _anchor = '2026-10-06T09:00:00.000Z';
const _launchedAt = '2026-10-06T13:00:44.058Z';
const _snapshotCommit = 'c0ffee000000';
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
const _recordedProfile = {
  'kind': 'request',
  'method': 'GET',
  'path': '/users/current',
  'status': 200,
  'response': {
    'data': {'id': 1, 'firstName': 'John'},
  },
};
const _replayedProfile = {
  'kind': 'request',
  'method': 'GET',
  'path': '/users/current',
  'acceptLanguage': 'uk',
  'status': 200,
  'response': {
    'data': {'id': 1, 'firstName': 'John', 'languageCode': 'uk'},
  },
};
const _deviceToken = 'eJ5_v1dAl01Er3JuuQ2GWd:tokG6cwXKTewd4riBO8Zw';
const _walkToken = 'atlas-headless:tok-install';
const _recordedSubscription = {
  'kind': 'request',
  'method': 'POST',
  'path': '/notifications/toggle-subscribe/device',
  'body': {'token': _deviceToken},
  'status': 200,
};
const _baselineSubscription = {
  'kind': 'request',
  'method': 'POST',
  'path': '/notifications/toggle-subscribe/device',
  'body': {'token': _walkToken},
  'status': 200,
};
const _currentSubscription = {
  'kind': 'request',
  'method': 'POST',
  'path': '/notifications/toggle-subscribe/device',
  'acceptLanguage': 'uk',
  'body': {'token': _walkToken},
  'status': 200,
};
const _recordedMediaId = '975f305f-aeba-4e77-8109-1c54fd02d19c';
const _baselineMediaId = '2f476b8f-1b80-452e-8264-4c3eebe3d2ac';
const _currentMediaId = '0fb39a87-0a41-441f-990d-13310d8d3d92';
const _okStatus = 200;
const _otherFlutterConfig = '{"flutter": "3.41.0"}';

void main() {
  group('AtlasJournalRefresh Tests', () {
    _atlasJournalRefresh_should_reportStageJournalForJournalAlone();
    _atlasJournalRefresh_should_writeCurrentJournalUntilStaleIsFresh();
    _atlasJournalRefresh_should_leaveVariantWithoutCurrentReport();
    _atlasJournalRefresh_should_leaveOtherStagesForCapture();
    _atlasJournalRefresh_should_writeRecordedInstallValueAndAlike();
    _atlasJournalRefresh_should_leaveStageOfWalkTokenForCapture();
    _atlasJournalRefresh_should_writeEveryStageOfWalkIdsTogether();
    _atlasJournalRefresh_should_keepHeadlessHashesOfRewrittenStages();
  });
}

void _atlasJournalRefresh_should_reportStageJournalForJournalAlone() {
  test(
    'AtlasJournalRefresh should report stage journal for journal alone',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeVariantWalkedAlikeOnChangedMain(root);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageJournal);
        expect(staleness.stages, [0]);
        expect(staleness.journalStages, [0]);
        expect(staleness.describe(), '$_flow $_variant stage journal 0');
      });
    },
  );
}

void _atlasJournalRefresh_should_writeCurrentJournalUntilStaleIsFresh() {
  test(
    'AtlasJournalRefresh should write current journal until stale is fresh',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeVariantWalkedAlikeOnChangedMain(root);

        final left = AtlasJournalRefresh(
          root.paths,
          _uk,
        ).run([await _check(root)]);

        final staleness = await _check(root);

        expect(left, isEmpty);
        expect(_readSnapshot(root).stages.first.journal, [
          _launch,
          _profileState,
          _replayedProfile,
        ]);
        expect(staleness.reason, AtlasStaleReason.fresh);
      });
    },
  );
}

void _atlasJournalRefresh_should_leaveVariantWithoutCurrentReport() {
  test(
    'AtlasJournalRefresh should leave variant without current report',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeVariantWalkedAlikeOnChangedMain(root);

        final staleness = await _check(root);

        File(_resolveReportPath(root, isBaseline: false)).deleteSync();

        final left = AtlasJournalRefresh(root.paths, _uk).run([staleness]);

        expect(left, [staleness]);
        expect(_readSnapshot(root).stages.first.journal, [
          _launch,
          _profileState,
          _recordedProfile,
        ]);
      });
    },
  );
}

void _atlasJournalRefresh_should_leaveOtherStagesForCapture() {
  test('AtlasJournalRefresh should leave other stages for capture', () async {
    await TestAtlasRoot.run((root) async {
      _writeVariantWalkedAlikeOnChangedMain(root);

      final checked = await _check(root);

      final staleness = AtlasStaleness(
        variant: checked.variant,
        reason: AtlasStaleReason.stageCode,
        changedPaths: const [_mainPath],
        changedTranslationKeys: const [],
        stages: const [0, 1],
        attributedPaths: const {},
        journalStages: const [0],
      );
      final [left] = AtlasJournalRefresh(root.paths, _uk).run([staleness]);

      expect(left.stages, [1]);
      expect(left.journalStages, isEmpty);
      expect(left.changedPaths, [_mainPath]);
      expect(_readSnapshot(root).stages.first.journal, [
        _launch,
        _profileState,
        _replayedProfile,
      ]);
    });
  });
}

void _atlasJournalRefresh_should_writeRecordedInstallValueAndAlike() {
  test(
    'AtlasJournalRefresh should write recorded install value and alike',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeVariantWalkedAlikeOnChangedMain(
          root,
          recordedRecords: const [_recordedProfile, _recordedSubscription],
          baselineRecords: const [_recordedProfile, _baselineSubscription],
          currentRecords: const [_recordedProfile, _currentSubscription],
        );

        final left = AtlasJournalRefresh(
          root.paths,
          _uk,
        ).run([await _check(root)]);

        expect(left, isEmpty);
        expect(_readSnapshot(root).stages.first.journal, [
          _launch,
          _profileState,
          _recordedProfile,
          {
            ..._currentSubscription,
            'body': {'token': _deviceToken},
          },
        ]);
      });
    },
  );
}

void _atlasJournalRefresh_should_leaveStageOfWalkTokenForCapture() {
  test(
    'AtlasJournalRefresh should leave stage of walk token for capture',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeVariantWithWalkTokenOnly(root);

        final checked = await _check(root);

        final staleness = AtlasStaleness(
          variant: checked.variant,
          reason: AtlasStaleReason.stageJournal,
          changedPaths: const [],
          changedTranslationKeys: const [],
          stages: const [0],
          attributedPaths: const {},
          journalStages: const [0],
        );
        final left = AtlasJournalRefresh(root.paths, _uk).run([staleness]);

        expect(left, [staleness]);
        expect(_readSnapshot(root).stages.first.journal, [
          _launch,
          _profileState,
          _recordedProfile,
        ]);
      });
    },
  );
}

void _atlasJournalRefresh_should_writeEveryStageOfWalkIdsTogether() {
  test(
    'AtlasJournalRefresh should write every stage of walk ids together',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeVariantWithMediaIdPerWalk(root);

        final staleness = await _check(root);

        final left = AtlasJournalRefresh(root.paths, _uk).run([staleness]);
        final journals = [
          for (final stage in _readSnapshot(root).stages) stage.journal,
        ];

        expect(staleness.reason, AtlasStaleReason.stageJournal);
        expect(left, isEmpty);
        expect(journals, [
          [
            _launch,
            _profileState,
            _mediaRecord(_currentMediaId, isWalked: true),
          ],
          [],
        ]);
      });
    },
  );
}

void _atlasJournalRefresh_should_keepHeadlessHashesOfRewrittenStages() {
  test(
    'AtlasJournalRefresh should keep headless hashes of rewritten stages',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeVariantWalkedAlikeOnChangedMain(root);
        root.writeSource('.fvmrc', _otherFlutterConfig);
        AtlasSnapshotStore(
          root.paths,
        ).write(addTestHeadlessHashes(_readSnapshot(root)));

        final left = AtlasJournalRefresh(
          root.paths,
          _uk,
        ).run([await _check(root)]);
        final snapshot = _readSnapshot(root);

        expect(left, isEmpty);
        expect(snapshot.stages.first.journal, [
          _launch,
          _profileState,
          _replayedProfile,
        ]);
        expectTestHeadlessHashes(snapshot);
      });
    },
  );
}

void _writeVariantWithMediaIdPerWalk(TestAtlasRoot root) {
  _writeVariantWalkedAlikeOnChangedMain(
    root,
    recordedRecords: [_mediaRecord(_recordedMediaId, isWalked: false)],
    baselineRecords: [_mediaRecord(_baselineMediaId, isWalked: false)],
    currentRecords: [_mediaRecord(_currentMediaId, isWalked: true)],
  );
}

Map<String, Object?> _mediaRecord(String mediaId, {required bool isWalked}) {
  return {
    'kind': 'request',
    'method': 'GET',
    'path': '/files/$mediaId',
    if (isWalked) 'acceptLanguage': 'uk',
    'status': _okStatus,
  };
}

void _writeVariantWithWalkTokenOnly(TestAtlasRoot root) {
  _writeVariantWalkedAlikeOnChangedMain(
    root,
    currentRecords: const [_recordedProfile, _currentSubscription],
  );
}

void _writeVariantWalkedAlikeOnChangedMain(
  TestAtlasRoot root, {
  List<Object?> recordedRecords = const [_recordedProfile],
  List<Object?> baselineRecords = const [_recordedProfile],
  List<Object?> currentRecords = const [_replayedProfile],
}) {
  root
    ..writeFlow(_flow, {
      'variants': {
        _variant: {
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
    ..writeSource(_mainPath, _changedMainSource)
    ..writeTranslations(_uk, {});

  final variant = AtlasDefinitions.read(root.paths).variants.single;
  final stages = [
    for (final (index, label) in _labels.indexed)
      AtlasStage(
        label: label,
        action: 'tap',
        journal: index == 0
            ? [_launch, _profileState, ...recordedRecords]
            : const [],
        ok: true,
        target: {'by': 'text', 'value': label},
        block: null,
        targetRect: null,
        screen: null,
        designScreen: null,
        shot: null,
        error: null,
        stepHash: variant.stageStepHashes[index],
        anchor: _anchor,
        launchedAt: _launchedAt,
      ),
  ];

  AtlasSnapshotStore(root.paths).write(
    createAtlasSnapshot(
      flow: _flow,
      variant: _variant,
      defHash: variant.defHash,
      manifest: {_mainPath: testSourceHash.hashSource(_recordedMainSource)},
      stages: stages,
    ),
  );
  _writeReport(root, isBaseline: false, records: currentRecords);
  _writeReport(root, isBaseline: true, records: baselineRecords);
}

void _writeReport(
  TestAtlasRoot root, {
  required bool isBaseline,
  required List<Object?> records,
}) {
  final report = AtlasHeadlessReport(
    frameHashes: _frameHashes,
    journals: [
      const [],
      [_profileState, ...records],
      const [],
    ],
    launch: _launch,
    endFrameHash: _endFrameHash,
    error: null,
    sourceHashes: isBaseline
        ? null
        : {_mainPath: testSourceHash.hashSource(_changedMainSource)},
    commit: isBaseline ? _snapshotCommit : null,
  );

  root.writeHeadlessReport(
    report,
    flow: _flow,
    variant: _variant,
    isBaseline: isBaseline,
  );
}

String _resolveReportPath(TestAtlasRoot root, {required bool isBaseline}) {
  return root.paths.resolveHeadlessReportPath(
    flow: _flow,
    variant: _variant,
    locale: _uk,
    isBaseline: isBaseline,
  );
}

Future<AtlasStaleness> _check(TestAtlasRoot root) async {
  final stalenesses = await AtlasStaleCheck(
    root.paths,
    _uk,
    mockReplay: const _SameMockReplay(),
    snapshotCommitReader: (_) => _snapshotCommit,
  ).check(AtlasDefinitions.read(root.paths).variants);

  return stalenesses.single;
}

AtlasSnapshot _readSnapshot(TestAtlasRoot root) {
  final snapshot = AtlasSnapshotStore(
    root.paths,
  ).tryRead(flow: _flow, variant: _variant, locale: _uk);

  if (snapshot == null) {
    throw StateError('No snapshot of $_flow $_variant');
  }

  return snapshot;
}

final class _SameMockReplay implements AtlasMockReplay {
  const _SameMockReplay();

  @override
  Map<String, AtlasMockReplayOutcome> replay(
    List<AtlasMockReplayInput> inputs,
  ) {
    return {
      for (final input in inputs) input.id: const AtlasMockReplayOutcome.same(),
    };
  }
}
