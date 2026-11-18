import 'package:flutter_automation_atlas/src/atlas_journal_comparison.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_source_hash.dart';

/// {@category Utils}
///
/// Applies the frame and journal hashes a headless walk showed to a snapshot,
/// the reference `stale` compares the next walks with, tells whether a
/// snapshot holds them from the renderer a walk runs on now and whether the
/// current headless report of a snapshot walked its manifest files as they
/// are now.
final class AtlasHeadlessHashes {
  final AtlasLocations _paths;
  final Map<String, String?> _currentHashes = {};
  String? _renderer;

  AtlasHeadlessHashes(this._paths);

  AtlasJournalComparison get _comparison {
    return AtlasJournalComparison(_paths.project.journalSchema);
  }

  /// A copy of [snapshot] with the frame and journal hashes of [report] on
  /// the stages [shotStages] names, the end frame hash of [report] on the end
  /// when [isEndShot], and the renderer a walk runs on now
  /// ([AtlasHeadless.readRenderer]); every other stage and the end keep
  /// their hashes while [snapshot] holds hashes of that renderer, and lose
  /// them otherwise.
  AtlasSnapshot apply(
    AtlasSnapshot snapshot,
    AtlasHeadlessReport? report, {
    required Set<int> shotStages,
    required bool isEndShot,
  }) {
    final renderer = _readRenderer();
    final isSameRenderer = snapshot.headlessRenderer == renderer;

    return snapshot.copyWithHeadlessWalk(
      renderer: renderer,
      stages: [
        for (final (index, stage) in snapshot.stages.indexed)
          shotStages.contains(index)
              ? _applyStageHashes(stage, report, index)
              : _keepStageHashes(stage, isSameRenderer: isSameRenderer),
      ],
      end: _resolveEndHashes(
        snapshot.end,
        report,
        isEndShot: isEndShot,
        isSameRenderer: isSameRenderer,
      ),
    );
  }

  /// Whether [report] holds the frame hash and the journal of every stage of
  /// [snapshot] and the frame hash of its end.
  static bool isComplete(AtlasHeadlessReport report, AtlasSnapshot snapshot) {
    return report.endFrameHash != null &&
        Iterable<int>.generate(
          snapshot.stages.length,
        ).every((index) => _hasStage(report, index));
  }

  /// Why [report], the current headless report of [snapshot], cannot give
  /// it the hashes of every stage and the end: absent when it can.
  static String? tryDescribeMissingHashes(
    AtlasHeadlessReport? report,
    AtlasSnapshot snapshot,
  ) {
    if (report == null) {
      return 'no current headless report';
    }

    if (!isComplete(report, snapshot)) {
      return 'the current headless report is incomplete';
    }

    return null;
  }

  /// Whether every stage and the end of [snapshot] hold their headless
  /// hashes from the renderer a walk runs on now.
  bool hasEveryHeadlessHash(AtlasSnapshot snapshot) {
    return hasEndHeadlessHash(snapshot) &&
        Iterable<int>.generate(
          snapshot.stages.length,
        ).every((index) => hasStageHeadlessHashes(snapshot, index));
  }

  /// Whether the stage of [snapshot] at [index] holds its frame and journal
  /// hashes from the renderer a walk runs on now, the last stage only while
  /// the end holds its frame hash as well.
  bool hasStageHeadlessHashes(AtlasSnapshot snapshot, int index) {
    final stage = snapshot.stages[index];

    return stage.headlessFrameHash != null &&
        stage.headlessJournalHash != null &&
        isCurrentRenderer(snapshot) &&
        _hasLastStageEnd(snapshot, index);
  }

  /// Whether the end of [snapshot] holds its frame hash from the renderer a
  /// walk runs on now.
  bool hasEndHeadlessHash(AtlasSnapshot snapshot) {
    return snapshot.end.headlessFrameHash != null &&
        isCurrentRenderer(snapshot);
  }

  /// Whether [snapshot] holds headless hashes of the renderer a walk runs on
  /// now ([AtlasHeadless.readRenderer]), read only for a snapshot
  /// naming a renderer.
  bool isCurrentRenderer(AtlasSnapshot snapshot) {
    final renderer = snapshot.headlessRenderer;

    if (renderer == null) {
      return false;
    }

    return renderer == _readRenderer();
  }

  /// The current headless report of [snapshot], absent when there is none
  /// or it walked a manifest file of [snapshot] otherwise than the file is
  /// now.
  AtlasHeadlessReport? tryReadCurrentReport(AtlasSnapshot snapshot) {
    final report = AtlasHeadlessReport.tryReadFile(
      _paths.resolveHeadlessReportPath(
        flow: snapshot.flow,
        variant: snapshot.variant,
        locale: snapshot.locale,
      ),
    );

    if (report == null || !hasCurrentSources(report, snapshot)) {
      return null;
    }

    return report;
  }

  /// Whether [report] walked every manifest file of [snapshot] as the file
  /// is now.
  bool hasCurrentSources(AtlasHeadlessReport report, AtlasSnapshot snapshot) {
    final sourceHashes = report.sourceHashes;

    if (sourceHashes == null) {
      return false;
    }

    return snapshot.manifest.keys.every(
      (path) =>
          sourceHashes.containsKey(path) &&
          sourceHashes[path] == readCurrentSourceHash(path),
    );
  }

  /// The [AtlasSourceHash] of the file at the repository [path] as it
  /// is now, read once per path; absent when the file is gone.
  String? readCurrentSourceHash(String path) {
    return _currentHashes.putIfAbsent(
      path,
      () => AtlasSourceHash.tryHashFile(_paths.resolve(path)),
    );
  }

  AtlasStage _applyStageHashes(
    AtlasStage stage,
    AtlasHeadlessReport? report,
    int index,
  ) {
    final journal = report?.tryReadStageJournal(index);

    return stage.copyWithHeadlessHashes(
      frameHash: report?.frameHashes.elementAtOrNull(index),
      journalHash: journal == null ? null : _comparison.hash(journal),
    );
  }

  static AtlasStage _keepStageHashes(
    AtlasStage stage, {
    required bool isSameRenderer,
  }) {
    if (isSameRenderer) {
      return stage;
    }

    return stage.copyWithHeadlessHashes(frameHash: null, journalHash: null);
  }

  static AtlasEnd _resolveEndHashes(
    AtlasEnd end,
    AtlasHeadlessReport? report, {
    required bool isEndShot,
    required bool isSameRenderer,
  }) {
    if (isEndShot) {
      return end.copyWithHeadlessFrameHash(report?.endFrameHash);
    }

    if (isSameRenderer) {
      return end;
    }

    return end.copyWithHeadlessFrameHash(null);
  }

  static bool _hasStage(AtlasHeadlessReport report, int index) {
    return report.frameHashes.elementAtOrNull(index) != null &&
        report.tryReadStageJournal(index) != null;
  }

  bool _hasLastStageEnd(AtlasSnapshot snapshot, int index) {
    return index != snapshot.stages.length - 1 || hasEndHeadlessHash(snapshot);
  }

  String _readRenderer() {
    return _renderer ??= AtlasHeadless.readRenderer(_paths);
  }
}
