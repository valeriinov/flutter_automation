import 'dart:io';

import 'package:collection/collection.dart';

import 'package:flutter_automation_atlas/src/atlas_declarations_store.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_hashes.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_comparison.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replay.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_stage_reach.dart';
import 'package:flutter_automation_atlas/src/atlas_translations.dart';
import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_source_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_settings.dart';
import 'package:flutter_automation_atlas/src/atlas_project.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_settings.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_schema.dart';

typedef _StageChanges = ({
  int? firstChangedStage,
  AtlasMockReplayOutcome? mockOutcome,
  Map<String, Set<int>> attributedPaths,
  _HeadlessReports headlessReports,
});

typedef _VariantChanges = ({
  AtlasMockReplayOutcome? mockOutcome,
  Map<String, Set<int>> attributedPaths,
  _HeadlessReports headlessReports,
});

typedef _HeadlessReports = ({
  AtlasHeadlessReport? current,
  AtlasHeadlessReport? baseline,
});

typedef _HeadlessShownStages = ({
  Set<int> shownStages,
  Set<int> journalStages,
  Map<int, String> journalDifferences,
});

typedef _ChangedDeclaration = ({String key, bool isRemoved});

typedef _StageJournals = ({
  List<Object?>? current,
  String? captureWalkHash,
  List<Object?>? baseline,
  List<Object?> recorded,
  String? installValue,
  bool canRewriteWalk,
});

typedef _ChangedFile = ({String path, Set<String> removedKeys});

typedef _WalkRewrite = ({String? installValue, bool canRewriteWalk});

/// {@category Utils}
///
/// Tells which variants and stages a capture no longer describes, by content
/// rather than by history, so the check holds before a snapshot is committed.
///
/// A variant is stale as a whole when it has no snapshot, when its steps or
/// mock changed in a way its stages cannot place, when the captured walk
/// failed, when the capture stored no manifest of the source files it
/// executed, or when the snapshot records no stages and a manifest file
/// changed or is gone — the first of these that holds names the reason.
///
/// Otherwise the stale stages are named: a stage whose steps up to its end
/// changed, and every stage after it, or a stage one of whose sources changed
/// or is gone. A manifest file outside the sources of every stage that
/// changed or is gone and that the widgets of the stages do not place stales
/// every stage, the mock left unreplayed, and the line of the variant names
/// it apart from the files the stages place. The journal of a stage closes
/// with the opening of the next screen, so the stage before one of those is
/// stale as well. Stages added after the recorded ones are stale as changed
/// steps. A stage one of whose localization keys changed its value or is gone
/// is stale alone, and so is the last stage for a key of the end, since
/// shooting it shoots the end.
///
/// A manifest file is compared by [AtlasSourceHash], so an edit of an
/// automation target alone changes nothing, and a stored hash of the raw
/// content still matches an unchanged file. The target enums are not
/// compared: they reach neither a frame nor the journal. The files of the
/// mock are not compared either: the mock reaches the app only through what
/// it answers, and every answer is a journal record
/// ([AtlasJournalSchema.answerKinds]).
/// [AtlasMockReplay] asks the current mock every answer the snapshot recorded,
/// and the first stage it answers differently is stale with the stage before it
/// and every stage after it, since the state diverges from there. A stage
/// captured before stages held their anchor journaled no launch or device
/// records: its launch is replayed against the one its configuration implies,
/// and its device answers are not compared.
///
/// The files [AtlasStaleSettings.uncomparedPaths] names are not compared by
/// their hash: the replay compares what the mock answers, and the analytics
/// records of each stage tell what the app logged. A stage that logged an
/// analytics event the project catalogue does not accept
/// ([AtlasProject.isCataloguedAnalytics]) is stale alone, since it logged the
/// event.
///
/// A stage that recorded the widgets visible on its frame (the last stage
/// with those of the end) narrows a changed manifest file with a
/// [AtlasDeclarationsStore] record to its changed declarations: those
/// whose hash differs from the record, the added and the removed, a class
/// member being a declaration of its own. A changed declaration stales, as
/// [AtlasStaleReason.stageCode], every stage with a widget that is it,
/// owns it or reaches it in [AtlasStageReach]; one reached only through
/// a DI edge stales the first stage reaching it and every stage after it. A
/// removed declaration is in no reach of the current code, and every
/// reference to it changed with it or now resolves to another declaration of
/// its name: it stales the stages showing a widget of its name and those
/// reaching a declaration of its name. A removed member of a class still
/// declared stales the stages showing that class as a widget and those
/// reaching the class together with a declaration or a member of its name;
/// the members of a removed class follow the class.
/// A deleted file with a record has every recorded declaration removed. A
/// file with no declaration changed — its directives, the order of its
/// declarations or its comments edited — stales no stage, unless it uses the
/// name declared more than once in the project or its imported packages
/// ([AtlasStageReach.isNameDeclaredMoreThanOnce]), which an edit of its
/// imports may have bound to another declaration: then every declaration of
/// the file counts as changed. A file with another declaration no stage
/// reaches or with no record follows the sources rule above, and a stage
/// without recorded widgets follows it for every file. The reach resolves
/// `lib/` with `package:analyzer` once per check, and only when a snapshot
/// records widgets and a changed file has a record.
///
/// A stage stale for [AtlasStaleReason.stageCode] alone shows its frame
/// alike when its frame hash in the current headless report of the variant
/// ([AtlasHeadless]) equals the one in the baseline report, walked on
/// the code of the commit the shots of the snapshot were taken on, the last
/// stage with the end as well, and no path that stales it changed a
/// declaration the walk stands in for or skips
/// ([AtlasHeadlessSettings.isStubbedDeclaration]). Such a stage is fresh when
/// the journal the current report holds for it is the baseline report's or
/// its own ([AtlasJournalComparison]). Otherwise it is stale as
/// [AtlasStaleReason.stageJournal] when the baseline report holds its
/// own journal, which proves the walk writes what the capture wrote, and the
/// current journal holds no value only the walk drew
/// ([_comparison.tryDescribeWalkValue]) — or the walk shows
/// every stage of the snapshot alike and journals each as itself, as the
/// baseline walk does or as the baseline walk writes it, so the journals of
/// the walk replace every journal of the snapshot together — and the current
/// journal replaces it without a device; when not, it stays stale for code
/// and the line names how the baseline journal differs from its own, or the
/// value the walk drew. A
/// current report counts only while every manifest file of the snapshot has
/// the hash it recorded, and a baseline report only while it names that
/// commit. A variant missing the current report, or a stage that report or
/// the one it is compared with holds no frame hash or journal of, stays as
/// the rules above tell. A variant whose
/// code stages all show their frame alike names no changed path. The stage
/// before a stale stage is not added for its journal once the headless
/// reports showed that stage alike.
///
/// A stage holding the frame and journal hashes the headless walk of its
/// capture wrote ([AtlasStage.headlessFrameHash]), on the renderer a
/// walk runs on now ([AtlasHeadless.readRenderer]), compares its frame
/// and journal with them in place of the baseline report, the last stage
/// only while the end holds its frame hash as well; the line of such a stage
/// names how the current journal differs from its own. A stage without them
/// takes the baseline report, and a variant whose every stage and end hold
/// them reads no baseline report.
///
/// A snapshot without stages whose manifest file changed is fresh when the
/// current report walked every step and ended on the frame whose hash the end
/// holds from a walk on the renderer of now, or, without that hash, on the
/// frame the baseline report ended on, and no changed path changed a
/// declaration the walk stands in for or skips; it holds no journal to
/// compare, and it is stale for [AtlasStaleReason.code] otherwise.
///
/// Every snapshot and value is read in one locale: a variant never captured
/// in it is new.
final class AtlasStaleCheck {
  static const _deletedSuffix = ' (deleted)';
  static const _memberSeparator = '.';
  static final _identifierPattern = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*');

