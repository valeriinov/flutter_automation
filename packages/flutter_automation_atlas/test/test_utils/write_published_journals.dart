import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';

import 'create_atlas_snapshot.dart';
import 'test_atlas_root.dart';

const testJournalVariantId = 'item_search/itemsFound';
const testJournalStageScreen = 'search-route';
const testJournalEndScreen = 'items-route';

const _flowName = 'item_search';
const _publishedVariantName = 'itemsFound';
const _unpublishedVariantName = 'noItemsFound';
const _tapStep = {
  'action': 'tap',
  'label': 'search',
  'finder': {'by': 'valueKey', 'value': 'item_search.button.search'},
};

void writePublishedJournals(
  TestAtlasRoot root, {
  required List<List<Object?>> journals,
  List<List<Object?>> unpublishedJournals = const [],
}) {
  root
    ..writeFlow(_flowName, {
      'variants': {
        _publishedVariantName: {
          'items': [_tapStep],
        },
        _unpublishedVariantName: {
          'items': [_tapStep],
        },
      },
    })
    ..writePublishedVariants({
      _flowName: [_publishedVariantName],
    });

  AtlasSnapshotStore(root.paths)
    ..write(_createSnapshot(_publishedVariantName, journals))
    ..write(_createSnapshot(_unpublishedVariantName, unpublishedJournals));
}

AtlasSnapshot _createSnapshot(String variant, List<List<Object?>> journals) {
  return createAtlasSnapshot(
    flow: _flowName,
    variant: variant,
    stages: [
      for (final journal in journals)
        AtlasStage(
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
        ),
    ],
    end: const AtlasEnd(
      screen: testJournalEndScreen,
      designScreen: null,
      shot: null,
    ),
  );
}
