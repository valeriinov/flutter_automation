import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_automation/locale_key_marker.dart';

import 'package:flutter_automation_atlas/src/atlas_declarations_store.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_cleaner.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_stage_sources.dart';
import 'package:flutter_automation_atlas/src/atlas_translations.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';

typedef _StageSteps = ({
  int? previousActionIndex,
  int start,
  int? nextActionIndex,
});

/// {@category Utils}
///
/// Turns the report of one runner capture in one locale into the snapshot of
/// its variant in that locale.
///
/// A stage opens on every user action and holds the steps up to the next one:
/// the screenshot and the screen logged before the action, and the journal
/// the action and the steps after it produced. The runner writes a
/// `screenshot` key, `null` when the shot failed, on every user action and on
/// nothing else, so that key is what opens a stage. Steps before the first
/// action only bring the app to where the walk starts, so they open no stage
/// and their journal is dropped.
///
/// Records that arrive after the last step of a stage are read just before
/// the next action as its `journalBeforeAction`, or after the run as
/// `endJournal`, and close the journal of the stage they arrived in. The
/// texts and the widget types the last frame showed arrive after the run as
/// `endTexts` and `endWidgets`; those of the frame before an action, on the
/// action step as `texts` and `widgets`.
///
/// The runner also reads the texts after every step as `textsAfterStep`, so a
/// toast an action raises and that is gone by the next frame read still
/// counts: the texts read after the steps of a stage that neither its own
/// frame nor the next one showed join the texts of the next stage, or of the
/// end after the last stage.
///
/// The report's `launch` record — what the launch was installed with — opens
/// the journal of the first stage without its moments, and every stage holds
/// its `anchor` and `launchedAt`. The mock files are left out of the manifest:
/// what the mock answered is in the journal, which `stale` replays. Every
/// manifest file content gets its declarations record through
/// [AtlasDeclarationsStore].
final class AtlasSnapshotBuilder {
  static const _actionKey = 'action';
  static const _screenKey = 'screen';
  static const _screenshotKey = 'screenshot';
  static const _textsKey = 'texts';
  static const _textsAfterStepKey = 'textsAfterStep';
  static const _widgetsKey = 'widgets';
  static const _launchKey = 'launch';
  static const _anchorKey = 'anchor';
  static const _launchedAtKey = 'launchedAt';

  final AtlasLocations _paths;
  final String _locale;

  const AtlasSnapshotBuilder(this._paths, this._locale);

  /// Builds the snapshot of a capture [report].
  ///
  /// The [report] parameter is the decoded runner report, the [device]
  /// parameter names the simulator it walked and the [defHash] parameter is the
  /// hash of the variant definition it walked, the [stepHashes] parameter
  /// holds the hash of the steps up to the end of each stage. The shots of the
  /// result still name the screenshot files of the capture directory rather
  /// than content hashes.
  AtlasSnapshot build({
    required Map<String, Object?> report,
    required String device,
    required String defHash,
    required List<String> stepHashes,
  }) {
    final steps = AtlasJson.readObjects(report, 'steps');
    final manifest = hashManifest(
      AtlasJson.readList(report, 'manifest').whereType<String>(),
    );
    final endScreen = _readScreen(
      steps.lastWhereOrNull((step) => step.containsKey(_screenKey)),
    );
    final translations = AtlasTranslations.read(_paths, _locale);
    final endMarkedTexts = _readEndMarkedTexts(report, steps);

    return AtlasSnapshot(
      flow: AtlasJson.readString(report, 'flow'),
      variant: AtlasJson.readString(report, 'variant'),
      locale: _locale,
      ok: report['ok'] == true,
      device: device,
      defHash: defHash,
      manifest: manifest,
      stages: _buildStages(
        report,
        stepHashes: stepHashes,
        manifest: manifest,
        translations: translations,
      ),
      end: AtlasEnd(
        screen: AtlasJson.tryReadString(endScreen, 'screenName'),
        designScreen: AtlasJson.tryReadString(
          endScreen,
          _paths.project.designScreenKey,
        ),
        shot: AtlasJson.tryReadString(report, 'endScreenshot'),
        texts: endMarkedTexts.map(LocaleKeyMarker.strip).toList(),
        localeKeys: translations.hashKeys(
          endMarkedTexts.expand(LocaleKeyMarker.readKeys),
        ),
        widgets: _readWidgets(report, 'endWidgets'),
      ),
    );
  }