  final AtlasLocations _paths;
  final String _locale;
  final AtlasJournalComparison _comparison;
  final AtlasMockReplay _mockReplay;
  final AtlasDeclarationsStore _declarationsStore;
  final AtlasHeadlessHashes _headlessHashes;
  final Map<String, ({String? raw, String? normalized})> _currentHashes = {};
  final Map<(String, String), List<_ChangedDeclaration>?> _changedDeclarations =
      {};
  final Map<String, AtlasReachedDeclarations> _reachedByWidget = {};
  final String? Function(String snapshotPath) _readSnapshotCommit;
  AtlasStageReach? _reach;

  /// The [mockReplay] parameter replays the answers of the mock a snapshot
  /// recorded, under `flutter test` when absent; the [snapshotCommitReader]
  /// parameter names the commit the shots of a snapshot file were taken on,
  /// read from git when absent.
  AtlasStaleCheck(
    this._paths,
    this._locale, {
    AtlasMockReplay? mockReplay,
    String? Function(String snapshotPath)? snapshotCommitReader,
  }) : _comparison = AtlasJournalComparison(_paths.project.journalSchema),
       _mockReplay =
           mockReplay ??
           AtlasMockReplayProcess(
             _paths.rootPath,
             _paths.project.mockReplayEntry,
             _paths.project.launchSettings,
           ),
       _declarationsStore = AtlasDeclarationsStore(_paths),
       _headlessHashes = AtlasHeadlessHashes(_paths),
       _readSnapshotCommit =
           snapshotCommitReader ??
           ((snapshotPath) =>
               AtlasHeadless.tryReadSnapshotCommit(_paths, snapshotPath));

  /// The staleness of each of [variants], in their order.
  Future<List<AtlasStaleness>> check(
    List<AtlasVariantDefinition> variants,
  ) async {
    final translations = AtlasTranslations.read(_paths, _locale);
    final store = AtlasSnapshotStore(_paths);
    final snapshots = {
      for (final variant in variants)
        variant.id: store.tryRead(
          flow: variant.flow,
          variant: variant.name,
          locale: _locale,
        ),
    };
    final attributedPaths = {
      for (final variant in variants)
        variant.id: await _attributeChangedPaths(snapshots[variant.id]),
    };
    final mockOutcomes = _mockReplay.replay([
      for (final variant in variants)
        ?_tryCreateReplayInput(
          variant,
          snapshots[variant.id],
          attributedPaths[variant.id] ?? const {},
        ),
    ]);

    return variants
        .map(
          (variant) =>
              _checkVariant(variant, snapshots[variant.id], translations, (
                mockOutcome: mockOutcomes[variant.id],
                attributedPaths: attributedPaths[variant.id] ?? const {},
                headlessReports: _readHeadlessReports(
                  variant,
                  snapshots[variant.id],
                ),
              )),
        )
        .toList();
  }

  Future<Map<String, Set<int>>> _attributeChangedPaths(
    AtlasSnapshot? snapshot,
  ) async {
    if (snapshot == null || !snapshot.ok || !_hasStageWidgets(snapshot)) {
      return const {};
    }

    final changedDeclarations = {
      for (final MapEntry(key: path, value: hash) in snapshot.manifest.entries)
        if (_isComparedPath(path) &&
            _tryDescribeChangedPath(path, hash) != null)
          path: ?_tryReadChangedDeclarations(path, hash),
    };

    if (changedDeclarations.isEmpty) {
      return const {};
    }

    final reach = _reach ??= await AtlasStageReach.read(_paths);

    return {
      for (final MapEntry(key: path, value: declarations)
          in changedDeclarations.entries)
        path: ?_tryAttributePath(snapshot, reach, path, declarations),
    };
  }

