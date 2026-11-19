import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';

import 'package:flutter_automation_atlas/src/atlas_capture.dart';
import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_record.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_selection.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_refresh.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_page_part.dart';
import 'package:flutter_automation_atlas/src/atlas_manifest_normalization.dart';
import 'package:flutter_automation_atlas/src/atlas_page_renderer.dart';
import 'package:flutter_automation_atlas/src/atlas_project.dart';
import 'package:flutter_automation_atlas/src/atlas_published_variants.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_encoder.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_source.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_check.dart';

/// {@category Utils}
///
/// Keeps the atlas of a project — a snapshot of every automation flow
/// variant, one screenshot, journal and design link per stage — in step with
/// the app.
///
/// A project calls it from its own file:
///
/// ```dart
/// Future<void> main(List<String> args) {
///   return runAtlas(args, MyAtlasProject());
/// }
/// ```
///
/// - `capture <flow> [<variant>...]` walks the named variants in the order
///   given, or every variant of the flow when none is named, on the one booted
///   iOS simulator and writes their snapshots and shots. Every name is
///   resolved before the app is launched, so a misspelt one fails first. A
///   full walk of a variant whose flow is in the QA catalogue, in the default
///   locale, also writes its recording.
/// - `capture <flow> <variant> --stages <i,…>` walks the one variant up to
///   the last of the stage indexes, shoots only them — the last stage shoots
///   the end too — and keeps every other stage with its hashes, the way
///   `capture --stale` captures stale stages without rebasing any; a variant
///   with no snapshot is walked whole.
/// - `capture --stale` captures exactly what `stale` names: every
///   `stage journal` stage first takes the journal of the current headless
///   report without a device, a variant stale as a whole or in every other
///   stage is walked whole, a variant with other stale stages is walked up to
///   the last of them, shoots only them and keeps every other stage, each
///   stage `stale` found fresh taking the hashes of the current files.
/// - `stale [<flow>]` prints one line per variant: `fresh`, `new`,
///   `definition`, `failed`, `manifest` or `code` with the changed paths for
///   the variant as a whole, or `stage definition`, `stage code`,
///   `stage mock`, `stage journal`, `stage analytics` and `locale` with the
///   stale stage indexes, the changed paths, the changed keys, the request the
///   mock answers differently and the journal the baseline walk does not
///   reproduce. With `--published`, before it prints, it walks headless in
///   one run the variants whose frames it did not compare
///   ([AtlasHeadlessSelection]) and checks them again;
///   `capture --stale --published` does the same, and `--no-walk` keeps both
///   to the reports already written.
/// - `headless [--baseline] [<flow> [<variant>...]]` walks the published
///   variants, the variants of the flow or the named ones in the app under
///   `flutter test`, on the in-app mock and without a device, and writes the
///   hash and the PNG of the frame and the journal of every stage and of the
///   end to the headless folder under the build folder of the project; with
///   `--baseline` it walks each variant on the commit its snapshot was
///   written in and writes to the baseline folder. `stale` compares the
///   current report with the hashes a snapshot holds, or with the baseline
///   one.
/// - `headless --record [<flow> [<variant>...]]` walks the same variants,
///   checks them as `stale --no-walk` does and writes the frame and journal
///   hashes of the current reports into the snapshots of the fresh ones
///   ([AtlasHeadlessRecord]), naming every variant it leaves.
/// - `normalize-manifests` rewrites the manifest hashes every stored snapshot
///   took of the raw content of a file into the hashes `stale` compares, and
///   prints the hashes no version of the file in git history matches.
/// - `source-commit --snapshot <file>` prints the commit `stale` takes as the
///   baseline of the snapshot file, or `not found`.
/// - `stale --published` and `capture --stale --published` keep to the
///   variants the published variants list of the project names.
/// - `render [--edition <name>]` writes the page of the edition, `full` when
///   absent, to `index.html` in the store folder, its shots read from
///   `shots/<hash>.png` beside it, deletes the shots and the declarations no
///   stored snapshot names and writes the reports of the project
///   ([AtlasProject.writeReports]).
/// - `bundle --edition <name> --shots <source> [--locale <code|all>]` writes
///   the page of the edition as `index.html` in its own folder under the
///   build folder, one folder per edition and locale. The source is `files`,
///   `inline`, `sheets` or `urls`. `files` copies the shots to `shots/`
///   beside the page. `inline` embeds them as WebP sheets. `sheets` writes
///   the WebP sheets as `shots/<hash>.webp` beside the page and deletes all
///   other files in that folder. `urls` takes their links from
///   [AtlasProject.shotPublisher]. `--locale` names the one series the page
///   shows; `all`, or none, shows every page locale in one file. The bundle
///   stops with its size when it passes the `maxBundleBytes` or the
///   `maxBundleImages` limit of `flutter_automation: atlas:`.
///   `maxBundleImages` counts the inline sheets or the sheet files. The
///   bundle also stops with the message of a publisher that fails.
///
/// `capture` and `stale` take `--locale <code>`, the first locale of the
/// project when absent: the app runs in that locale and its values come from
/// the translations of the project. Every command takes `--store <folder>`,
/// the folder of the snapshots, the declarations, the shots and the page, the
/// output folder of the project when absent, and `--source-label <text>`, the
/// label of the source the page shows.
///
/// `headless` with `--published` or `--no-walk`, and `capture` with
/// `--no-walk` but without `--stale`, fail with the usage.
///
/// A capture or a headless walk that did not pass exits with code 1.
Future<void> runAtlas(List<String> args, AtlasProject project) async {
  try {
    await AtlasRun(args, project).run();
  } on AtlasException catch (error) {
    stderr.writeln(error.message);
    exit(AtlasException.errorExitCode);
  } on AutomationRunnerException catch (error) {
    stderr.writeln(error.message);
    exit(AutomationRunnerException.errorExitCode);
  }
}

