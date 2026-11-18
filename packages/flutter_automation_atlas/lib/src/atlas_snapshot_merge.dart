import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_stage_scope.dart';

/// {@category Utils}
///
/// Places the stages a partial walk shot onto the snapshot the variant held
/// before it.
///
/// A manifest file takes its new hash only when every stage whose sources
/// hold it was shot again, or every stage the widgets of the stages placed it
/// on, a file they placed on no stage taking it whenever the walk executed it;
/// every other file keeps the hash of the previous capture, since the
/// partial walk executed only the steps up to its stop, and a file the walk
/// executed for the first time joins with its new hash. A deleted file is
/// taken out of the previous snapshot first ([removePaths]), so it leaves the
/// manifest and the sources of every stage.
///
/// A stage `stale` found fresh on the current tree is rebased onto it first
/// ([rebaseFreshStages]), so its files take their current hash as a capture
/// of it would record them.
///
/// A mock file a previous capture held is kept only while a stage of the
/// merged snapshot was captured before stages held their anchor: `stale`
/// compares such a stage by the files of the mock, and every other stage by
/// replaying its journal.
abstract final class AtlasSnapshotMerge {
  /// The [previous] snapshot holding the stages of [scope] from [captured],
  /// and the stages a walk to the end added after the previous ones; `null`
  /// when the walks do not line up: a shot stage is missing or is another
  /// action, a walk to the end counted fewer stages or added one it did not
  /// shoot, or the walk did not execute a file only the shot stages hold or
  /// place.
  ///
  /// The [attributedPaths] parameter holds the stages the widgets of the
  /// stages placed each changed manifest file on, by path; the
  /// [mockDirectory] parameter is the folder of the mock.
  static AtlasSnapshot? tryMerge({
    required AtlasSnapshot captured,
    required AtlasSnapshot previous,
    required AtlasStageScope scope,
    required String mockDirectory,
    Map<String, Set<int>> attributedPaths = const {},
  }) {
    if (!_canMerge(captured, previous, scope)) {
      return null;
    }

    final hasWalkedToEnd = scope.until == null;
    final shotStages = scope.stages.toSet();
    final previousStages = previous.stages.indexed.toList();
    final capturedManifest = captured.manifest;
    final stages = [
      for (final (index, stage) in previousStages)
        shotStages.contains(index) ? captured.stages[index] : stage,
      if (hasWalkedToEnd) ...captured.stages.skip(previousStages.length),
    ];
    final sourceOwners = [...previousStages, ...stages.indexed];
    final shotPaths = {...previous.manifest.keys, ...capturedManifest.keys}
        .where(
          (path) =>
              _isAttributedWithin(attributedPaths[path], shotStages) ||
              _isOwnedWithin(path, sourceOwners, shotStages),
        );

    if (shotPaths.any((path) => !capturedManifest.containsKey(path))) {
      return null;
    }

    final isEveryStageAnchored = stages.every((stage) => stage.anchor != null);

    return AtlasSnapshot(
      flow: captured.flow,
      variant: captured.variant,
      locale: captured.locale,
      ok: captured.ok && stages.every((stage) => stage.ok),
      device: captured.device,
      defHash: captured.defHash,
      manifest: {
        ...capturedManifest,
        for (final MapEntry(key: path, value: hash)
            in previous.manifest.entries)
          if (!isEveryStageAnchored || !path.startsWith(mockDirectory))
            path: hash,
        for (final path in shotPaths) path: ?capturedManifest[path],
        for (final MapEntry(key: path, value: stages)
            in attributedPaths.entries)
          if (stages.isEmpty) path: ?capturedManifest[path],
      },
      stages: stages,
      end: hasWalkedToEnd ? captured.end : previous.end,
      headlessRenderer: previous.headlessRenderer,
      sourceCommit: captured.sourceCommit,
      sourceDirty: captured.sourceDirty,
    );
  }

