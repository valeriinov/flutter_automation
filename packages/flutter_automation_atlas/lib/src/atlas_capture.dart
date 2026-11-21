import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';

import 'package:flutter_automation_atlas/src/atlas_runner_process.dart';
import 'package:flutter_automation_atlas/src/atlas_flutter_run_session.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_hashes.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_record.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_order.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replay.dart';
import 'package:flutter_automation_atlas/src/atlas_remote_shots.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_builder.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_diff.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_merge.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_stage_scope.dart';
import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_store.dart';

typedef _StoredWalk = ({
  AtlasVariantDefinition variant,
  AtlasSnapshot snapshot,
  bool isMerged,
  Set<int> shotStages,
  bool isEndShot,
});

typedef _MockRejection = ({
  AtlasVariantDefinition variant,
  AtlasMockReplayOutcome outcome,
});

/// {@category Utils}
///
/// Walks variants on the booted simulator in one locale and stores each walk
/// as the snapshot of its variant in that locale.
///
/// The app is launched once and restarted before every variant; each walk is a
/// runner capture turned into a snapshot, its screenshots moved into the shots
/// directory, and what it changed printed to stdout. A walk the runner stopped
/// is printed and counted as failed, so the variants after it are walked all
/// the same.
///
/// With a remote shot storage (`AtlasProject.shotStorage`), the screenshots
/// of a walk go to the cache folder. Just before a snapshot is written, the
/// capture puts into the storage each shot of the snapshot whose file the
/// cache holds and that the storage did not confirm in this run. A failed
/// upload fails the variant, and its previous snapshot stays.
///
/// A variant named with stages walks only up to the last of them, shoots only
/// them and places them onto its stored snapshot, its stages `stale` found
/// fresh rebased onto the current tree first; when the stored stages do not
/// line up with the walk, the variant is walked again as a whole. Once every
/// variant is walked, the merged snapshots are replayed against the mock in
/// one run, and a variant the mock answers otherwise than its merged snapshot
/// recorded is walked again as a whole.
///
/// A capture in the default locale then walks every stored variant headless
/// once and writes the frame and journal hashes that walk showed onto the
/// stages and the end it shot, with the renderer of the walk
/// ([AtlasHeadlessHashes.apply]); a stage it did not shoot keeps its
/// hashes while they come from the same renderer. A variant whose current
/// report is absent, walked other code, or misses a frame, a journal or the
/// end is named, and the stages and the end it shot take what that report
/// holds, no hash where it holds none.
///
/// The main variant of a variant is the one its `stateOf` names, else the
/// default variant of its flow; its stored snapshot lends the shots of the
/// stages whose steps both walk alike, whatever mock each runs against.
final class AtlasCapture {
  static const _captureDirectoryPrefix = 'atlas-capture-';
  static const _captureErrorKeys = [
    'manifestError',
    'endScreenshotError',
    'endJournalError',
  ];
  static const AtlasStageSelection _wholeSelection = (
    stages: [],
    attributedPaths: {},
    freshStages: [],
  );

  final AtlasLocations _paths;
  final String _locale;
  final AtlasMockReplay _mockReplay;
  final AtlasHeadlessPass _headlessPass;
  final AtlasRemoteShots? _remoteShots;

  /// The [mockReplay] parameter replays the answers of the mock a merged
  /// snapshot recorded, under `flutter test` when absent; the [headlessPass]
  /// parameter walks the stored variants headless, on the working tree when
  /// absent.
  AtlasCapture(
    this._paths,
    this._locale, {
    AtlasMockReplay? mockReplay,
    AtlasHeadlessPass? headlessPass,
  }) : _mockReplay =
           mockReplay ??
           AtlasMockReplayProcess(
             _paths.rootPath,
             _paths.project.mockReplayEntry,
             _paths.project.launchSettings,
           ),
       _headlessPass = headlessPass ?? AtlasHeadless(_paths).run,
       _remoteShots = AtlasRemoteShots.tryCreate(_paths);

  /// Captures [variants] and returns whether every walk passed.
  ///
  /// The [stageSelections] parameter names, by variant id, the stages to
  /// capture of a variant that is not walked as a whole.
  Future<bool> run(
    List<AtlasVariantDefinition> variants, {
    Map<String, AtlasStageSelection> stageSelections = const {},
  }) async {
    if (variants.isEmpty) {
      stdout.writeln('Nothing to capture.');

      return true;
    }

    final sourceStamp = AtlasStore(_paths).tryReadSourceStamp();

    final simulator = await AutomationIosSimulator.find();

    await simulator.prepareKeyboard();

    final session = _SimulatorSession(_paths, simulator.udid, _locale);

    try {
      return await captureWalks(
        variants,
        device: simulator.device,
        walker: session,
        stageSelections: stageSelections,
        sourceStamp: sourceStamp,
      );
    } finally {
      await session.stop();
    }
  }