/// {@category Utils}
///
/// Dispatches one command of the atlas.
final class AtlasRun {
  static const _captureCommand = 'capture';
  static const _staleCommand = 'stale';
  static const _headlessCommand = 'headless';
  static const _normalizeManifestsCommand = 'normalize-manifests';
  static const _sourceCommitCommand = 'source-commit';
  static const _renderCommand = 'render';
  static const _bundleCommand = 'bundle';
  static const _staleFlag = '--stale';
  static const _baselineFlag = '--baseline';
  static const _recordFlag = '--record';
  static const _noWalkFlag = '--no-walk';
  static const _publishedFlag = '--published';
  static const _localeOption = '--locale';
  static const _stagesOption = '--stages';
  static const _storeOption = '--store';
  static const _sourceLabelOption = '--source-label';
  static const _snapshotOption = '--snapshot';
  static const _editionOption = '--edition';
  static const _shotsOption = '--shots';
  static const _allLocales = 'all';
  static const _optionArgumentCount = 2;
  static const _failureExitCode = 1;
  static const _firstVariantArgumentIndex = 2;
  static const _noSourceCommit = 'not found';
  static const _usage =
      'usage: atlas '
      '$_captureCommand <flow> [<variant>...] [$_localeOption <code>] | '
      '$_captureCommand <flow> <variant> $_stagesOption <i,...> '
      '[$_localeOption <code>] | '
      '$_captureCommand $_staleFlag [$_publishedFlag] [$_noWalkFlag] '
      '[$_localeOption <code>] | '
      '$_staleCommand [$_publishedFlag] [$_noWalkFlag] '
      '[$_localeOption <code>] [<flow>] | '
      '$_headlessCommand [$_baselineFlag | $_recordFlag] '
      '[<flow> [<variant>...]] | '
      '$_normalizeManifestsCommand | '
      '$_sourceCommitCommand $_snapshotOption <file> | '
      '$_renderCommand [$_editionOption <name>] | '
      '$_bundleCommand $_editionOption <name> '
      '$_shotsOption <files|inline|sheets|urls> '
      '[$_localeOption <code|$_allLocales>] '
      '[$_storeOption <folder>] [$_sourceLabelOption <text>]';

