import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_page_config.dart';
import 'package:flutter_automation_atlas/src/atlas_project.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_automation_atlas/src/atlas_declarations.dart';
import 'package:flutter_automation_atlas/src/atlas_source_hash.dart';

/// {@category Utils}
///
/// Where the atlas reads its flows and writes its snapshots and its page,
/// every path resolved against one root.
///
/// The snapshots, the declarations, the screenshots and the page live in the
/// store folder; everything else the atlas builds lives under the build folder
/// of the project, and every source file is read from the root.
///
/// Each reader and writer of the atlas takes an instance, so a test points
/// them at a temporary directory instead of the repository.
final class AtlasLocations {
  /// The folder of the shots beside a page, by its name.
  static const shotsDirectory = 'shots';

  static final _configs = Expando<AutomationRunnerConfig>();
  static final _pageConfigs = Expando<AtlasPageConfig>();
  static final _sourceHashes = Expando<AtlasSourceHash>();

  static const _pubspecPath = 'pubspec.yaml';
  static const _dataDirectory = 'data';
  static const _declarationsDirectory = 'declarations';
  static const _shotCacheDirectory = 'shot_cache';
  static const _headlessDirectory = 'headless';
  static const _headlessBaselineDirectory = 'headless_baseline';
  static const _baselineWorktreesDirectory = 'baseline_worktrees';
  static const _pageFileName = 'index.html';
  static const _bundleDirectoryPrefix = 'bundle';
  static const _jsonExtension = '.json';
  static const _pngExtension = '.png';

  /// The directory every source path is resolved against.
  final String rootPath;

  /// The project the atlas serves.
  final AtlasProject project;

  /// The store folder, absolute or relative to the working directory; the
  /// output folder of the project when absent.
  final String? _store;

  /// The [rootPath] parameter names the repository the commands read; the
  /// [store] parameter replaces the output folder of the project.
  const AtlasLocations(this.rootPath, this.project, {String? store})
    : _store = store;

  /// The `flutter_automation:` section of the `pubspec.yaml` under the root,
  /// read once per instance.
  AutomationRunnerConfig get config {
    return _configs[this] ??= AutomationRunnerConfig.read(
      resolve(_pubspecPath),
    );
  }

  /// The `flutter_automation: atlas:` section of the `pubspec.yaml` under the
  /// root, read once per instance.
  AtlasPageConfig get pageConfig {
    return _pageConfigs[this] ??= AtlasPageConfig.read(resolve(_pubspecPath));
  }

  /// The hash a source file of the project is compared by, built once per
  /// instance from [AtlasProject.staleSettings].
  AtlasSourceHash get sourceHash {
    return _sourceHashes[this] ??= AtlasSourceHash(project.staleSettings);
  }

  /// The locale a capture runs in when none is named, and whose series every
  /// other locale falls back to.
  String get defaultLocale => project.locales.first;

  /// The locales whose series the page shows, the default one first.
  List<String> get pageLocales => project.locales;

  /// The `package:` prefix of the libraries of the project under the root.
  String get packagePrefix => config.packagePrefix;

  /// The folder of the atlas: the snapshots, the declarations, the
  /// screenshots and the page.
  String get storePath {
    final store = _store;

    return store == null ? resolve(project.paths.output) : p.absolute(store);
  }

  /// The entry point of the automation runner.
  String get runnerEntryPath => project.paths.runnerEntry;

  /// The folder of the recordings of the QA catalogue.
  String get recordingsPath => project.paths.recordings;

  /// The list naming the variants of each flow the page shows.
  String get publishedVariantsPath => resolve(project.paths.publishedVariants);

  /// Directory holding one snapshot per captured variant and locale.
  String get dataPath => p.join(storePath, _dataDirectory);

  /// Directory holding the screenshots, each named by its content hash.
  String get shotsPath => p.join(storePath, shotsDirectory);

  /// Directory holding the declarations of every manifest file, each record
  /// named by the source hash of the file content it was read from.
  String get declarationsPath => p.join(storePath, _declarationsDirectory);

