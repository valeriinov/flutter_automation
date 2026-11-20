import 'package:flutter_automation_atlas/src/atlas_journal_split.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_published_variants.dart';

/// {@category Utils}
///
/// Reads the journal records of the published variants, each with the stage
/// the page shows it on.
///
/// Only the stored snapshots of the default locale of the variants
/// [AtlasPublishedVariants] names are read. The journal of every stage
/// is split by [AtlasJournalSplit] as the page splits it: a record the
/// action produced belongs to its stage, a record the screen it opened
/// produced belongs to the next stage, or to the end of the snapshot.
final class AtlasJournalStages {
  static const _kindKey = 'kind';

  final AtlasLocations _paths;

  const AtlasJournalStages(this._paths);

  /// The journal of every stage of [snapshot] split as the page shows it, in
  /// the order of the stages.
  List<AtlasStageJournal> split(AtlasSnapshot snapshot) {
    final journalSplit = AtlasJournalSplit(_paths.project.journalSchema);

    return [
      for (final (index, stage) in snapshot.stages.indexed)
        journalSplit.split(
          journal: stage.journal,
          screen: stage.screen,
          destination: _resolveDestination(snapshot, index),
        ),
    ];
  }

  /// The stage of [snapshot] at [index], which names the `<flow>/<variant>`
  /// of the snapshot.
  static AtlasJournalStage stageOf(AtlasSnapshot snapshot, int index) {
    return (variantId: '${snapshot.flow}/${snapshot.variant}', index: index);
  }

  /// The stored snapshots of the default locale that belong to the published
  /// variants, in the order of the snapshot paths.
  Iterable<AtlasSnapshot> readPublishedSnapshots() {
    final publishedVariants = AtlasPublishedVariants.read(
      _paths,
      AtlasDefinitions.read(_paths),
    );

    return AtlasSnapshotStore(_paths)
        .readAll(locale: _paths.defaultLocale)
        .where((snapshot) => publishedVariants.ids.contains(snapshot.id));
  }

  /// Every record of [kind] the published variants logged, in the order of
  /// the snapshot paths, their stages and their journals.
  List<AtlasJournalRecord> readRecords(String kind) {
    return readPublishedSnapshots()
        .expand(_readStageRecords)
        .where((record) => record.record[_kindKey] == kind)
        .toList();
  }

  String? _resolveDestination(AtlasSnapshot snapshot, int stageIndex) {
    final nextIndex = stageIndex + 1;

    return nextIndex < snapshot.stages.length
        ? snapshot.stages[nextIndex].screen
        : snapshot.end.screen;
  }

  Iterable<AtlasJournalRecord> _readStageRecords(AtlasSnapshot snapshot) {
    return [
      for (final (index, journal) in split(snapshot).indexed) ...[
        for (final record
            in journal.afterAction.whereType<Map<String, Object?>>())
          (record: record, stage: stageOf(snapshot, index)),
        for (final record
            in journal.onScreenOpen.whereType<Map<String, Object?>>())
          (record: record, stage: stageOf(snapshot, index + 1)),
      ],
    ];
  }
}

/// The journal of one stage: what its action produced and what the screen
/// the action opened produced while opening.
typedef AtlasStageJournal = ({
  List<Object?> afterAction,
  List<Object?> onScreenOpen,
});

/// A stage of a stored snapshot: the `<flow>/<variant>` it belongs to and its
/// zero-based index among the stages of that snapshot; the end of the
/// snapshot takes the index after its last stage.
typedef AtlasJournalStage = ({String variantId, int index});

/// A journal record and the stage the page shows it on.
typedef AtlasJournalRecord = ({
  Map<String, Object?> record,
  AtlasJournalStage stage,
});
