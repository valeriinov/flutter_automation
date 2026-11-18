import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_merge.dart';
import 'package:flutter_automation_atlas/src/atlas_stage_scope.dart';

import 'test_utils/add_test_headless_hashes.dart';
import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';

const _flow = 'shop_flow';
const _variant = 'shopFromExistingItem';
const _mockPath = 'lib/support/mock/mock_config.dart';
const _viewPath = 'lib/existing_items_view.dart';
const _dimensPath = 'lib/theme/app_dimens_ext.dart';
const _anchor = '2026-10-03T09:00:00.000Z';
const _previousManifest = {
  _mockPath: 'aaaaaaaaaaaa',
  _viewPath: 'bbbbbbbbbbbb',
};
const _capturedManifest = {_viewPath: 'bbbbbbbbbbbb'};
const _previousWidgets = ['ExistingItemsView'];
const _capturedWidgets = ['ExistingItemsView', 'ItemQuoteSheet'];

void main() {
  group('AtlasSnapshotMerge Tests', () {
    _atlasSnapshotMerge_should_keepMockFilesWhileStageLacksAnchor();
    _atlasSnapshotMerge_should_dropMockFilesOnceEveryStageIsAnchored();
    _atlasSnapshotMerge_should_keepWidgetsOfUncapturedStages();
    _atlasSnapshotMerge_should_takeNewHashOfFilePlacedOnNoStage();
    _atlasSnapshotMerge_should_dropDeletedFileFromManifestAndSources();
    _atlasSnapshotMerge_should_keepHeadlessHashesOfRebasedStages();
    _atlasSnapshotMerge_should_keepHeadlessHashesWhenRemovingPaths();
  });
}

void _atlasSnapshotMerge_should_keepMockFilesWhileStageLacksAnchor() {
  test(
    'AtlasSnapshotMerge should keep mock files while stage lacks anchor',
    () {
      final merged = _merge(previousAnchor: null, shotStages: [1]);

      expect(merged?.manifest, _previousManifest);
    },
  );
}

void _atlasSnapshotMerge_should_dropMockFilesOnceEveryStageIsAnchored() {
  test('AtlasSnapshotMerge should drop mock files once every stage is '
      'anchored', () {
    final merged = _merge(previousAnchor: null, shotStages: [0, 1]);

    expect(merged?.manifest, _capturedManifest);
  });
}

void _atlasSnapshotMerge_should_keepWidgetsOfUncapturedStages() {
  test('AtlasSnapshotMerge should keep widgets of uncaptured stages', () {
    final merged = _merge(previousAnchor: _anchor, shotStages: [1]);

    expect(merged?.stages.map((stage) => stage.widgets), [
      _previousWidgets,
      _capturedWidgets,
    ]);
  });
}

void _atlasSnapshotMerge_should_takeNewHashOfFilePlacedOnNoStage() {
  test(
    'AtlasSnapshotMerge should take new hash of file placed on no stage',
    () {
      final merged = _merge(
        previousAnchor: _anchor,
        shotStages: [1],
        previousManifest: {..._capturedManifest, _dimensPath: 'cccccccccccc'},
        capturedManifest: {..._capturedManifest, _dimensPath: 'dddddddddddd'},
        attributedPaths: {_dimensPath: {}},
      );

      expect(merged?.manifest[_dimensPath], 'dddddddddddd');
    },
  );
}

void _atlasSnapshotMerge_should_dropDeletedFileFromManifestAndSources() {
  test(
    'AtlasSnapshotMerge should drop deleted file from manifest and sources',
    () {
      final merged = _merge(
        previousAnchor: _anchor,
        shotStages: [1],
        previousManifest: {..._capturedManifest, _dimensPath: 'cccccccccccc'},
        attributedPaths: {
          _dimensPath: {1},
        },
        previousSources: {_dimensPath: 'cccccccccccc'},
        deletedPaths: {_dimensPath},
      );

      expect(merged?.manifest, _capturedManifest);
      expect(merged?.stages.map((stage) => stage.sources), [isEmpty, isEmpty]);
    },
  );
}

void _atlasSnapshotMerge_should_keepHeadlessHashesOfRebasedStages() {
  test('AtlasSnapshotMerge should keep headless hashes of rebased stages', () {
    final rebased = AtlasSnapshotMerge.rebaseFreshStages(
      _createHeadlessSnapshot(),
      (stages: const [], attributedPaths: const {}, freshStages: const [0]),
      {_viewPath: 'dddddddddddd'},
    );

    expect(rebased.stages.first.sources, {_viewPath: 'dddddddddddd'});
    expectTestHeadlessHashes(rebased);
  });
}

void _atlasSnapshotMerge_should_keepHeadlessHashesWhenRemovingPaths() {
  test(
    'AtlasSnapshotMerge should keep headless hashes when removing paths',
    () {
      final removed = AtlasSnapshotMerge.removePaths(
        _createHeadlessSnapshot(),
        {_viewPath},
      );

      expect(removed.stages.first.sources, isEmpty);
      expectTestHeadlessHashes(removed);
    },
  );
}

AtlasSnapshot _createHeadlessSnapshot() {
  return addTestHeadlessHashes(
    _createSnapshot(
      _capturedManifest,
      anchor: _anchor,
      widgets: _previousWidgets,
      sources: _capturedManifest,
    ),
  );
}

AtlasSnapshot? _merge({
  required String? previousAnchor,
  required List<int> shotStages,
  Map<String, String> previousManifest = _previousManifest,
  Map<String, String> capturedManifest = _capturedManifest,
  Map<String, Set<int>> attributedPaths = const {},
  Map<String, String> previousSources = const {},
  Set<String> deletedPaths = const {},
}) {
  return AtlasSnapshotMerge.tryMerge(
    captured: _createSnapshot(
      capturedManifest,
      anchor: _anchor,
      widgets: _capturedWidgets,
    ),
    mockDirectory: fakeAtlasStaleSettings.mockDirectory,
    previous: AtlasSnapshotMerge.removePaths(
      _createSnapshot(
        previousManifest,
        anchor: previousAnchor,
        widgets: _previousWidgets,
        sources: previousSources,
      ),
      deletedPaths,
    ),
    scope: AtlasStageScope.of(shotStages, stageCount: 2),
    attributedPaths: attributedPaths,
  );
}

AtlasSnapshot _createSnapshot(
  Map<String, String> manifest, {
  required String? anchor,
  required List<String> widgets,
  Map<String, String> sources = const {},
}) {
  return createAtlasSnapshot(
    flow: _flow,
    variant: _variant,
    manifest: manifest,
    stages: [
      for (final label in ['open the search', 'quote an item'])
        AtlasStage(
          label: label,
          action: 'tap',
          journal: const [],
          ok: true,
          target: null,
          block: null,
          targetRect: null,
          screen: null,
          designScreen: null,
          shot: null,
          error: null,
          anchor: anchor,
          launchedAt: anchor,
          sources: sources,
          widgets: widgets,
        ),
    ],
  );
}
