import 'package:collection/collection.dart';

import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';

/// {@category Utils}
///
/// Keeps the journal order of the previous snapshot where a capture recorded
/// the same records in another order.
///
/// Requests and analytics of one stage run concurrently in the app, so their
/// records arrive in whichever order they finish; an unchanged walk would
/// otherwise rewrite its snapshot on every capture.
abstract final class AtlasJournalOrder {
  static const _recordsEquality = UnorderedIterableEquality<String>();

  /// Returns [captured] with the journal of every stage that is the same action
  /// as the previous stage at its position, and holds the same records, in the
  /// order of the [previous] snapshot.
  static AtlasSnapshot keepPreviousOrder({
    required AtlasSnapshot captured,
    required AtlasSnapshot? previous,
  }) {
    return captured.copyWithStages(
      stages: [
        for (final (index, stage) in captured.stages.indexed)
          _keepPreviousStageOrder(
            stage,
            previous?.tryFindSameActionStage(index, stage),
          ),
      ],
      end: captured.end,
    );
  }

  static AtlasStage _keepPreviousStageOrder(
    AtlasStage stage,
    AtlasStage? previousStage,
  ) {
    if (previousStage == null) {
      return stage;
    }

    final hasSameRecords = _recordsEquality.equals(
      stage.journal.map(AtlasContentHash.encodeCanonicalJson),
      previousStage.journal.map(AtlasContentHash.encodeCanonicalJson),
    );

    return hasSameRecords
        ? stage.copyWithJournal(previousStage.journal)
        : stage;
  }
}
