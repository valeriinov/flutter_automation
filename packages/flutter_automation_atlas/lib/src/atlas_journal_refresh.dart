import 'dart:io';

import 'package:flutter_automation_atlas/src/atlas_journal_comparison.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_check.dart';

/// {@category Utils}
///
/// Writes, without a device, the journal the current headless report holds
/// into every [AtlasStaleness.journalStages] stage of a snapshot: the
/// headless walks show its frame alike on the current code and on the code it
/// was captured on, and the baseline walk wrote the journal the capture
/// wrote, so the current walk writes the one a capture would write now.
///
/// A record the stage recorded alike ([AtlasJournalComparison]) is written as
/// recorded, and an install value as the device recorded it, since the walk
/// holds an install value of no install. When a stage's other records hold a
/// value only the walk drew — a uuid or a generated value the stage does not
/// hold — every stage of the snapshot takes the journal of the walk, so its ids
/// stay those of one walk, with each generated and install value the device
/// recorded in its place; `stale` names such a stage only when the walk shows
/// every stage alike. A variant whose walk holds an install value while the
/// snapshot holds none, or another number of generated values, is left for a
/// capture. Every other field of the snapshot stays as it is. A variant without
/// a current report, or whose report holds no journal of such a stage, is left
/// for a capture.
final class AtlasJournalRefresh {
  final AtlasLocations _paths;
  final String _locale;

  const AtlasJournalRefresh(this._paths, this._locale);

  AtlasJournalComparison get _comparison {
    return AtlasJournalComparison(_paths.project.journalSchema);
  }

  /// Writes the journals of the [AtlasStaleness.journalStages] of
  /// [stalenesses] and returns, in order, every staleness with a stage left
  /// for a capture, without the stages it wrote.
  List<AtlasStaleness> run(List<AtlasStaleness> stalenesses) {
    final store = AtlasSnapshotStore(_paths);

    return [
      for (final staleness in stalenesses)
        if (staleness.journalStages.isEmpty || !_tryRefresh(staleness, store))
          staleness
        else
          ?staleness.tryWithoutJournalStages(),
    ];
  }

  bool _tryRefresh(AtlasStaleness staleness, AtlasSnapshotStore store) {
    final variant = staleness.variant;
    final snapshot = store.tryRead(
      flow: variant.flow,
      variant: variant.name,
      locale: _locale,
    );
    final report = AtlasHeadlessReport.tryReadFile(
      _paths.resolveHeadlessReportPath(
        flow: variant.flow,
        variant: variant.name,
        locale: _locale,
      ),
    );

    if (snapshot == null || report == null) {
      _printLeft(variant.id, 'no current headless report');

      return false;
    }

    final stages = _tryRewriteStages(snapshot, report, staleness.journalStages);

    if (stages == null) {
      _printLeft(
        variant.id,
        'the current headless report holds no journal or a value the walk '
        'drew',
      );

      return false;
    }

    store.write(snapshot.copyWithStages(stages: stages, end: snapshot.end));
    stdout.writeln(
      '${variant.id} journal written for stages '
      '${staleness.journalStages.join(',')}',
    );

    return true;
  }

  List<AtlasStage>? _tryRewriteStages(
    AtlasSnapshot snapshot,
    AtlasHeadlessReport report,
    List<int> journalStages,
  ) {
    final journals = {
      for (final index in journalStages)
        index: report.tryReadStageJournal(index),
    };
    final installValue = _comparison.tryFindInstallValue([
      for (final stage in snapshot.stages) ...stage.journal,
    ]);

    if (journals.containsValue(null)) {
      return null;
    }

    final hasWalkValue = journals.entries.any(
      (entry) =>
          _comparison.tryDescribeWalkValue(
            walked: entry.value ?? const [],
            recorded: snapshot.stages[entry.key].journal,
            installValue: installValue,
          ) !=
          null,
    );

    if (hasWalkValue) {
      return _tryRewriteEveryStage(snapshot, report, installValue);
    }

    return [
      for (final (index, stage) in snapshot.stages.indexed)
        switch (journals[index]) {
          final journal? => stage.copyWithJournal(
            _comparison.keepRecorded(
              walked: journal,
              recorded: stage.journal,
              installValue: installValue,
            ),
          ),
          null => stage,
        },
    ];
  }

  void _printLeft(String id, String reason) {
    stdout.writeln('$id journal left for a capture: $reason');
  }

  List<AtlasStage>? _tryRewriteEveryStage(
    AtlasSnapshot snapshot,
    AtlasHeadlessReport report,
    String? installValue,
  ) {
    final walked = [
      for (int index = 0; index < snapshot.stages.length; index++)
        report.tryReadStageJournal(index),
    ];

    if (walked.contains(null)) {
      return null;
    }

    final journals = _comparison.tryRewriteWalk(
      walked: walked.nonNulls.toList(),
      recorded: [for (final stage in snapshot.stages) stage.journal],
      installValue: installValue,
    );

    if (journals == null) {
      return null;
    }

    return [
      for (final (index, stage) in snapshot.stages.indexed)
        stage.copyWithJournal(journals[index]),
    ];
  }
}