  /// The rendered page.
  String get pagePath => p.join(storePath, _pageFileName);

  /// Directory holding the WebP encode of every shot a bundle inlined, each
  /// named by the shot's content hash.
  String get bundleShotCachePath {
    return resolve(p.join(project.paths.build, _shotCacheDirectory));
  }

  /// Directory holding the detached worktree of every commit a baseline walk
  /// checks out, kept out of the repository under the build folder.
  String get baselineWorktreesPath {
    return resolve(p.join(project.paths.build, _baselineWorktreesDirectory));
  }

  /// The declarations of the Dart [source], read with the theme classes of
  /// the project.
  AtlasDeclarations readDeclarations(String source) {
    final settings = project.staleSettings;

    return AtlasDeclarations.read(
      source,
      themeClassPattern: settings.themeClassPattern,
      themeValueClassPattern: settings.themeValueClassPattern,
    );
  }

  /// Resolves a path relative to the root.
  String resolve(String relativePath) {
    return p.normalize(p.join(rootPath, relativePath));
  }

  /// The bundle page of the [edition], for the series of [locale] or, when
  /// [locale] is absent, for every page locale: the file
  /// `bundle.<edition>[.<locale>]/index.html` under the build folder, out of
  /// the repository.
  String resolveBundlePagePath(String edition, {String? locale}) {
    final suffix = locale == null ? '' : '.$locale';

    return resolve(
      p.join(
        project.paths.build,
        '$_bundleDirectoryPrefix.$edition$suffix',
        _pageFileName,
      ),
    );
  }

  /// The shots a bundle page reads from files, beside the page.
  String resolveBundleShotsPath(String bundlePagePath) {
    return p.join(p.dirname(bundlePagePath), shotsDirectory);
  }

  /// The snapshot file of one variant of a flow captured in [locale].
  String resolveSnapshotPath({
    required String flow,
    required String variant,
    required String locale,
  }) {
    return p.join(dataPath, flow, '$variant.$locale$_jsonExtension');
  }

  /// The headless report of one variant of a flow walked in [locale], the
  /// baseline one when [isBaseline] is set, kept out of the repository under
  /// the build folder.
  String resolveHeadlessReportPath({
    required String flow,
    required String variant,
    required String locale,
    bool isBaseline = false,
  }) {
    return resolve(
      p.join(
        project.paths.build,
        isBaseline ? _headlessBaselineDirectory : _headlessDirectory,
        flow,
        '$variant.$locale$_jsonExtension',
      ),
    );
  }

  /// The detached worktree a baseline walk checks [commit] out into.
  String resolveBaselineWorktreePath(String commit) {
    return p.join(baselineWorktreesPath, commit);
  }

  /// The variant a snapshot file at [snapshotPath] is named after.
  String resolveSnapshotVariant(String snapshotPath) {
    return p.basenameWithoutExtension(p.basenameWithoutExtension(snapshotPath));
  }

  /// The locale a snapshot file at [snapshotPath] is named after.
  ///
  /// Throws an [AtlasException] naming [snapshotPath] when its name carries no
  /// locale.
  String resolveSnapshotLocale(String snapshotPath) {
    final localeExtension = p.extension(
      p.basenameWithoutExtension(snapshotPath),
    );

    if (localeExtension.isEmpty) {
      throw AtlasException(
        'Snapshot $snapshotPath names no locale: it is '
        '<variant>.<locale>$_jsonExtension.',
      );
    }

    return localeExtension.substring(1);
  }

  /// The screenshot file named by the [shot] content hash.
  String resolveShotPath(String shot) {
    return p.join(shotsPath, '$shot$_pngExtension');
  }

  /// The declarations record of the manifest file content whose source hash
  /// is [sourceHash].
  String resolveDeclarationsPath(String sourceHash) {
    return p.join(declarationsPath, '$sourceHash$_jsonExtension');
  }
}