  /// Stores what [walker] walks for each of [variants] as its snapshot, taken
  /// on [device], and returns whether every walk passed; [walker] is stopped
  /// once a round of walks is done, before the mock replay and the headless
  /// walk.
  ///
  /// The [stageSelections] parameter names, by variant id, the stages to
  /// capture of a variant that is not walked as a whole; the [sourceStamp]
  /// parameter is the commit and the dirty flag every snapshot records, read
  /// from git before the first walk when absent.
  Future<bool> captureWalks(
    List<AtlasVariantDefinition> variants, {
    required String device,
    required AtlasWalker walker,
    Map<String, AtlasStageSelection> stageSelections = const {},
    AtlasSourceStamp? sourceStamp,
  }) async {
    final stamp = sourceStamp ?? AtlasStore(_paths).tryReadSourceStamp();
    final firstWalks = <String, _StoredWalk?>{};

    for (final variant in variants) {
      firstWalks[variant.id] = await _captureVariant(
        variant,
        device: device,
        walker: walker,
        selection: stageSelections[variant.id] ?? _wholeSelection,
        sourceStamp: stamp,
      );
    }

    await walker.stop();

    final storedWalks = {
      ...firstWalks,
      ...await _rewalkMockRejections(
        firstWalks.values.nonNulls,
        device: device,
        walker: walker,
        sourceStamp: stamp,
      ),
    };

    await _recordHeadlessHashes(storedWalks.values.nonNulls.toList());

    return storedWalks.values.every(
      (storedWalk) => storedWalk?.snapshot.ok ?? false,
    );
  }

  Future<Map<String, _StoredWalk?>> _rewalkMockRejections(
    Iterable<_StoredWalk> walks, {
    required String device,
    required AtlasWalker walker,
    required AtlasSourceStamp? sourceStamp,
  }) async {
    final rewalks = <String, _StoredWalk?>{};

    for (final (:variant, :outcome) in _readMockRejections(walks)) {
      stdout.writeln(
        '${variant.id}: the mock answers stage ${outcome.stage} otherwise '
        '(${outcome.difference}), walking it whole',
      );

      rewalks[variant.id] = await _captureVariant(
        variant,
        device: device,
        walker: walker,
        selection: _wholeSelection,
        sourceStamp: sourceStamp,
      );
    }

    await walker.stop();

    return rewalks;
  }

  Future<void> _recordHeadlessHashes(List<_StoredWalk> walks) async {
    if (_locale != _paths.defaultLocale || walks.isEmpty) {
      return;
    }

    await _headlessPass([for (final walk in walks) walk.variant]);

    final hashes = AtlasHeadlessHashes(_paths);
    final store = AtlasSnapshotStore(_paths);

    for (final walk in walks) {
      _recordVariantHeadlessHashes(walk, store, hashes);
    }
  }

  List<_MockRejection> _readMockRejections(Iterable<_StoredWalk> walks) {
    final mergedWalks = walks.where(_isReplayable).toList();
    final outcomes = _mockReplay.replay([
      for (final walk in mergedWalks) _createReplayInput(walk),
    ]);

    return [
      for (final variant in mergedWalks.map((walk) => walk.variant))
        if (outcomes[variant.id] case final outcome? when !outcome.isSame)
          (variant: variant, outcome: outcome),
    ];
  }

