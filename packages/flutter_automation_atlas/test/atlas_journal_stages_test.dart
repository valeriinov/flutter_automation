import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_journal_stages.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/test_atlas_root.dart';
import 'test_utils/write_published_journals.dart';

const _itemsRequest = {'kind': 'request', 'method': 'GET', 'path': '/items'};
const _cartsRequest = {'kind': 'request', 'method': 'GET', 'path': '/carts'};
const _profileRequest = {'kind': 'request', 'method': 'GET', 'path': '/users'};
const _tabRecord = {
  'kind': 'analytics',
  'target': 'tracker',
  'name': 'tabbar_item_tap',
  'parameters': {'screen_name': testJournalStageScreen},
};
const _itemsViewRecord = {
  'kind': 'analytics',
  'target': 'tracker',
  'name': 'screen_opened',
  'parameters': {'screen_name': testJournalEndScreen},
};
const _createdStateRecord = {
  'kind': 'state',
  'owner': 'ItemsOwner',
  'created': true,
};

void main() {
  group('AtlasJournalStages Tests', () {
    _atlasJournalStages_should_readRecordsOfKindOnTheirStage();
    _atlasJournalStages_should_moveScreenOpenRecordsToNextStageOrEnd();
    _atlasJournalStages_should_readPublishedSnapshotsOfDefaultLocale();
    _atlasJournalStages_should_splitAgainstNextStageScreen();
  });
}

void _atlasJournalStages_should_readRecordsOfKindOnTheirStage() {
  test(
    'AtlasJournalStages should read records of kind on their stage',
    () async {
      await TestAtlasRoot.run((root) {
        writePublishedJournals(
          root,
          journals: const [
            [_tabRecord, _itemsRequest],
            [_cartsRequest],
          ],
        );

        final records = _readLocatedRequests(root);

        expect(records, [
          _located(_itemsRequest, 0),
          _located(_cartsRequest, 1),
        ]);
      });
    },
  );
}

void _atlasJournalStages_should_moveScreenOpenRecordsToNextStageOrEnd() {
  test('AtlasJournalStages should move screen open records to next stage or '
      'end', () async {
    await TestAtlasRoot.run((root) {
      writePublishedJournals(
        root,
        journals: const [
          [_itemsViewRecord, _createdStateRecord, _itemsRequest],
          [
            _cartsRequest,
            _itemsViewRecord,
            _createdStateRecord,
            _profileRequest,
          ],
        ],
      );

      final records = _readLocatedRequests(root);

      expect(records, [
        _located(_itemsRequest, 1),
        _located(_cartsRequest, 1),
        _located(_profileRequest, 2),
      ]);
    });
  });
}

void _atlasJournalStages_should_readPublishedSnapshotsOfDefaultLocale() {
  test('AtlasJournalStages should read published snapshots of default locale'
      'locale only', () async {
    await TestAtlasRoot.run((root) {
      writePublishedJournals(
        root,
        journals: const [
          [_itemsRequest],
        ],
        unpublishedJournals: const [
          [_cartsRequest],
        ],
      );
      AtlasSnapshotStore(root.paths).write(
        createAtlasSnapshot(
          flow: 'item_search',
          variant: 'itemsFound',
          locale: 'en',
          stages: [
            _createStage(const [_profileRequest]),
          ],
        ),
      );

      final records = _readLocatedRequests(root);

      expect(records, [_located(_itemsRequest, 0)]);
    });
  });
}

void _atlasJournalStages_should_splitAgainstNextStageScreen() {
  test('AtlasJournalStages should split against next stage screen', () {
    final snapshot = createAtlasSnapshot(
      flow: 'item_search',
      variant: 'itemsFound',
      stages: [
        _createStage(const [_tabRecord, _itemsViewRecord]),
      ],
      end: const AtlasEnd(
        screen: testJournalEndScreen,
        designScreen: null,
        shot: null,
      ),
    );
    final journals = AtlasJournalStages(
      AtlasLocations('.', FakeAtlasProject()),
    ).split(snapshot);

    expect(journals.single.afterAction, [_tabRecord]);
    expect(journals.single.onScreenOpen, [_itemsViewRecord]);
  });
}

List<({Object? path, AtlasJournalStage stage})> _readLocatedRequests(
  TestAtlasRoot root,
) {
  return [
    for (final journalRecord in AtlasJournalStages(
      root.paths,
    ).readRecords('request'))
      (path: journalRecord.record['path'], stage: journalRecord.stage),
  ];
}

({Object? path, AtlasJournalStage stage}) _located(
  Map<String, Object?> record,
  int index,
) {
  return (
    path: record['path'],
    stage: (variantId: testJournalVariantId, index: index),
  );
}

AtlasStage _createStage(List<Object?> journal) {
  return AtlasStage(
    label: 'search',
    action: 'tap',
    journal: journal,
    ok: true,
    target: null,
    block: null,
    targetRect: null,
    screen: testJournalStageScreen,
    designScreen: null,
    shot: null,
    error: null,
  );
}
