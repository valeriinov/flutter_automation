import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_capture.dart';
import 'package:flutter_automation_atlas/src/atlas_checks.dart';
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
import 'package:flutter_automation_atlas/src/atlas_prune.dart';
import 'package:flutter_automation_atlas/src/atlas_published_variants.dart';
import 'package:flutter_automation_atlas/src/atlas_remote_shots.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_encoder.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_id.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_migration.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_references.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_source.dart';
import 'package:flutter_automation_atlas/src/atlas_site_server.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_check.dart';
import 'package:flutter_automation_atlas/src/atlas_store_reader.dart';
import 'package:flutter_automation_atlas/src/atlas_version_tags.dart';
import 'package:flutter_automation_atlas/src/atlas_versions.dart';

/// {@category Utils}
///
/// Keeps the atlas of a project in step with the app. The atlas holds a
/// snapshot of each automation flow variant, and one screenshot, journal and
/// design link per stage.
///
/// A project calls it from its own file:
///
/// ```dart
/// Future<void> main(List<String> args) {
///   return runAtlas(args, MyAtlasProject());
/// }
/// ```
///
/// - `capture <flow> [<variant>...]` walks the named variants in order.
///   When the command names no variant, it walks each variant of the
///   flow. It uses the one booted iOS simulator and writes the snapshots and
///   shots. The command resolves each name before the app launches, so a
///   misspelt name fails first. A full walk of a variant writes the answer
///   records of the variant when the flow is in the QA catalogue and the
///   locale is the default locale.
/// - `capture <flow> <variant> --stages <i,…>` walks the one variant up to
///   the last of the stage indexes. It shoots only these stages; the last
///   stage shoots the end too. It keeps each other stage with its hashes,
///   the way `capture --stale` captures stale stages without a rebase. It
///   walks a variant with no snapshot whole.
/// - `capture --stale` captures exactly what `stale` names:
///   - Each `stage journal` stage takes the journal of the current headless
///     report without a device.
///   - A variant that is stale as a whole, or in each other stage, gets a
///     whole walk.
///   - A variant with other stale stages gets a walk up to the last of them.
///     The walk shoots only these stages and keeps each other stage. Each
///     stage that `stale` found fresh takes the hashes of the current files.
/// - `stale [<flow>]` prints one line per variant. For the variant as a
///   whole, the line is one of these words: `fresh`, `new`, `definition`,
///   `failed`, `manifest` or `code`, with the changed paths. For stages, the
///   line is `stage definition`, `stage code`, `stage mock`, `stage journal`,
///   `stage analytics` or `locale`. It lists the stale stage indexes, the
///   changed paths, the changed keys, the request that the mock answers
///   differently and the journal that the baseline walk does not reproduce.
///   With `--published`, before it prints, it walks headless the variants whose
///   frames it did not compare ([AtlasHeadlessSelection]). It does this in one
///   run, and it checks them again. `capture --stale --published` does the
///   same. `--no-walk` keeps both to the reports on disk. With
///   `--require-fresh`, after it prints the lines, `stale` exits with code 1
///   when a line names another reason than `fresh`. `capture --stale` does
///   not take that flag.
/// - `headless [--baseline] [<flow> [<variant>...]]` walks variants in the
///   app under `flutter test`. It walks the published variants, the variants
///   of the flow or the named ones. It uses the in-app mock and no device. It
///   writes the hash and the PNG of the frame, and the journal of each stage
///   and of the end, to the headless folder under the build folder of the
///   project. With `--baseline` it walks each variant on the commit of its
///   snapshot and writes to the baseline folder. `stale` compares the current
///   report with the hashes of a snapshot, or with the baseline report.
/// - `headless --record [<flow> [<variant>...]]` walks the same variants and
///   checks them as `stale --no-walk` does. It writes the frame and journal
///   hashes of the current reports into the snapshots of the fresh variants
///   ([AtlasHeadlessRecord]). It names each variant that it leaves.
/// - `normalize-manifests` rewrites the manifest hashes that each stored
///   snapshot took of the raw content of a file. The new hashes are the ones
///   that `stale` compares. It prints the hashes that no version of the file
///   in git history matches.
/// - `source-commit --snapshot <file>` prints the commit that `stale` takes
///   as the baseline of the snapshot file, or `not found`.
/// - `stale --published` and `capture --stale --published` keep to the
///   variants that the published variants list of the project names.
/// - `render [--edition <name>]` writes the page of the edition to
///   `index.html` in the store folder. The default edition is `full`. The
///   page reads its shots from `shots/<hash>.png` beside it. The command
///   removes the shots and the declarations that no stored snapshot names.
///   It writes the reports of the project ([AtlasProject.writeReports]).
///   With a remote shot storage, the page reads its shots by the link
///   template of the storage, and the command removes no shot.
/// - `bundle --edition <name> --shots <source> [--locale <code|all>]` writes
///   the page of the edition as `index.html` in its own folder under the
///   build folder, one folder per edition and locale. The source is `files`,
///   `inline`, `sheets` or `urls`. The bundle first deletes each file and
///   folder in `shots/` beside the page.
///   - `files` copies the shots to `shots/`.
///   - `inline` embeds them as WebP sheets.
///   - `sheets` writes the WebP sheets as `shots/<sheet hash>.webp`. The hash
///     of the sheet bytes names each file.
///   - `urls` puts the link template of [AtlasProject.shotStorage] into the
///     page, and puts nothing into the storage.
///
///   With a remote shot storage, the other three sources read the shots from
///   the cache folder. They first read from the storage each shot that the
///   cache does not hold.
///
///   `--locale` names the one series that the page shows. `all`, or no
///   option, shows all page locales in one file. The command prints the bytes
///   of the page, the bytes and the files of the whole bundle, and its
///   images. The bundle stops with its size when the page passes the
///   `maxBundleBytes` limit or the images pass the `maxBundleImages` limit
///   of `flutter_automation: atlas:`. `maxBundleImages` counts the inline
///   sheets, the sheet files or the shot files.
/// - `check` runs the six checks of [AtlasChecks]. It prints one line per
///   check, with the lines of each problem under it:
///   - `page` holds the committed page against its sources.
///   - `publishedVariants` holds the published variants list against the flow
///     files and the snapshots.
///   - `snapshots` holds the published snapshots against the variants. A
///     stale variant warns.
///   - `localeKeyCoverage` holds the translation keys against the frames and
///     the uncovered keys list.
///   - `shots` holds the screenshot identifiers of the snapshots. It fails
///     an identifier that is not 64 lowercase hex digits. It fails also an
///     identifier that a remote shot storage does not hold.
///
///   The command exits with code 1 when a check fails.
/// - `migrate-shots` renames each file of the shots folder of the store to
///   the SHA-256 of its bytes. It rewrites only the `shot` fields of the
///   snapshots ([AtlasShotMigration]). With a remote shot storage, it puts
///   the files into the storage. It then asks the storage for each
///   identifier.
/// - `upload-shots` reads the screenshot files of the shots folder of the
///   store and of the cache folder. It puts into the remote shot storage
///   each file that the storage does not hold.
/// - `delete-shots <id>...` removes the named screenshots from the remote
///   shot storage. It removes nothing when a file of the repository of the
///   store names one of them ([AtlasShotReferences]).
/// - `publish-version --site <folder> --version <label>` writes the folder
///   of a version into the site folder ([AtlasVersions]). It needs also
///   `--position <number>` and `--edition <name>`, and it takes
///   `--locale <code|all>` as a bundle does. The folder holds the page
///   without data, `index.html`, and the data that the page reads,
///   `data.json.gz`. The command writes the row of the version into
///   `versions.json` by its position. It writes the link template of the
///   shot storage into `atlas-config.json`. It points the `index.html` of
///   the site folder at the version with the largest position. It stops when
///   the branch `origin/main` holds the folder of the version. The command
///   needs a remote shot storage.
/// - `open --site <folder> [--version <label>]` serves the site folder on
///   `127.0.0.1` ([AtlasSiteServer]). It prints the address and opens the
///   page of the version in the browser, or the `index.html` of the site
///   folder. It runs until Ctrl+C.
/// - `prune [--site <folder>...] [--repo-only | --storage-only] [--apply]`
///   reports what the repository of the store folder and the shot storage
///   hold past their use ([AtlasPrune]). With `--apply`, it deletes that.
///   Without `--site`, it takes each folder `site/<name>/` of the repository
///   that holds an `atlas-config.json`.
/// - `tag-versions [--site <folder>...]` puts on `origin` the git tag of
///   each row of `versions.json` whose folder the branch `origin/main` holds
///   ([AtlasVersionTags]). The field `versionTagTemplate` of
///   `atlas-config.json` gives the name of the tag. The tag names the commit
///   that last added the `data.json.gz` file of the version. The command
///   takes the site folders as `prune` does.
///
/// A project with a remote shot storage ([AtlasProject.shotStorage]) keeps no
/// screenshot in the store folder. The commands read and write the files in
/// the cache folder `shots/` under the build folder, and
/// `--shots-cache <folder>` names another folder.
///
/// `capture` and `stale` take `--locale <code>`. The default is the first
/// locale of the project. The app runs in that locale, and its values come
/// from the translations of the project. Each command takes
/// `--store <folder>`, the folder of the snapshots, the declarations, the
/// shots and the page. The default is the output folder of the project. Each
/// command also takes `--source-label <text>`, the label of the source that
/// the page footer shows.
///
/// `headless` with `--published` or `--no-walk` fails with the usage. So does
/// `capture` with `--no-walk` but without `--stale`, and `capture` or
/// `headless` with `--require-fresh`.
///
/// A capture or a headless walk that did not pass exits with code 1. So does
/// `stale --require-fresh` when a variant is not fresh.
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
  static const _checkCommand = 'check';
  static const _migrateShotsCommand = 'migrate-shots';
  static const _uploadShotsCommand = 'upload-shots';
  static const _deleteShotsCommand = 'delete-shots';
  static const _publishVersionCommand = 'publish-version';
  static const _openCommand = 'open';
  static const _pruneCommand = 'prune';
  static const _tagVersionsCommand = 'tag-versions';
  static const _staleFlag = '--stale';
  static const _baselineFlag = '--baseline';
  static const _recordFlag = '--record';
  static const _noWalkFlag = '--no-walk';
  static const _publishedFlag = '--published';
  static const _requireFreshFlag = '--require-fresh';
  static const _repoOnlyFlag = '--repo-only';
  static const _storageOnlyFlag = '--storage-only';
  static const _applyFlag = '--apply';
  static const _localeOption = '--locale';
  static const _stagesOption = '--stages';
  static const _storeOption = '--store';
  static const _sourceLabelOption = '--source-label';
  static const _snapshotOption = '--snapshot';
  static const _editionOption = '--edition';
  static const _shotsOption = '--shots';
  static const _shotsCacheOption = '--shots-cache';
  static const _siteOption = '--site';
  static const _versionOption = '--version';
  static const _positionOption = '--position';
  static const _pngExtension = '.png';
  static const _allLocales = 'all';
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
      '$_staleCommand [$_publishedFlag] [$_noWalkFlag] [$_requireFreshFlag] '
      '[$_localeOption <code>] [<flow>] | '
      '$_headlessCommand [$_baselineFlag | $_recordFlag] '
      '[<flow> [<variant>...]] | '
      '$_normalizeManifestsCommand | '
      '$_sourceCommitCommand $_snapshotOption <file> | '
      '$_renderCommand [$_editionOption <name>] | '
      '$_checkCommand | '
      '$_migrateShotsCommand | '
      '$_uploadShotsCommand | '
      '$_deleteShotsCommand <id>... | '
      '$_publishVersionCommand $_siteOption <folder> $_versionOption <label> '
      '$_positionOption <number> $_editionOption <name> '
      '[$_localeOption <code|$_allLocales>] | '
      '$_openCommand $_siteOption <folder> [$_versionOption <label>] | '
      '$_pruneCommand [$_siteOption <folder>...] '
      '[$_repoOnlyFlag | $_storageOnlyFlag] [$_applyFlag] | '
      '$_tagVersionsCommand [$_siteOption <folder>...] | '
      '$_bundleCommand $_editionOption <name> '
      '$_shotsOption <files|inline|sheets|urls> '
      '[$_localeOption <code|$_allLocales>] '
      '[$_storeOption <folder>] [$_sourceLabelOption <text>] '
      '[$_shotsCacheOption <folder>]';

  /// The arguments of the command.
  final List<String> args;

  /// The places the commands read and write.
  final AtlasLocations locations;

  final AtlasProject _project;
  final AtlasStalenessReader? _readStalenesses;
  final AtlasHeadlessPass? _headlessPass;
  final AtlasShotEncoder? _shotEncoder;

  /// The [rootPath] parameter names the repository that the commands read and
  /// write. The [readStalenesses] parameter tells the staleness of each of
  /// the variants in their order. It is [AtlasStaleCheck] by default. The
  /// [headlessPass] parameter walks variants headless. It walks the current
  /// tree by default. The [shotEncoder] parameter turns shots into the sheets
  /// that a bundle inlines or writes as files. It makes WebP sheets by
  /// default.
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
         shotsCache: _tryReadOption(args, _shotsCacheOption),
       ),
       _readStalenesses = readStalenesses,
       _headlessPass = headlessPass,
       _shotEncoder = shotEncoder;

  /// The label of the source that the page shows; `null` when the command
  /// gives none.
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

  bool get _isFreshRequired => args.contains(_requireFreshFlag);

  bool get _isHeadlessRefused {
    return _isPublishedOnly || args.contains(_noWalkFlag) || _isFreshRequired;
  }

  List<String> get _positionalArguments {
    const options = {
      _localeOption,
      _stagesOption,
      _storeOption,
      _sourceLabelOption,
      _snapshotOption,
      _editionOption,
      _shotsOption,
      _shotsCacheOption,
      _siteOption,
      _versionOption,
      _positionOption,
    };
    final optionIndexes = {
      for (final (index, arg) in args.indexed)
        if (options.contains(arg)) ...[index, index + 1],
    };

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
      case _checkCommand:
        await _check();
      case _migrateShotsCommand:
        await _migrateShots();
      case _uploadShotsCommand:
        await _uploadShots();
      case _deleteShotsCommand:
        await _deleteShots();
      case _publishVersionCommand:
        await _publishVersion();
      case _openCommand:
        await _open();
      case _pruneCommand:
        await _prune();
      case _tagVersionsCommand:
        _tagVersions();
      case _:
        throw const AtlasException(_usage);
    }
  }

  /// Writes the reports of the project that read the atlas, from the store
  /// folder the command names.
  void writeReports() {
    _project.writeReports(AtlasLocationsStore(locations));
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
      _requireFreshFlag,
      _baselineFlag,
      _recordFlag,
      _noWalkFlag,
      _repoOnlyFlag,
      _storageOnlyFlag,
      _applyFlag,
    }.contains(arg);
  }

  Future<void> _capture(String locale) async {
    if (_isFreshRequired) {
      throw const AtlasException(_usage);
    }

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

    final stalenesses = await _checkStale(
      locale,
      _readCheckedVariants(variants),
    );

    for (final staleness in stalenesses) {
      stdout.writeln(staleness.describe());
    }

    if (_isFreshRequired && stalenesses.any((staleness) => staleness.isStale)) {
      exitCode = _failureExitCode;
    }
  }

  Future<void> _walkHeadless() async {
    if (_isHeadlessRefused) {
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
      'Wrote ${rendering.path}: ${rendering.pageBytes} page bytes, '
      '${rendering.bundleBytes} bundle bytes in ${rendering.files} files, '
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

  Future<void> _check() async {
    final checks = AtlasChecks(
      _project,
      rootPath: locations.rootPath,
      store: _tryReadOption(args, _storeOption),
      shotsCache: _tryReadOption(args, _shotsCacheOption),
      sourceLabel: sourceLabel,
    );
    final outcomes = {
      'page': await checks.page(),
      'publishedVariants': await checks.publishedVariants(),
      'storedVariants': await checks.storedVariants(),
      'snapshots': await AtlasSnapshotsCheck(
        locations,
        readStalenesses: _readStalenesses,
      ).run(),
      'localeKeyCoverage': await checks.localeKeyCoverage(),
      'shots': await checks.shots(),
    };

    for (final MapEntry(key: name, value: outcome) in outcomes.entries) {
      outcome.describe(name).forEach(stdout.writeln);
    }

    if (outcomes.values.any((outcome) => outcome.isFailure)) {
      exitCode = _failureExitCode;
    }
  }

  Future<void> _migrateShots() async {
    final result = await AtlasShotMigration(locations).run();

    stdout.writeln(
      'Renamed ${result.renamedShots} shots, rewrote '
      '${result.rewrittenSnapshots} snapshots, stored ${result.storedShots} '
      'shots',
    );
  }

  Future<void> _uploadShots() async {
    final remoteShots = _resolveRemoteShots();
    final pathsByShot = {
      for (final directory in [
        locations.shotsCachePath,
        locations.storeShotsPath,
      ])
        ..._listShotFiles(directory),
    };

    final absent = await remoteShots.findAbsent(pathsByShot.keys);

    await remoteShots.upload({
      for (final shot in absent) shot: ?pathsByShot[shot],
    });

    stdout.writeln('Uploaded ${absent.length} of ${pathsByShot.length} shots');
  }

  Future<void> _deleteShots() async {
    final remoteShots = _resolveRemoteShots();
    final shots = _positionalArguments.skip(1).toList();

    if (shots.isEmpty || !shots.every(AtlasShotId.isValid)) {
      throw const AtlasException(_usage);
    }

    final references = await AtlasShotReferences(locations.storePath).read();

    final needed = shots.where(references.contains).toList();

    if (needed.isNotEmpty) {
      throw AtlasException(
        'The repository of ${locations.storePath} names the shots '
        '${needed.join(', ')}; nothing is deleted.',
      );
    }

    await remoteShots.delete(shots);

    stdout.writeln('Deleted ${shots.length} shots');
  }

  Future<void> _publishVersion() async {
    final versions = AtlasVersions(_readOption(_siteOption));
    final label = _readOption(_versionOption);
    final position = int.tryParse(_readOption(_positionOption));
    final editionName = _readOption(_editionOption);
    final localeName = _tryReadOption(args, _localeOption);

    if (position == null) {
      throw const AtlasException(_usage);
    }

    final rendering = await _createRenderer().buildVersion(
      edition: locations.pageConfig.resolveEdition(editionName),
      version: label,
      locale: localeName == _allLocales ? null : localeName,
    );

    versions.publish(
      AtlasVersion(
        label: label,
        position: position,
        builtAt: rendering.builtAt.toIso8601String(),
        sourceLabel: sourceLabel,
      ),
      rendering,
    );
    stdout.writeln(
      'Wrote ${versions.resolveVersionPath(label)}: '
      '${rendering.page.length} page characters, ${rendering.data.length} '
      'data bytes',
    );
  }

  Future<void> _open() async {
    final sitePath = _readOption(_siteOption);

    final server = await AtlasSiteServer.start(sitePath);

    final address = server.resolvePageAddress(
      _tryReadOption(args, _versionOption),
    );

    stdout.writeln('Serving $sitePath at $address until Ctrl+C');

    await AtlasSiteServer.openInBrowser(address);
    await ProcessSignal.sigint.watch().first;
    await server.stop();
  }

  Future<void> _prune() async {
    final report = await AtlasPrune(
      locations,
      sites: _readSites(),
    ).run(scope: _readPruneScope(), isApplied: args.contains(_applyFlag));

    report.describe().forEach(stdout.writeln);
  }

  void _tagVersions() {
    final tags = AtlasVersionTags(locations, sites: _readSites()).run();

    for (final tag in tags) {
      stdout.writeln('Tagged ${tag.name} at ${tag.commit}');
    }

    stdout.writeln('Tagged ${tags.length} versions');
  }

  String _readOption(String option) {
    return _tryReadOption(args, option) ?? (throw const AtlasException(_usage));
  }

  List<String> _readSites() {
    final sites = [
      for (final (index, arg) in args.indexed)
        if (arg == _siteOption) args.elementAtOrNull(index + 1),
    ];

    if (sites.any((site) => site == null || site.startsWith('-'))) {
      throw const AtlasException(_usage);
    }

    return sites.nonNulls.toList();
  }

  AtlasPruneScope _readPruneScope() {
    final isRepositoryOnly = args.contains(_repoOnlyFlag);
    final isStorageOnly = args.contains(_storageOnlyFlag);

    if (isRepositoryOnly && isStorageOnly) {
      throw const AtlasException(_usage);
    }

    if (isRepositoryOnly) {
      return AtlasPruneScope.repository;
    }

    return isStorageOnly ? AtlasPruneScope.storage : AtlasPruneScope.all;
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

  AtlasRemoteShots _resolveRemoteShots() {
    final remoteShots = AtlasRemoteShots.tryCreate(locations);

    if (remoteShots == null) {
      throw const AtlasException(
        'The command needs AtlasProject.shotStorage, and the project returns '
        'none.',
      );
    }

    return remoteShots;
  }

  Map<String, String> _listShotFiles(String path) {
    final directory = Directory(path);

    if (!directory.existsSync()) {
      return const {};
    }

    return {
      for (final file in directory.listSync().whereType<File>())
        if (file.path.endsWith(_pngExtension) &&
            AtlasShotId.isValid(_readFileShot(file)))
          _readFileShot(file): file.path,
    };
  }

  String _readFileShot(File file) {
    return p.basenameWithoutExtension(file.path);
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