  Future<_StoredWalk?> _captureVariant(
    AtlasVariantDefinition variant, {
    required String device,
    required AtlasWalker walker,
    required AtlasStageSelection selection,
    required AtlasSourceStamp? sourceStamp,
  }) async {
    final stages = selection.stages;
    final store = AtlasSnapshotStore(_paths);
    final previous = store.tryRead(
      flow: variant.flow,
      variant: variant.name,
      locale: _locale,
    );
    final scope = previous == null || _isEveryStageSelected(previous, stages)
        ? const AtlasStageScope.every()
        : AtlasStageScope.of(stages, stageCount: previous.stages.length);

    stdout.writeln(
      scope.isEveryStage
          ? variant.id
          : '${variant.id} stages ${scope.stages.join(',')}',
    );

    try {
      final walked = await _walk(
        variant,
        scope,
        device: device,
        walker: walker,
      );

      final merged = _tryMerge(walked, previous, scope, selection);
      final walkedSnapshot =
          merged ?? await _walkWhole(variant, device: device, walker: walker);
      final snapshot = _stamp(walkedSnapshot, sourceStamp);
      final isMerged = merged != null && !scope.isEveryStage;

      await _remoteShots?.uploadUnconfirmed(snapshot.shots);

      store.write(snapshot);
      _printDiff(
        AtlasSnapshotDiff.describe(previous: previous, next: snapshot),
      );

      return (
        variant: variant,
        snapshot: snapshot,
        isMerged: isMerged,
        shotStages: isMerged
            ? _readMergedShotStages(scope, previous, snapshot)
            : Iterable<int>.generate(snapshot.stages.length).toSet(),
        isEndShot: !isMerged || scope.until == null,
      );
    } on AtlasException catch (error) {
      stderr.writeln(error.message);

      return null;
    }
  }

  AtlasSnapshot _stamp(AtlasSnapshot snapshot, AtlasSourceStamp? stamp) {
    if (stamp == null) {
      return snapshot;
    }

    return snapshot.copyWithSource(
      commit: stamp.commit,
      isDirty: stamp.isDirty,
    );
  }

  void _recordVariantHeadlessHashes(
    _StoredWalk walk,
    AtlasSnapshotStore store,
    AtlasHeadlessHashes hashes,
  ) {
    final snapshot = walk.snapshot;
    final report = hashes.tryReadCurrentReport(snapshot);
    final missingHashes = AtlasHeadlessHashes.tryDescribeMissingHashes(
      report,
      snapshot,
    );

    if (missingHashes != null) {
      AtlasHeadlessRecord.printLeft(walk.variant.id, missingHashes);
    }

    store.write(
      hashes.apply(
        snapshot,
        report,
        shotStages: walk.shotStages,
        isEndShot: walk.isEndShot,
      ),
    );
  }

  bool _isReplayable(_StoredWalk walk) {
    final snapshot = walk.snapshot;

    return walk.isMerged && snapshot.ok && snapshot.manifest.isNotEmpty;
  }

  AtlasMockReplayInput _createReplayInput(_StoredWalk walk) {
    final variant = walk.variant;

    return AtlasMockReplayInput.fromSnapshot(
      id: variant.id,
      scenario: variant.scenario,
      snapshot: walk.snapshot,
      schema: _paths.project.journalSchema,
    );
  }

  bool _isEveryStageSelected(AtlasSnapshot previous, List<int> stages) {
    final selectedStages = stages.toSet();

    return Iterable<int>.generate(
      previous.stages.length,
    ).every(selectedStages.contains);
  }

  AtlasSnapshot? _tryMerge(
    AtlasSnapshot walked,
    AtlasSnapshot? previous,
    AtlasStageScope scope,
    AtlasStageSelection selection,
  ) {
    if (previous == null || scope.isEveryStage) {
      return walked;
    }

    final existing = AtlasSnapshotMerge.removePaths(previous, {
      for (final path in previous.manifest.keys)
        if (!File(_paths.resolve(path)).existsSync()) path,
    });

    return AtlasSnapshotMerge.tryMerge(
      captured: walked,
      previous: AtlasSnapshotMerge.rebaseFreshStages(
        existing,
        selection,
        AtlasSnapshotBuilder(
          _paths,
          _locale,
        ).hashManifest(existing.manifest.keys),
      ),
      scope: scope,
      mockDirectory: _paths.project.staleSettings.mockDirectory,
      attributedPaths: selection.attributedPaths,
    );
  }

  Future<AtlasSnapshot> _walkWhole(
    AtlasVariantDefinition variant, {
    required String device,
    required AtlasWalker walker,
  }) {
    stdout.writeln(
      '  the stages walked do not merge, walking ${variant.id} whole',
    );

    return _walk(
      variant,
      const AtlasStageScope.every(),
      device: device,
      walker: walker,
    );
  }

  void _printDiff(List<String> lines) {
    for (final line in lines) {
      stdout.writeln('  $line');
    }
  }

  Set<int> _readMergedShotStages(
    AtlasStageScope scope,
    AtlasSnapshot? previous,
    AtlasSnapshot merged,
  ) {
    final previousStageCount = previous?.stages.length ?? 0;

    return {
      ...scope.stages,
      for (
        int index = previousStageCount;
        index < merged.stages.length;
        index++
      )
        index,
    };
  }