  AtlasMockReplayInput? _tryCreateReplayInput(
    AtlasVariantDefinition variant,
    AtlasSnapshot? snapshot,
    Map<String, Set<int>> attributedPaths,
  ) {
    if (snapshot == null || !snapshot.ok || snapshot.manifest.isEmpty) {
      return null;
    }

    final hasSameDefinition = snapshot.defHash == variant.defHash;
    final firstChangedStage = hasSameDefinition
        ? null
        : _tryFindFirstChangedStage(snapshot, variant);

    if (!hasSameDefinition && (firstChangedStage ?? 0) == 0) {
      return null;
    }

    if (_readVariantPaths(snapshot, attributedPaths).isNotEmpty) {
      return null;
    }

    return AtlasMockReplayInput.fromSnapshot(
      id: variant.id,
      scenario: variant.scenario,
      snapshot: snapshot,
      schema: _paths.project.journalSchema,
    );
  }

  AtlasStaleness _checkVariant(
    AtlasVariantDefinition variant,
    AtlasSnapshot? snapshot,
    AtlasTranslations translations,
    _VariantChanges changes,
  ) {
    if (snapshot == null) {
      return AtlasStaleness.variant(variant, AtlasStaleReason.noSnapshot);
    }

    final hasSameDefinition = snapshot.defHash == variant.defHash;
    final firstChangedStage = hasSameDefinition
        ? null
        : _tryFindFirstChangedStage(snapshot, variant);

    if (!hasSameDefinition && firstChangedStage == null) {
      return AtlasStaleness.variant(variant, AtlasStaleReason.definition);
    }

    if (!snapshot.ok) {
      return AtlasStaleness.variant(variant, AtlasStaleReason.failed);
    }

    if (snapshot.manifest.isEmpty) {
      return AtlasStaleness.variant(variant, AtlasStaleReason.noManifest);
    }

    return _resolveStageStaleness(
      snapshot,
      variant,
      translations,
      changes: (
        firstChangedStage: firstChangedStage,
        mockOutcome: changes.mockOutcome,
        attributedPaths: changes.attributedPaths,
        headlessReports: changes.headlessReports,
      ),
    );
  }

  _HeadlessReports _readHeadlessReports(
    AtlasVariantDefinition variant,
    AtlasSnapshot? snapshot,
  ) {
    if (snapshot == null) {
      return (current: null, baseline: null);
    }

    final current = _tryReadHeadlessReport(variant, isBaseline: false);

    if (current == null ||
        !_headlessHashes.hasCurrentSources(current, snapshot)) {
      return (current: null, baseline: null);
    }

    if (_headlessHashes.hasEveryHeadlessHash(snapshot)) {
      return (current: current, baseline: null);
    }

    final baseline = _tryReadHeadlessReport(variant, isBaseline: true);

    return (
      current: current,
      baseline: baseline != null && _isOnSnapshotCommit(baseline, variant)
          ? baseline
          : null,
    );
  }

  bool _hasStageWidgets(AtlasSnapshot snapshot) {
    return Iterable<int>.generate(
      snapshot.stages.length,
    ).any((index) => _tryReadStageWidgets(snapshot, index) != null);
  }

  Set<int>? _tryAttributePath(
    AtlasSnapshot snapshot,
    AtlasStageReach reach,
    String path,
    List<_ChangedDeclaration> declarations,
  ) {
    final changedDeclarations =
        declarations.isEmpty && _usesNameDeclaredInSeveralFiles(reach, path)
        ? _readEveryDeclaration(path)
        : declarations;
    final removedKeys = {
      for (final declaration in changedDeclarations)
        if (declaration.isRemoved) declaration.key,
    };
    final declarationStages = changedDeclarations
        .map(
          (declaration) => _tryAttributeDeclaration(snapshot, reach, (
            path: path,
            removedKeys: removedKeys,
          ), declaration),
        )
        .toList();

    if (declarationStages.contains(null)) {
      return null;
    }

    return {
      for (final stages in declarationStages) ...?stages,
      ..._readStagesWithoutWidgets(snapshot, path),
    };
  }

  int? _tryFindFirstChangedStage(
    AtlasSnapshot snapshot,
    AtlasVariantDefinition variant,
  ) {
    final stepHashes = variant.stageStepHashes;
    final recordedHashes = snapshot.stages
        .map((stage) => stage.stepHash)
        .toList();

    if (!_canPlaceStepHashes(recordedHashes, stepHashes)) {
      return null;
    }

    final firstChangedStage = Iterable<int>.generate(
      recordedHashes.length,
    ).firstWhereOrNull((index) => stepHashes[index] != recordedHashes[index]);

    if (firstChangedStage != null) {
      return firstChangedStage;
    }

    return stepHashes.length > recordedHashes.length
        ? recordedHashes.length
        : null;
  }