  /// The arguments of the command.
  final List<String> args;

  /// The places the commands read and write.
  final AtlasLocations locations;

  final AtlasProject _project;
  final AtlasStalenessReader? _readStalenesses;
  final AtlasHeadlessPass? _headlessPass;
  final AtlasShotEncoder? _shotEncoder;

  /// The [rootPath] parameter names the repository the commands read and
  /// write; the [readStalenesses] parameter tells the staleness of each of
  /// the variants in their order, [AtlasStaleCheck] when absent; the
  /// [headlessPass] parameter walks variants headless, on the working tree
  /// when absent; the [shotEncoder] parameter turns shots into the sheets a
  /// bundle inlines or writes as files, WebP sheets when absent.
  AtlasRun(
    this.args,
    this._project, {
    String rootPath = '.',
    AtlasStalenessReader? readStalenesses,
    AtlasHeadlessPass? headlessPass,
    AtlasShotEncoder? shotEncoder,
  }) : locations = AtlasLocations(
         rootPath,
         _project,
         store: _tryReadOption(args, _storeOption),
       ),
       _readStalenesses = readStalenesses,
       _headlessPass = headlessPass,
       _shotEncoder = shotEncoder;

  /// The label of the source the page shows, absent when none is given.
  String? get sourceLabel => _tryReadOption(args, _sourceLabelOption);

  String get _locale {
    return _tryReadOption(args, _localeOption) ?? locations.defaultLocale;
  }

  List<int>? get _stages {
    final stages = _tryReadOption(
      args,
      _stagesOption,
    )?.split(',').map(int.tryParse).toList();

    if (stages == null) {
      return null;
    }

    if (stages.any((stage) => stage == null || stage < 0)) {
      throw const AtlasException(_usage);
    }

    return stages.nonNulls.toList();
  }

  bool get _isPublishedOnly => args.contains(_publishedFlag);

  bool get _isWalked => _isPublishedOnly && !args.contains(_noWalkFlag);

  List<String> get _positionalArguments {
    final optionIndexes =
        [
              _localeOption,
              _stagesOption,
              _storeOption,
              _sourceLabelOption,
              _snapshotOption,
              _editionOption,
              _shotsOption,
            ]
            .map(args.indexOf)
            .where((index) => index >= 0)
            .expand(
              (index) => List.generate(
                _optionArgumentCount,
                (offset) => index + offset,
              ),
            )
            .toSet();

    return [
      for (final (index, arg) in args.indexed)
        if (!optionIndexes.contains(index) && !_isFlag(arg)) arg,
    ];
  }

  Future<void> run() async {
    switch (_positionalArguments.firstOrNull) {
      case _captureCommand:
        await _capture(_locale);
      case _staleCommand:
        await _printStale(_locale);
      case _headlessCommand:
        await _walkHeadless();
      case _normalizeManifestsCommand:
        _normalizeManifests();
      case _sourceCommitCommand:
        _printSourceCommit();
      case _renderCommand:
        await _render();
      case _bundleCommand:
        await _bundle();
      case _:
        throw const AtlasException(_usage);
    }
  }

  /// Writes the reports of the project that read the atlas, from the store
  /// folder the command names.
  void writeReports() {
    _project.writeReports(locations.storePath);
  }

  static String? _tryReadOption(List<String> args, String option) {
    final index = args.indexOf(option);

    if (index < 0) {
      return null;
    }

    final value = args.elementAtOrNull(index + 1);

    if (value == null || value.startsWith('-')) {
      throw const AtlasException(_usage);
    }

    return value;
  }

  bool _isFlag(String arg) {
    return const {
      _publishedFlag,
      _baselineFlag,
      _recordFlag,
      _noWalkFlag,
    }.contains(arg);
  }

  Future<void> _capture(String locale) async {
    final stages = _stages;
    final isOk = switch (_positionalArguments.elementAtOrNull(1)) {
      _staleFlag when stages == null => await _captureStale(locale),
      _staleFlag => throw const AtlasException(_usage),
      _ when args.contains(_noWalkFlag) => throw const AtlasException(_usage),
      _ when stages != null => await _captureStages(locale, stages),
      _ => await AtlasCapture(
        locations,
        locale,
        headlessPass: _headlessPass,
      ).run(_resolveCaptureVariants()),
    };

    if (!isOk) {
      exitCode = _failureExitCode;
    }
  }

