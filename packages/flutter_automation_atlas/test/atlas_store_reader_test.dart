import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/test_atlas_root.dart';
import 'test_utils/write_published_journals.dart';

const _itemsRequest = {'kind': 'request', 'method': 'GET', 'path': '/items'};

const _storedSnapshots = [
  ('item_search', 'found', 'en'),
  ('item_search', 'found', 'uk'),
  ('item_search', 'found-twice', 'en'),
  ('login', 'signedIn', 'en'),
  ('login', 'signedIn', 'uk'),
];

void main() {
  group('AtlasStoreReader Tests', () {
    _atlasStoreReader_should_openStoreOfTemporaryRoot();
    _atlasStoreReader_should_readRecordsOfPublishedVariants();
    _atlasStoreReader_should_listWalkersByScreen();
    _atlasStoreReader_should_tellStoreOfOptionFromDefault();
    _atlasStoreReader_should_readSnapshotsByFlowVariantAndLocale();
    _atlasStoreReader_should_readNoSnapshotOfEmptyStore();
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
      expect(store.storePath, '${root.directory.path}/shared');
    });
  });
}

void _atlasStoreReader_should_readSnapshotsByFlowVariantAndLocale() {
  test(
    'AtlasStoreReader should read snapshots by flow variant and locale',
    () async {
      await TestAtlasRoot.run((root) {
        final store = AtlasSnapshotStore(root.paths);

        for (final (flow, variant, locale) in _storedSnapshots.reversed) {
          store.write(
            createAtlasSnapshot(flow: flow, variant: variant, locale: locale),
          );
        }

        final snapshots = AtlasStoreReader.open(
          root.project,
          rootPath: root.directory.path,
        ).snapshots();

        expect([
          for (final snapshot in snapshots)
            (snapshot.flow, snapshot.variant, snapshot.locale),
        ], _storedSnapshots);
      });
    },
  );
}

void _atlasStoreReader_should_readNoSnapshotOfEmptyStore() {
  test('AtlasStoreReader should read no snapshot of empty store', () async {
    await TestAtlasRoot.run((root) {
      final snapshots = AtlasStoreReader.open(
        root.project,
        rootPath: root.directory.path,
      ).snapshots();

      expect(snapshots, isEmpty);
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