  AtlasStaleness _resolveStageStaleness(
    AtlasSnapshot snapshot,
    AtlasVariantDefinition variant,
    AtlasTranslations translations, {
    required _StageChanges changes,
  }) {
    final (
      :firstChangedStage,
      :mockOutcome,
      :attributedPaths,
      :headlessReports,
    ) = changes;
    final changedPaths = {
      for (final MapEntry(key: path, value: description)
          in _describeChangedPaths(snapshot).entries)
        if (attributedPaths[path]?.isNotEmpty ?? true) path: description,
    };
    final variantPaths = _readVariantPaths(snapshot, attributedPaths);

    if (variantPaths.isNotEmpty && snapshot.stages.isEmpty) {
      if (_isWalkShownAlike(snapshot, headlessReports, variantPaths)) {
        return AtlasStaleness.variant(variant, AtlasStaleReason.fresh);
      }

      return AtlasStaleness(
        variant: variant,
        reason: AtlasStaleReason.code,
        changedPaths: changedPaths.values.toList(),
        changedTranslationKeys: const [],
        stages: const [],
        attributedPaths: const {},
      );
    }

    final unattributedPaths = [
      for (final path in variantPaths) ?changedPaths[path],
    ];
    final indexedStages = snapshot.stages.indexed.toList();
    final endTranslationKeys = snapshot.end.localeKeys;
    final shownTranslationKeys = [
      for (final stage in snapshot.stages) ...stage.localeKeys.entries,
      ...endTranslationKeys.entries,
    ];
    final changedTranslationKeys = {
      for (final MapEntry(key: key, value: hash) in shownTranslationKeys)
        key: ?_tryDescribeChangedLocaleKey(translations, key, hash),
    };
    final localeStages = {
      for (final (index, stage) in indexedStages)
        if (stage.localeKeys.keys.any(changedTranslationKeys.containsKey))
          index,
      if (endTranslationKeys.keys.any(changedTranslationKeys.containsKey))
        ?_tryFindLastStage(snapshot),
    };
    final definitionStages = {
      if (firstChangedStage != null)
        for (
          int index = firstChangedStage;
          index < variant.stageStepHashes.length;
          index += 1
        )
          index,
    };
    final codeStagePaths = _readCodeStagePaths(
      snapshot,
      changedPaths: changedPaths.keys.toSet(),
      attributedPaths: attributedPaths,
      variantPaths: variantPaths,
    );
    final mockStages = _readMockStages(snapshot, mockOutcome);
    final analyticsStages = {
      for (final (index, stage) in indexedStages)
        if (stage.journal.any(_isOffCatalogueEvent)) index,
    };
    final otherStages = {
      ...definitionStages,
      ...mockStages,
      ...analyticsStages,
      ...localeStages,
    };
    final (
      :shownStages,
      :journalStages,
      :journalDifferences,
    ) = _readHeadlessShownStages(
      snapshot,
      headlessReports,
      codeStagePaths: codeStagePaths,
      otherStages: otherStages,
    );
    final codeStages = codeStagePaths.keys
        .toSet()
        .difference(shownStages)
        .difference(journalStages);
    final isClearedByHeadless = codeStages.isEmpty && codeStagePaths.isNotEmpty;

    return AtlasStaleness(
      variant: variant,
      reason: _resolveStageReason([
        (AtlasStaleReason.stageDefinition, definitionStages),
        (AtlasStaleReason.stageCode, codeStages),
        (AtlasStaleReason.stageMock, mockStages),
        (AtlasStaleReason.stageJournal, journalStages),
        (AtlasStaleReason.stageAnalytics, analyticsStages),
        (AtlasStaleReason.locale, localeStages),
      ]),
      changedPaths: [
        if (!isClearedByHeadless)
          for (final MapEntry(key: path, value: description)
              in changedPaths.entries)
            if (!variantPaths.contains(path)) description,
      ],
      unattributedPaths: isClearedByHeadless ? const [] : unattributedPaths,
      changedTranslationKeys: changedTranslationKeys.values.toList()..sort(),
      stages: ({
        ..._addJournalStages({
          ...definitionStages,
          ...codeStages,
          ...mockStages,
        }, shownStages: shownStages.union(journalStages)),
        ...journalStages,
        ...analyticsStages,
        ...localeStages,
      }.toList()..sort()),
      attributedPaths: attributedPaths,
      mockDifference: mockStages.isEmpty ? null : mockOutcome?.difference,
      journalStages: journalStages.toList()..sort(),
      journalDifferences: {
        for (final MapEntry(key: index, value: difference)
            in journalDifferences.entries)
          if (codeStages.contains(index)) index: difference,
      },
    );
  }

  AtlasHeadlessReport? _tryReadHeadlessReport(
    AtlasVariantDefinition variant, {
    required bool isBaseline,
  }) {
    return AtlasHeadlessReport.tryReadFile(
      _paths.resolveHeadlessReportPath(
        flow: variant.flow,
        variant: variant.name,
        locale: _locale,
        isBaseline: isBaseline,
      ),
    );
  }

  bool _isOnSnapshotCommit(
    AtlasHeadlessReport baseline,
    AtlasVariantDefinition variant,
  ) {
    final snapshotCommit = _readSnapshotCommit(
      _paths.resolveSnapshotPath(
        flow: variant.flow,
        variant: variant.name,
        locale: _locale,
      ),
    );

    return snapshotCommit != null && baseline.commit == snapshotCommit;
  }

  bool _usesNameDeclaredInSeveralFiles(AtlasStageReach reach, String path) {
    final file = File(_paths.resolve(path));

    if (!file.existsSync()) {
      return false;
    }

    final source = AtlasSourceHash.mask(file.readAsStringSync());

    return {
      for (final match in _identifierPattern.allMatches(source)) match[0],
    }.nonNulls.any(reach.isNameDeclaredMoreThanOnce);
  }

  List<_ChangedDeclaration> _readEveryDeclaration(String path) {
    return [
      for (final declaration
          in _paths
              .readDeclarations(File(_paths.resolve(path)).readAsStringSync())
              .declarations)
        (key: declaration.key, isRemoved: false),
    ];
  }