  Future<AtlasSnapshot> _walk(
    AtlasVariantDefinition variant,
    AtlasStageScope scope, {
    required String device,
    required AtlasWalker walker,
  }) async {
    final store = AtlasSnapshotStore(_paths);
    final previous = store.tryRead(
      flow: variant.flow,
      variant: variant.name,
      locale: _locale,
    );
    final mainVariant = _tryFindMainVariant(variant);

    final captureDirectory = await Directory.systemTemp.createTemp(
      _captureDirectoryPrefix,
    );

    try {
      final report = await walker.walk(variant, scope, captureDirectory);

      _failOnRunnerError(report);
      _warnOnCaptureErrors(report);

      final captured = AtlasSnapshotBuilder(_paths, _locale).build(
        report: report,
        device: device,
        defHash: variant.defHash,
        stepHashes: variant.stageStepHashes,
      );

      return await AtlasShotStore(_paths, remoteShots: _remoteShots).store(
        captured: AtlasJournalOrder.keepPreviousOrder(
          captured: captured,
          previous: previous,
        ),
        previous: previous,
        captureDirectory: captureDirectory.path,
        mainVariantShots: mainVariant == null
            ? const []
            : _readSameStepsShots(variant, mainVariant, store),
      );
    } finally {
      await captureDirectory.delete(recursive: true);
    }
  }

  AtlasVariantDefinition? _tryFindMainVariant(AtlasVariantDefinition variant) {
    final flow = AtlasDefinitions.read(_paths).findFlow(variant.flow);
    final stateOf = variant.automationFlow.stateOf;
    final mainVariant = stateOf == null
        ? flow.variants.firstWhereOrNull((candidate) => candidate.isDefault)
        : flow.findVariant(stateOf);

    return mainVariant?.name == variant.name ? null : mainVariant;
  }

  void _failOnRunnerError(Map<String, Object?> report) {
    final error = report['error'];

    if (error == null) {
      return;
    }

    throw AtlasException('The runner stopped: $error');
  }

  void _warnOnCaptureErrors(Map<String, Object?> report) {
    for (final key in _captureErrorKeys) {
      _warnOnCaptureError(key, report[key]);
    }
  }

  List<String?> _readSameStepsShots(
    AtlasVariantDefinition variant,
    AtlasVariantDefinition mainVariant,
    AtlasSnapshotStore store,
  ) {
    final stepHashes = variant.stageStepOnlyHashes;
    final mainStepHashes = mainVariant.stageStepOnlyHashes;
    final mainStages =
        store
            .tryRead(
              flow: mainVariant.flow,
              variant: mainVariant.name,
              locale: _locale,
            )
            ?.stages ??
        const [];

    return [
      for (final (index, stepHash) in stepHashes.indexed)
        stepHash == mainStepHashes.elementAtOrNull(index)
            ? mainStages.elementAtOrNull(index)?.shot
            : null,
    ];
  }

  void _warnOnCaptureError(String key, Object? error) {
    if (error == null) {
      return;
    }

    stderr.writeln('$key: $error');
  }
}

/// {@category Utils}
///
/// Walks variants on a device for a capture.
abstract interface class AtlasWalker {
  /// Walks the [scope] of [variant] into [captureDirectory] and returns the
  /// report the walk produced.
  Future<Map<String, Object?>> walk(
    AtlasVariantDefinition variant,
    AtlasStageScope scope,
    Directory captureDirectory,
  );

  /// Releases the device; the next [walk] takes it again.
  Future<void> stop();
}

/// {@category Utils}
///
/// One headless walk of [variants], answering whether every variant wrote its
/// report.
typedef AtlasHeadlessPass =
    Future<bool> Function(List<AtlasVariantDefinition> variants);

final class _SimulatorSession implements AtlasWalker {
  final AtlasLocations _paths;
  final String _deviceId;
  final String _locale;
  AtlasFlutterRunSession? _session;

  _SimulatorSession(this._paths, this._deviceId, this._locale);

  @override
  Future<Map<String, Object?>> walk(
    AtlasVariantDefinition variant,
    AtlasStageScope scope,
    Directory captureDirectory,
  ) async {
    final session = _session ??= await AtlasFlutterRunSession.start(
      _paths.project.launchSettings,
      deviceId: _deviceId,
    );

    await session.restart();

    return AtlasRunnerProcess(
      _paths,
      session.vmServiceUri,
      _locale,
    ).capture(variant, scope, captureDirectory);
  }

  @override
  Future<void> stop() async {
    final session = _session;

    _session = null;

    await session?.stop();
  }
}