  /// The source hash of every file of [paths] that exists outside the mock,
  /// by path, each with its declarations record written.
  Map<String, String> hashManifest(Iterable<String> paths) {
    final declarationsStore = AtlasDeclarationsStore(_paths);

    return {
      for (final path in paths)
        if (!path.startsWith(_paths.project.staleSettings.mockDirectory))
          path: ?_tryHashManifestFile(path, declarationsStore),
    };
  }

  List<String> _readEndMarkedTexts(
    Map<String, Object?> report,
    List<Map<String, Object?>> steps,
  ) {
    final endTexts = _readMarkedTexts(report, 'endTexts');
    final lastActionIndex = _readActionIndexes(steps).lastOrNull;

    if (lastActionIndex == null) {
      return endTexts;
    }

    return _mergeMarkedTexts(
      endTexts,
      laterTexts: _readTextsAfterSteps(steps.sublist(lastActionIndex)),
      earlierTexts: _readMarkedTexts(steps[lastActionIndex], _textsKey),
    );
  }

  List<AtlasStage> _buildStages(
    Map<String, Object?> report, {
    required List<String> stepHashes,
    required Map<String, String> manifest,
    required AtlasTranslations translations,
  }) {
    final steps = AtlasJson.readObjects(report, 'steps');
    final endJournal = AtlasJson.readList(report, 'endJournal');
    final stageSources = AtlasStageSources(_paths, _paths.packagePrefix);
    final actionIndexes = _readActionIndexes(steps);
    final stagesSteps = [
      for (final (position, start) in actionIndexes.indexed)
        (
          previousActionIndex: position == 0
              ? null
              : actionIndexes[position - 1],
          start: start,
          nextActionIndex: actionIndexes.elementAtOrNull(position + 1),
        ),
    ];
    final stagesMarkedTexts = [
      for (final stageSteps in stagesSteps)
        _readStageMarkedTexts(steps, stageSteps),
    ];
    final stages = [
      for (final (position, stageSteps) in stagesSteps.indexed)
        _buildStage(
          steps,
          stageSteps: stageSteps,
          markedTexts: stagesMarkedTexts[position],
          endJournal: endJournal,
        ),
    ];
    final launch = AtlasJson.tryReadObject(report, _launchKey);

    return [
      for (final (position, stage) in stages.indexed)
        stage
            .copyWithHashes(
              stepHash: stepHashes.elementAtOrNull(position),
              sources: _hashSources(stageSources, stage.screen, manifest),
              localeKeys: translations.hashKeys(
                stagesMarkedTexts[position].expand(LocaleKeyMarker.readKeys),
              ),
            )
            .copyWithLaunch(
              anchor: _tryReadMoment(launch, _anchorKey),
              launchedAt: _tryReadMoment(launch, _launchedAtKey),
            )
            .copyWithJournal([
              if (position == 0)
                ?AtlasJournalCleaner(
                  _paths.project.journalSchema,
                ).tryDescribeLaunch(launch),
              ...stage.journal,
            ]),
    ];
  }

  String? _tryHashManifestFile(
    String path,
    AtlasDeclarationsStore declarationsStore,
  ) {
    final file = File(_paths.resolve(path));

    if (!file.existsSync()) {
      return null;
    }

    final source = file.readAsStringSync();
    final sourceHash = _paths.sourceHash.hashSource(source);

    declarationsStore.maybeWrite(sourceHash: sourceHash, source: source);

    return sourceHash;
  }

  List<int> _readActionIndexes(List<Map<String, Object?>> steps) {
    return [
      for (final (index, step) in steps.indexed)
        if (step.containsKey(_screenshotKey)) index,
    ];
  }