  Set<int>? _tryAttributeDeclaration(
    AtlasSnapshot snapshot,
    AtlasStageReach reach,
    _ChangedFile file,
    _ChangedDeclaration declaration,
  ) {
    final (:path, :removedKeys) = file;
    final (:key, :isRemoved) = declaration;
    final separatorIndex = key.indexOf(_memberSeparator);

    if (isRemoved && separatorIndex < 0) {
      return _readStagesReachingName(snapshot, reach, key);
    }

    if (isRemoved) {
      final ownerName = key.substring(0, separatorIndex);

      return removedKeys.contains(ownerName)
          ? const {}
          : _readStagesReachingMemberName(
              snapshot,
              reach,
              ownerName: ownerName,
              name: key.substring(separatorIndex + 1),
            );
    }

    final id = AtlasStageReach.idOf(path, key);
    final directStages = _readStagesReaching(
      snapshot,
      reach,
      (reached) => reached.ids.contains(id),
    );
    final firstDiStage = _readStagesReaching(
      snapshot,
      reach,
      (reached) => reached.diIds.contains(id),
    ).minOrNull;
    final stages = {
      ...directStages,
      if (firstDiStage != null)
        for (
          int index = firstDiStage;
          index < snapshot.stages.length;
          index += 1
        )
          index,
    };

    return stages.isEmpty ? null : stages;
  }

  Set<int> _readStagesWithoutWidgets(AtlasSnapshot snapshot, String path) {
    final isStageSource = _isStageSource(snapshot, path);

    return {
      for (final (index, stage) in snapshot.stages.indexed)
        if (_tryReadStageWidgets(snapshot, index) == null &&
            (!isStageSource || stage.sources.containsKey(path)))
          index,
    };
  }

  bool _canPlaceStepHashes(
    List<String?> recordedHashes,
    List<String> stepHashes,
  ) {
    return recordedHashes.isNotEmpty &&
        recordedHashes.length <= stepHashes.length &&
        !recordedHashes.contains(null);
  }

  List<String> _readVariantPaths(
    AtlasSnapshot snapshot,
    Map<String, Set<int>> attributedPaths,
  ) {
    return _describeChangedPaths(snapshot).keys
        .where(
          (path) =>
              !attributedPaths.containsKey(path) &&
              !_isStageSource(snapshot, path),
        )
        .toList();
  }

  bool _isWalkShownAlike(
    AtlasSnapshot snapshot,
    _HeadlessReports headlessReports,
    List<String> changedPaths,
  ) {
    final (:current, :baseline) = headlessReports;

    if (current == null) {
      return false;
    }

    return _hasSameEndFrame(snapshot, current, baseline) &&
        !changedPaths.any((path) => _isStubbedChange(snapshot, path));
  }

  String? _tryDescribeChangedLocaleKey(
    AtlasTranslations translations,
    String key,
    String hash,
  ) {
    final currentHash = translations.tryHashValue(key);

    if (currentHash == null) {
      return '$key$_deletedSuffix';
    }

    return currentHash == hash ? null : key;
  }

  Map<int, Set<String>> _readCodeStagePaths(
    AtlasSnapshot snapshot, {
    required Set<String> changedPaths,
    required Map<String, Set<int>> attributedPaths,
    required List<String> variantPaths,
  }) {
    final codeStagePaths = <int, Set<String>>{};

    for (final (index, stage) in snapshot.stages.indexed) {
      final paths = {
        for (final path in stage.sources.keys)
          if (changedPaths.contains(path) && !attributedPaths.containsKey(path))
            path,
        for (final MapEntry(key: path, value: stages)
            in attributedPaths.entries)
          if (stages.contains(index)) path,
        ...variantPaths,
      };

      if (paths.isNotEmpty) {
        codeStagePaths[index] = paths;
      }
    }

    return codeStagePaths;
  }

  Set<int> _readMockStages(
    AtlasSnapshot snapshot,
    AtlasMockReplayOutcome? mockOutcome,
  ) {
    final firstStage = mockOutcome?.stage;

    if (firstStage == null) {
      return const {};
    }

    return {
      for (int index = firstStage; index < snapshot.stages.length; index += 1)
        index,
    };
  }

  bool _isOffCatalogueEvent(Object? record) {
    if (record is! Map<String, Object?> ||
        record['kind'] != _paths.project.journalSchema.analyticsKind) {
      return false;
    }

    return !_paths.project.isCataloguedAnalytics(record);
  }

  _HeadlessShownStages _readHeadlessShownStages(
    AtlasSnapshot snapshot,
    _HeadlessReports headlessReports, {
    required Map<int, Set<String>> codeStagePaths,
    required Set<int> otherStages,
  }) {
    final (:current, :baseline) = headlessReports;

    if (current == null) {
      return (
        shownStages: const {},
        journalStages: const {},
        journalDifferences: const {},
      );
    }

    final frameStages = {
      for (final MapEntry(key: index, value: paths) in codeStagePaths.entries)
        if (!otherStages.contains(index) &&
            !paths.any((path) => _isStubbedChange(snapshot, path)))
          if (_hasSameFrame(snapshot, current, baseline, index)) index,
    };
    final installValue = _comparison.tryFindInstallValue([
      for (final stage in snapshot.stages) ...stage.journal,
    ]);
    final canRewriteWalk =
        otherStages.isEmpty &&
        !codeStagePaths.values.any(
          (paths) => paths.any((path) => _isStubbedChange(snapshot, path)),
        ) &&
        _canRewriteWalk(snapshot, current, baseline, installValue);
    final journals = {
      for (final index in frameStages)
        index: _readStageJournals(
          snapshot,
          (current: current, baseline: baseline),
          index,
          (installValue: installValue, canRewriteWalk: canRewriteWalk),
        ),
    };
    final shownStages = {
      for (final MapEntry(key: index, value: journal) in journals.entries)
        if (_isJournalShownAlike(journal)) index,
    };
    final journalStages = {
      for (final MapEntry(key: index, value: journal) in journals.entries)
        if (_isJournalRefreshable(journal)) index,
    };

    return (
      shownStages: shownStages,
      journalStages: journalStages,
      journalDifferences: {
        for (final MapEntry(key: index, value: journal) in journals.entries)
          if (!shownStages.contains(index) && !journalStages.contains(index))
            index: _describeJournalDifference(journal),
      },
    );
  }