  /// The [previous] snapshot with the [AtlasStageSelection.freshStages]
  /// of [selection] rebased onto the current tree: the `sources` of those
  /// stages take the hash [currentHashes] holds, and so does every manifest
  /// file whose stages all are fresh or shot — the stages whose sources hold
  /// it, the stages the widgets placed it on, or every stage for a file held
  /// and placed by none — and every manifest file once every stage is either.
  /// A file [currentHashes] holds no hash of keeps its own.
  static AtlasSnapshot rebaseFreshStages(
    AtlasSnapshot previous,
    AtlasStageSelection selection,
    Map<String, String> currentHashes,
  ) {
    final (:stages, :attributedPaths, :freshStages) = selection;
    final currentStages = {...stages, ...freshStages};
    final previousStages = previous.stages.indexed.toList();
    final isEveryStageCurrent = previousStages.every(
      (entry) => currentStages.contains(entry.$1),
    );
    final rebasedPaths = previous.manifest.keys.where(
      (path) =>
          isEveryStageCurrent ||
          _isAttributedWithin(attributedPaths[path], currentStages) ||
          _isOwnedWithin(path, previousStages, currentStages),
    );

    return AtlasSnapshot(
      flow: previous.flow,
      variant: previous.variant,
      locale: previous.locale,
      ok: previous.ok,
      device: previous.device,
      defHash: previous.defHash,
      manifest: {
        ...previous.manifest,
        for (final path in rebasedPaths) path: ?currentHashes[path],
      },
      stages: [
        for (final (index, stage) in previousStages)
          freshStages.contains(index)
              ? _rebaseSources(stage, currentHashes)
              : stage,
      ],
      end: previous.end,
      headlessRenderer: previous.headlessRenderer,
      sourceCommit: previous.sourceCommit,
      sourceDirty: previous.sourceDirty,
    );
  }

  /// The [snapshot] without [paths] in its manifest and in the sources of its
  /// stages.
  static AtlasSnapshot removePaths(AtlasSnapshot snapshot, Set<String> paths) {
    return AtlasSnapshot(
      flow: snapshot.flow,
      variant: snapshot.variant,
      locale: snapshot.locale,
      ok: snapshot.ok,
      device: snapshot.device,
      defHash: snapshot.defHash,
      manifest: _removeKeys(snapshot.manifest, paths),
      stages: [
        for (final stage in snapshot.stages)
          stage.copyWithHashes(
            stepHash: stage.stepHash,
            sources: _removeKeys(stage.sources, paths),
            localeKeys: stage.localeKeys,
          ),
      ],
      end: snapshot.end,
      headlessRenderer: snapshot.headlessRenderer,
      sourceCommit: snapshot.sourceCommit,
      sourceDirty: snapshot.sourceDirty,
    );
  }

  static bool _canMerge(
    AtlasSnapshot captured,
    AtlasSnapshot previous,
    AtlasStageScope scope,
  ) {
    if (scope.until == null &&
        !_isEveryAddedStageShot(captured, previous, scope)) {
      return false;
    }

    return scope.stages.every(
      (index) => _canPlaceShotStage(captured, previous, index),
    );
  }

  static bool _isAttributedWithin(Set<int>? attributedStages, Set<int> stages) {
    return attributedStages != null &&
        attributedStages.isNotEmpty &&
        stages.containsAll(attributedStages);
  }

  static bool _isOwnedWithin(
    String path,
    List<(int, AtlasStage)> sourceOwners,
    Set<int> stages,
  ) {
    final owners = {
      for (final (index, stage) in sourceOwners)
        if (stage.sources.containsKey(path)) index,
    };

    return owners.isNotEmpty && stages.containsAll(owners);
  }

  static AtlasStage _rebaseSources(
    AtlasStage stage,
    Map<String, String> currentHashes,
  ) {
    return stage.copyWithHashes(
      stepHash: stage.stepHash,
      sources: {
        for (final MapEntry(key: path, value: hash) in stage.sources.entries)
          path: currentHashes[path] ?? hash,
      },
      localeKeys: stage.localeKeys,
    );
  }

  static Map<String, String> _removeKeys(
    Map<String, String> hashes,
    Set<String> keys,
  ) {
    return {
      for (final MapEntry(key: key, value: hash) in hashes.entries)
        if (!keys.contains(key)) key: hash,
    };
  }

  static bool _isEveryAddedStageShot(
    AtlasSnapshot captured,
    AtlasSnapshot previous,
    AtlasStageScope scope,
  ) {
    final previousCount = previous.stages.length;
    final capturedCount = captured.stages.length;

    return capturedCount >= previousCount &&
        scope.stages.toSet().containsAll(
          Iterable<int>.generate(
            capturedCount - previousCount,
            (offset) => previousCount + offset,
          ),
        );
  }

  static bool _canPlaceShotStage(
    AtlasSnapshot captured,
    AtlasSnapshot previous,
    int index,
  ) {
    final stage = captured.stages.elementAtOrNull(index);

    if (stage == null) {
      return false;
    }

    return index >= previous.stages.length ||
        previous.tryFindSameActionStage(index, stage) != null;
  }
}

/// {@category Utils}
///
/// The stages to capture of a variant not walked as a whole, the stages
/// `stale` placed each changed manifest file on by widgets, by path, and the
/// stages it found fresh on the current tree.
typedef AtlasStageSelection = ({
  List<int> stages,
  Map<String, Set<int>> attributedPaths,
  List<int> freshStages,
});
