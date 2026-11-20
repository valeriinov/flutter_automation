import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/test_atlas_root.dart';
import 'test_utils/write_published_journals.dart';

const _itemsRequest = {'kind': 'request', 'method': 'GET', 'path': '/items'};

void main() {
  group('AtlasStoreReader Tests', () {
    _atlasStoreReader_should_openStoreOfTemporaryRoot();
    _atlasStoreReader_should_readRecordsOfPublishedVariants();
    _atlasStoreReader_should_listWalkersByScreen();
    _atlasStoreReader_should_tellStoreOfOptionFromDefault();
  });
}

void _atlasStoreReader_should_openStoreOfTemporaryRoot() {
  test('AtlasStoreReader should open store of temporary root', () async {
    await TestAtlasRoot.run((root) {
      final store = AtlasStoreReader.open(
        root.project,
        rootPath: root.directory.path,
      );

      expect(store.rootPath, root.directory.path);
      expect(store.isDefaultStore, isTrue);
    });
  });
}

void _atlasStoreReader_should_readRecordsOfPublishedVariants() {
  test('AtlasStoreReader should read records of published variants', () async {
    await TestAtlasRoot.run((root) {
      writePublishedJournals(
        root,
        journals: const [
          [_itemsRequest],
        ],
        unpublishedJournals: const [
          [_itemsRequest],
        ],
      );

      final records = AtlasStoreReader.open(
        root.project,
        rootPath: root.directory.path,
      ).recordsOf('request');

      expect(records.single.record, _itemsRequest);
      expect(records.single.stage, (variantId: testJournalVariantId, index: 0));
    });
  });
}

void _atlasStoreReader_should_listWalkersByScreen() {
  test('AtlasStoreReader should list walkers by screen', () async {
    await TestAtlasRoot.run((root) {
      AtlasSnapshotStore(root.paths)
        ..write(
          createAtlasSnapshot(
            flow: 'item_search',
            variant: 'itemsFound',
            stages: [_createStage('search-route')],
            end: const AtlasEnd(
              screen: 'items-route',
              designScreen: null,
              shot: null,
            ),
          ),
        )
        ..write(
          createAtlasSnapshot(
            flow: 'item_search',
            variant: 'noItemsFound',
            stages: [_createStage('search-route')],
          ),
        );

      final walkers = AtlasStoreReader.open(
        root.project,
        rootPath: root.directory.path,
      ).walkersByScreen();

      expect(walkers, {
        'search-route': ['item_search itemsFound', 'item_search noItemsFound'],
        'items-route': ['item_search itemsFound'],
      });
    });
  });
}

void _atlasStoreReader_should_tellStoreOfOptionFromDefault() {
  test('AtlasStoreReader should tell store of option from default', () async {
    await TestAtlasRoot.run((root) {
      final store = AtlasStoreReader.open(
        root.project,
        rootPath: root.directory.path,
        store: '${root.directory.path}/shared',
      );

      expect(store.isDefaultStore, isFalse);
    });
  });
}

AtlasStage _createStage(String screen) {
  return AtlasStage(
    label: 'search',
    action: 'tap',
    journal: const [],
    ok: true,
    target: null,
    block: null,
    targetRect: null,
    screen: screen,
    designScreen: null,
    shot: null,
    error: null,
  );
}