  AtlasStaleReason _resolveStageReason(
    List<(AtlasStaleReason, Set<int>)> stagesByReason,
  ) {
    final (reason, _) =
        stagesByReason.firstWhereOrNull((entry) => entry.$2.isNotEmpty) ??
        (AtlasStaleReason.fresh, const <int>{});

    return reason;
  }

  List<int> _addJournalStages(
    Set<int> changedStages, {
    required Set<int> shownStages,
  }) {
    return {
      for (final index in changedStages) ...[
        if (index > 0 && !shownStages.contains(index - 1)) index - 1,
        index,
      ],
    }.toList()..sort();
  }

  Set<int> _readStagesReachingName(
    AtlasSnapshot snapshot,
    AtlasStageReach reach,
    String key,
  ) {
    final idSuffix = AtlasStageReach.idOf('', key);

    return {
      ..._readStagesShowing(snapshot, key),
      ..._readStagesReaching(
        snapshot,
        reach,
        (reached) => [
          ...reached.ids,
          ...reached.diIds,
        ].any((id) => id.endsWith(idSuffix)),
      ),
    };
  }

  Set<int> _readStagesReachingMemberName(
    AtlasSnapshot snapshot,
    AtlasStageReach reach, {
    required String ownerName,
    required String name,
  }) {
    final ownerSuffix = AtlasStageReach.idOf('', ownerName);
    final nameSuffixes = [
      AtlasStageReach.idOf('', name),
      '$_memberSeparator$name',
    ];

    return {
      ..._readStagesShowing(snapshot, ownerName),
      ..._readStagesReaching(snapshot, reach, (reached) {
        final ids = [...reached.ids, ...reached.diIds];

        return ids.any((id) => id.endsWith(ownerSuffix)) &&
            ids.any((id) => nameSuffixes.any(id.endsWith));
      }),
    };
  }

  Map<String, String> _describeChangedPaths(AtlasSnapshot snapshot) {
    return {
      for (final MapEntry(key: path, value: hash) in snapshot.manifest.entries)
        if (_isComparedPath(path)) path: ?_tryDescribeChangedPath(path, hash),
    };
  }

  bool _isStageSource(AtlasSnapshot snapshot, String path) {
    return snapshot.stages.any((stage) => stage.sources.containsKey(path));
  }

  bool _isStubbedChange(AtlasSnapshot snapshot, String path) {
    if (!_paths.project.headlessSettings.hasStubs(path)) {
      return false;
    }

    final hash = snapshot.manifest[path];
    final declarations = hash == null
        ? null
        : _tryReadChangedDeclarations(path, hash);

    if (declarations == null || declarations.isEmpty) {
      return true;
    }

    return declarations.any(
      (declaration) => _paths.project.headlessSettings.isStubbedDeclaration(
        path,
        declaration.key,
      ),
    );
  }

  bool _canRewriteWalk(
    AtlasSnapshot snapshot,
    AtlasHeadlessReport current,
    AtlasHeadlessReport? baseline,
    String? installValue,
  ) {
    final journals = [
      for (int index = 0; index < snapshot.stages.length; index++)
        _readStageJournals(
          snapshot,
          (current: current, baseline: baseline),
          index,
          (installValue: installValue, canRewriteWalk: false),
        ),
    ];
    final walked = journals.map((journal) => journal.current).toList();
    final isEveryStageProven = journals.indexed.every(
      (entry) =>
          _hasSameFrame(snapshot, current, baseline, entry.$1) &&
          _isJournalProven(entry.$2),
    );

    return isEveryStageProven &&
        !walked.contains(null) &&
        _comparison.tryRewriteWalk(
              walked: walked.nonNulls.toList(),
              recorded: [for (final journal in journals) journal.recorded],
              installValue: installValue,
            ) !=
            null;
  }

  bool _isJournalRefreshable(_StageJournals journals) {
    if (journals.current == null) {
      return false;
    }

    return !_isJournalShownAlike(journals) &&
        _isCaptureWalkJournal(journals, journals.recorded) &&
        _tryDescribeWalkValue(journals) == null;
  }

  String _describeJournalDifference(_StageJournals journals) {
    final (
      :current,
      :captureWalkHash,
      :baseline,
      :recorded,
      installValue: _,
      canRewriteWalk: _,
    ) = journals;

    if (current == null) {
      return 'no headless journal';
    }

    if (captureWalkHash == null) {
      return 'no headless reference';
    }

    final baselineDifference = baseline == null
        ? null
        : _comparison.tryDescribeDifference(
            recorded: recorded,
            walked: baseline,
          );

    return baselineDifference ??
        _tryDescribeWalkValue(journals) ??
        _comparison.tryDescribeDifference(
          recorded: recorded,
          walked: current,
        ) ??
        'no headless journal';
  }

  Set<int> _readStagesShowing(AtlasSnapshot snapshot, String widgetName) {
    return {
      for (int index = 0; index < snapshot.stages.length; index += 1)
        if (_tryReadStageWidgets(snapshot, index)?.contains(widgetName) ??
            false)
          index,
    };
  }

  Set<int> _readStagesReaching(
    AtlasSnapshot snapshot,
    AtlasStageReach reach,
    bool Function(AtlasReachedDeclarations reached) isReaching,
  ) {
    return {
      for (int index = 0; index < snapshot.stages.length; index += 1)
        if (_tryReadStageWidgets(
              snapshot,
              index,
            )?.any((widget) => isReaching(_readReached(reach, widget))) ??
            false)
          index,
    };
  }

  bool _isComparedPath(String path) {
    final settings = _paths.project.staleSettings;

    return !path.startsWith(settings.targetsDirectory) &&
        !path.startsWith(settings.mockDirectory) &&
        !settings.uncomparedPaths.any(path.startsWith);
  }