  Future<void> _printStale(String locale) async {
    final flowName = _positionalArguments.elementAtOrNull(1);
    final definitions = AtlasDefinitions.read(locations);
    final variants = flowName == null
        ? definitions.variants
        : definitions.findFlow(flowName).variants;

    for (final staleness in await _checkStale(
      locale,
      _readCheckedVariants(variants),
    )) {
      stdout.writeln(staleness.describe());
    }
  }

  Future<void> _walkHeadless() async {
    if (_isPublishedOnly || args.contains(_noWalkFlag)) {
      throw const AtlasException(_usage);
    }

    final definitions = AtlasDefinitions.read(locations);
    final variants = _positionalArguments.length > 1
        ? _resolveCaptureVariants()
        : AtlasPublishedVariants.read(
            locations,
            definitions,
          ).filter(definitions.variants);

    if (!await _runHeadless(variants)) {
      exitCode = _failureExitCode;
    }
  }

  void _normalizeManifests() {
    final result = AtlasManifestNormalization(locations).run();

    stdout.writeln('Rewrote ${result.rewrittenSnapshots} snapshots');

    for (final hash in result.unresolvedHashes) {
      stderr.writeln('No version of the file matches $hash');
    }
  }

  Future<void> _render() async {
    final edition = locations.pageConfig.resolveEdition(
      _tryReadOption(args, _editionOption) ?? AtlasEdition.fullName,
    );

    final rendering = await _createRenderer().render(edition: edition);

    writeReports();

    stdout
      ..writeln('Wrote ${locations.pagePath}: ${rendering.totals}')
      ..writeln('Deleted ${rendering.deletedShots.length} unreferenced shots')
      ..writeln(
        'Deleted ${rendering.deletedDeclarations.length} unreferenced '
        'declarations records',
      );

    for (final snapshot in rendering.unlistedSnapshots) {
      stderr.writeln('No flow file lists the snapshot of $snapshot');
    }

    for (final shot in rendering.missingShots) {
      stderr.writeln('No shot file at ${locations.resolveShotPath(shot)}');
    }
  }

  Future<void> _bundle() async {
    final editionName = _tryReadOption(args, _editionOption);
    final source = AtlasShotSource.tryRead(
      _tryReadOption(args, _shotsOption) ?? '',
    );

    if (editionName == null || source == null) {
      throw const AtlasException(_usage);
    }

    final config = locations.pageConfig;
    final maxBytes = config.maxBundleBytes;
    final maxImages = config.maxBundleImages;
    final localeName = _tryReadOption(args, _localeOption);

    final rendering = await _createRenderer().renderBundle(
      edition: config.resolveEdition(editionName),
      source: source,
      locale: localeName == _allLocales ? null : localeName,
    );

    stdout.writeln(
      'Wrote ${rendering.path}: ${rendering.bytes} bytes, '
      '${rendering.images} images',
    );

    final overLimit = rendering.tryDescribeOverLimit(
      maxBytes: maxBytes,
      maxImages: maxImages,
    );

    if (overLimit != null) {
      throw AtlasException(overLimit);
    }
  }

  AtlasPageRenderer _createRenderer() {
    return AtlasPageRenderer(
      locations,
      shotEncoder: _shotEncoder,
      sourceLabel: sourceLabel,
    );
  }

  void _printSourceCommit() {
    final snapshotPath = _tryReadOption(args, _snapshotOption);

    if (snapshotPath == null) {
      throw const AtlasException(_usage);
    }

    final commit = AtlasHeadless.tryReadSnapshotCommit(locations, snapshotPath);

    stdout.writeln(commit ?? _noSourceCommit);
  }