  List<String> _readStageMarkedTexts(
    List<Map<String, Object?>> steps,
    _StageSteps stageSteps,
  ) {
    final (:previousActionIndex, :start, nextActionIndex: _) = stageSteps;
    final ownTexts = _readMarkedTexts(steps[start], _textsKey);

    if (previousActionIndex == null) {
      return ownTexts;
    }

    return _mergeMarkedTexts(
      ownTexts,
      laterTexts: _readTextsAfterSteps(
        steps.sublist(previousActionIndex, start),
      ),
      earlierTexts: _readMarkedTexts(steps[previousActionIndex], _textsKey),
    );
  }

  AtlasStage _buildStage(
    List<Map<String, Object?>> steps, {
    required _StageSteps stageSteps,
    required List<String> markedTexts,
    required List<Object?> endJournal,
  }) {
    final (previousActionIndex: _, :start, :nextActionIndex) = stageSteps;
    final action = steps[start];
    final ownSteps = steps.sublist(start, nextActionIndex ?? steps.length);
    final screen = _readScreen(start == 0 ? null : steps[start - 1]);
    final lateJournal = nextActionIndex == null
        ? endJournal
        : AtlasJson.readList(steps[nextActionIndex], 'journalBeforeAction');

    return AtlasStage(
      label: AtlasJson.readString(action, 'label'),
      action: AtlasJson.readString(action, _actionKey),
      journal: AtlasJournalCleaner(_paths.project.journalSchema).clean([
        ...ownSteps.expand((step) => AtlasJson.readList(step, 'journal')),
        ...lateJournal,
      ]),
      ok: ownSteps.every((step) => step['ok'] == true),
      target: AtlasJson.tryReadObject(action, 'target'),
      block: AtlasJson.tryReadString(action, 'block'),
      targetRect: AtlasJson.tryReadObject(action, 'targetRect'),
      screen: AtlasJson.tryReadString(screen, 'screenName'),
      designScreen: AtlasJson.tryReadString(
        screen,
        _paths.project.designScreenKey,
      ),
      shot: AtlasJson.tryReadString(action, _screenshotKey),
      error: ownSteps
          .map((step) => AtlasJson.tryReadString(step, 'error'))
          .nonNulls
          .firstOrNull,
      texts: markedTexts.map(LocaleKeyMarker.strip).toList(),
      widgets: _readWidgets(action, _widgetsKey),
    );
  }

  Map<String, String> _hashSources(
    AtlasStageSources stageSources,
    String? screen,
    Map<String, String> manifest,
  ) {
    if (screen == null || manifest.isEmpty) {
      return const {};
    }

    final paths = stageSources.resolve(
      screen: screen,
      manifestPaths: manifest.keys,
    );

    return {for (final path in paths) path: ?manifest[path]};
  }

  String? _tryReadMoment(Map<String, Object?>? launch, String key) {
    return launch == null ? null : AtlasJson.tryReadString(launch, key);
  }

  List<String> _mergeMarkedTexts(
    List<String> ownTexts, {
    required Iterable<String> laterTexts,
    required List<String> earlierTexts,
  }) {
    return [
      ...ownTexts,
      ...laterTexts
          .where((text) => !ownTexts.contains(text))
          .where((text) => !earlierTexts.contains(text))
          .toSet(),
    ];
  }

  Iterable<String> _readTextsAfterSteps(List<Map<String, Object?>> steps) {
    return steps.expand((step) => _readMarkedTexts(step, _textsAfterStepKey));
  }

  Map<String, Object?> _readScreen(Map<String, Object?>? step) {
    final screen = step?[_screenKey];

    return screen is Map<String, Object?> ? screen : const {};
  }

  List<String> _readWidgets(Map<String, Object?> json, String key) {
    return AtlasJson.readList(json, key).whereType<String>().toList();
  }

  List<String> _readMarkedTexts(Map<String, Object?> json, String key) {
    return AtlasJson.readList(json, key).whereType<String>().toList();
  }
}