  String? _tryDescribeChangedPath(String path, String hash) {
    final (:raw, :normalized) = _readCurrentHashes(path);

    if (raw == null) {
      return '$path$_deletedSuffix';
    }

    return hash == raw || hash == normalized ? null : path;
  }

  List<_ChangedDeclaration>? _tryReadChangedDeclarations(
    String path,
    String hash,
  ) {
    return _changedDeclarations.putIfAbsent((path, hash), () {
      final recordedHashes = _declarationsStore.tryReadHashes(hash);
      final file = File(_paths.resolve(path));

      if (recordedHashes == null) {
        return null;
      }

      final currentHashes = file.existsSync()
          ? {
              for (final declaration
                  in _paths
                      .readDeclarations(file.readAsStringSync())
                      .declarations)
                declaration.key: declaration.hash,
            }
          : const <String, String>{};
      final changedDeclarations = [
        for (final key in {...recordedHashes.keys, ...currentHashes.keys})
          if (recordedHashes[key] != currentHashes[key])
            (key: key, isRemoved: !currentHashes.containsKey(key)),
      ];

      return changedDeclarations;
    });
  }

  _StageJournals _readStageJournals(
    AtlasSnapshot snapshot,
    _HeadlessReports headlessReports,
    int index,
    _WalkRewrite walkRewrite,
  ) {
    final (:current, :baseline) = headlessReports;
    final (:installValue, :canRewriteWalk) = walkRewrite;
    final stage = snapshot.stages[index];
    final hasHeadlessHashes = _headlessHashes.hasStageHeadlessHashes(
      snapshot,
      index,
    );
    final baselineJournal = hasHeadlessHashes
        ? null
        : baseline?.tryReadStageJournal(index);

    return (
      current: current?.tryReadStageJournal(index),
      captureWalkHash: hasHeadlessHashes
          ? stage.headlessJournalHash
          : _tryHashJournal(baselineJournal),
      baseline: baselineJournal,
      recorded: stage.journal,
      installValue: installValue,
      canRewriteWalk: canRewriteWalk,
    );
  }

  bool _hasSameFrame(
    AtlasSnapshot snapshot,
    AtlasHeadlessReport current,
    AtlasHeadlessReport? baseline,
    int index,
  ) {
    if (!_hasSameStageFrame(snapshot, current, baseline, index)) {
      return false;
    }

    return index != _tryFindLastStage(snapshot) ||
        _hasSameEndFrame(snapshot, current, baseline);
  }

  bool _isJournalProven(_StageJournals journals) {
    return _isJournalShownAlike(journals) ||
        (journals.current != null &&
            _isCaptureWalkJournal(journals, journals.recorded));
  }

  String? _tryDescribeWalkValue(_StageJournals journals) {
    final (
      :current,
      captureWalkHash: _,
      baseline: _,
      :recorded,
      :installValue,
      :canRewriteWalk,
    ) = journals;

    if (current == null || canRewriteWalk) {
      return null;
    }

    return _comparison.tryDescribeWalkValue(
      walked: current,
      recorded: recorded,
      installValue: installValue,
    );
  }

  List<String>? _tryReadStageWidgets(AtlasSnapshot snapshot, int index) {
    final widgets = snapshot.stages[index].widgets;

    if (widgets.isEmpty) {
      return null;
    }

    if (index < snapshot.stages.length - 1) {
      return widgets;
    }

    final endWidgets = snapshot.end.widgets;

    return endWidgets.isEmpty ? null : [...widgets, ...endWidgets];
  }

  AtlasReachedDeclarations _readReached(
    AtlasStageReach reach,
    String widgetName,
  ) {
    return _reachedByWidget.putIfAbsent(
      widgetName,
      () => reach.reachFrom(widgetName),
    );
  }

  ({String? raw, String? normalized}) _readCurrentHashes(String path) {
    return _currentHashes.putIfAbsent(
      path,
      () => (
        raw: AtlasContentHash.tryHashFile(_paths.resolve(path)),
        normalized: _headlessHashes.readCurrentSourceHash(path),
      ),
    );
  }

  String? _tryHashJournal(List<Object?>? journal) {
    return journal == null ? null : _comparison.hash(journal);
  }

  bool _hasSameStageFrame(
    AtlasSnapshot snapshot,
    AtlasHeadlessReport current,
    AtlasHeadlessReport? baseline,
    int index,
  ) {
    if (_headlessHashes.hasStageHeadlessHashes(snapshot, index)) {
      return current.frameHashes.elementAtOrNull(index) ==
          snapshot.stages[index].headlessFrameHash;
    }

    return baseline != null && current.hasSameFrame(baseline, index);
  }

  int? _tryFindLastStage(AtlasSnapshot snapshot) {
    return snapshot.stages.isEmpty ? null : snapshot.stages.length - 1;
  }

  bool _hasSameEndFrame(
    AtlasSnapshot snapshot,
    AtlasHeadlessReport current,
    AtlasHeadlessReport? baseline,
  ) {
    if (_headlessHashes.hasEndHeadlessHash(snapshot)) {
      return current.endFrameHash == snapshot.end.headlessFrameHash;
    }

    return baseline != null && current.hasSameEndFrame(baseline);
  }

  bool _isJournalShownAlike(_StageJournals journals) {
    final current = journals.current;

    if (current == null) {
      return false;
    }

    return _comparison.isSame(current, journals.recorded) ||
        _isCaptureWalkJournal(journals, current);
  }

  bool _isCaptureWalkJournal(_StageJournals journals, List<Object?> journal) {
    final captureWalkHash = journals.captureWalkHash;

    return captureWalkHash != null &&
        _comparison.hash(journal) == captureWalkHash;
  }
}