  Future<bool> _captureStale(String locale) async {
    final stalenesses = await _checkStale(
      locale,
      _readCheckedVariants(AtlasDefinitions.read(locations).variants),
    );

    final staleVariants = AtlasJournalRefresh(
      locations,
      locale,
    ).run(stalenesses.where((staleness) => staleness.isStale).toList());

    return AtlasCapture(locations, locale, headlessPass: _headlessPass).run(
      staleVariants.map((staleness) => staleness.variant).toList(),
      stageSelections: {
        for (final staleness in staleVariants)
          staleness.variant.id: (
            stages: staleness.stages,
            attributedPaths: staleness.attributedPaths,
            freshStages: staleness.freshStages,
          ),
      },
    );
  }

  Future<bool> _captureStages(String locale, List<int> stages) {
    if (_positionalArguments.length != _firstVariantArgumentIndex + 1) {
      throw const AtlasException(_usage);
    }

    final variant = _resolveCaptureVariants().single;

    return AtlasCapture(locations, locale, headlessPass: _headlessPass).run(
      [variant],
      stageSelections: {
        variant.id: (
          stages: stages,
          attributedPaths: const {},
          freshStages: const [],
        ),
      },
    );
  }

  Future<bool> _runHeadless(List<AtlasVariantDefinition> variants) {
    final isBaseline = args.contains(_baselineFlag);
    final isRecord = args.contains(_recordFlag);

    if (isBaseline && isRecord) {
      throw const AtlasException(_usage);
    }

    if (isBaseline) {
      return AtlasHeadless.baseline(locations).run(variants);
    }

    if (isRecord) {
      return _recordHeadless(variants);
    }

    return _resolveHeadlessPass()(variants);
  }

  Future<List<AtlasStaleness>> _checkStale(
    String locale,
    List<AtlasVariantDefinition> variants,
  ) async {
    final readStalenesses = _resolveStalenessReader(locale);

    final stalenesses = await readStalenesses(variants);

    final walkedVariants = _isWalked
        ? AtlasHeadlessSelection(locations, locale).select(stalenesses)
        : const <AtlasVariantDefinition>[];

    if (walkedVariants.isEmpty) {
      return stalenesses;
    }

    await _resolveHeadlessPass()(walkedVariants);

    final rechecked = await readStalenesses(walkedVariants);

    return [
      for (final staleness in stalenesses)
        _findStaleness(rechecked, staleness.variant.id) ?? staleness,
    ];
  }

  List<AtlasVariantDefinition> _readCheckedVariants(
    List<AtlasVariantDefinition> variants,
  ) {
    if (!_isPublishedOnly) {
      return variants;
    }

    return AtlasPublishedVariants.read(
      locations,
      AtlasDefinitions.read(locations),
    ).filter(variants);
  }

  List<AtlasVariantDefinition> _resolveCaptureVariants() {
    final flowName = _positionalArguments.elementAtOrNull(1);
    final definitions = AtlasDefinitions.read(locations);

    if (flowName == null) {
      throw const AtlasException(_usage);
    }

    final flow = definitions.findFlow(flowName);
    final variantNames = _positionalArguments.skip(_firstVariantArgumentIndex);

    if (variantNames.isEmpty) {
      return flow.variants;
    }

    return variantNames.toSet().map(flow.findVariant).toList();
  }

  Future<bool> _recordHeadless(List<AtlasVariantDefinition> variants) async {
    final isPassed = await _resolveHeadlessPass()(variants);
    final stalenesses = await _resolveStalenessReader(locations.defaultLocale)(
      variants,
    );

    AtlasHeadlessRecord(locations).run(stalenesses);

    return isPassed;
  }

  AtlasStaleness? _findStaleness(
    List<AtlasStaleness> stalenesses,
    String variantId,
  ) {
    return stalenesses.firstWhereOrNull(
      (staleness) => staleness.variant.id == variantId,
    );
  }

  AtlasHeadlessPass _resolveHeadlessPass() {
    return _headlessPass ?? AtlasHeadless(locations).run;
  }

  AtlasStalenessReader _resolveStalenessReader(String locale) {
    return _readStalenesses ?? AtlasStaleCheck(locations, locale).check;
  }
}