/// {@category Utils}
///
/// Tells the staleness of each of [variants], in their order.
typedef AtlasStalenessReader =
    Future<List<AtlasStaleness>> Function(
      List<AtlasVariantDefinition> variants,
    );

/// {@category Utils}
///
/// Whether one variant's snapshot still describes it, and why not.
final class AtlasStaleness {
  static const _everyStageLabel = 'every stage by';

  /// The variant checked.
  final AtlasVariantDefinition variant;

  /// Why the snapshot no longer describes the variant, or that it does.
  final AtlasStaleReason reason;

  /// The compared manifest paths that changed, marked when deleted, other
  /// than [unattributedPaths]; empty unless the reason is
  /// [AtlasStaleReason.code] or a stage reason.
  final List<String> changedPaths;

  /// The changed manifest paths outside the sources of every stage that no
  /// widget of a stage places, marked when deleted; each stales every stage.
  final List<String> unattributedPaths;

  /// The localization keys a stage showed whose value changed, marked when
  /// deleted.
  final List<String> changedTranslationKeys;

  /// The indexes of the stages a capture walks again, in order; empty when
  /// the variant is fresh or stale as a whole.
  final List<int> stages;

  /// The stages the widgets of the stages placed each changed manifest file
  /// on, by path; a capture of [stages] takes the new hash of such a file.
  final Map<String, Set<int>> attributedPaths;

  /// The stages whose frame the headless reports show alike while their
  /// journal differs, and whose own journal the baseline report holds, in
  /// order; the journal refresh writes the current journal into them without
  /// a device.
  final List<int> journalStages;

  /// How the baseline journal differs from its own for each stale stage
  /// whose frame the headless reports show alike, by stage.
  final Map<int, String> journalDifferences;

  /// The first request the current mock answers differently and how, when a
  /// stage is stale for it.
  final String? mockDifference;

  const AtlasStaleness({
    required this.variant,
    required this.reason,
    required this.changedPaths,
    required this.changedTranslationKeys,
    required this.stages,
    required this.attributedPaths,
    this.unattributedPaths = const [],
    this.mockDifference,
    this.journalStages = const [],
    this.journalDifferences = const {},
  });

  /// The staleness of [variant] as a whole, for a [reason] naming no path.
  const AtlasStaleness.variant(this.variant, this.reason)
    : changedPaths = const [],
      unattributedPaths = const [],
      changedTranslationKeys = const [],
      stages = const [],
      attributedPaths = const {},
      mockDifference = null,
      journalStages = const [],
      journalDifferences = const {};

  /// Whether the variant needs a new capture.
  bool get isStale => reason != AtlasStaleReason.fresh;

  /// The indexes of the stages of the variant [stages] does not name, fresh
  /// on the current tree, in order; empty when [stages] is.
  List<int> get freshStages {
    if (stages.isEmpty) {
      return const [];
    }

    return [
      for (int index = 0; index < variant.stageStepHashes.length; index += 1)
        if (!stages.contains(index)) index,
    ];
  }

  /// The same staleness without [journalStages], once their journal was
  /// written; absent when no other stage is stale.
  AtlasStaleness? tryWithoutJournalStages() {
    final otherStages = stages
        .where((index) => !journalStages.contains(index))
        .toList();

    if (journalStages.isNotEmpty && otherStages.isEmpty) {
      return null;
    }

    return AtlasStaleness(
      variant: variant,
      reason: reason,
      changedPaths: changedPaths,
      unattributedPaths: unattributedPaths,
      changedTranslationKeys: changedTranslationKeys,
      stages: otherStages,
      attributedPaths: attributedPaths,
      mockDifference: mockDifference,
      journalDifferences: journalDifferences,
    );
  }

  /// The variant's line of the `stale` command.
  String describe() {
    return [
      variant.id,
      reason.label,
      if (stages.isNotEmpty) stages.join(','),
      if (unattributedPaths.isNotEmpty)
        '[$_everyStageLabel ${unattributedPaths.join(', ')}]',
      if (changedPaths.isNotEmpty) changedPaths.join(', '),
      if (changedTranslationKeys.isNotEmpty)
        '${AtlasStaleReason.locale.label} ${changedTranslationKeys.join(', ')}',
      if (mockDifference case final difference?) 'mock $difference',
      for (final MapEntry(key: index, value: difference)
          in journalDifferences.entries)
        'journal $index: $difference',
    ].join(' ');
  }
}

/// {@category Utils}
///
/// Why a snapshot no longer describes its variant.
enum AtlasStaleReason {
  /// The snapshot describes the variant.
  fresh('fresh'),

  /// The variant was never captured.
  noSnapshot('new'),

  /// The steps or the mock of the variant changed since the capture.
  definition('definition'),

  /// The captured walk did not pass.
  failed('failed'),

  /// The capture stored no manifest of the source files it executed.
  noManifest('manifest'),

  /// The snapshot records no stages, and an app source file the capture
  /// executed changed or is gone.
  code('code'),

  /// The steps up to the end of a stage changed since the capture.
  stageDefinition('stage definition'),

  /// A source file of a stage changed or is gone, a declaration a widget
  /// visible on the stage reaches changed, or a file no widget of a stage
  /// places changed or is gone.
  stageCode('stage code'),

  /// The current mock answers a request the stage recorded differently.
  stageMock('stage mock'),

  /// The headless walks show the stage's frame alike on the current code and
  /// on the code it was captured on, and only its journal differs, which the
  /// baseline walk writes as the capture did.
  stageJournal('stage journal'),

  /// An analytics event a stage logged is missing from the analytics
  /// catalogue, or its catalogue parameters do not fit the logged keys.
  stageAnalytics('stage analytics'),

  /// The value of a localization key a stage showed changed or is gone.
  locale('locale');

  /// The word the `stale` command prints.
  final String label;

  const AtlasStaleReason(this.label);
}
