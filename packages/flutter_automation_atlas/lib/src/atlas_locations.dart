import 'dart:io';

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
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
/// The snapshots, the declarations and the page live in the store folder.
/// The screenshots live in its shots folder, or in the remote storage of
/// [AtlasProject.shotStorage] with a cache under the build folder. Everything
/// else that the atlas builds lives under the build folder of the project.
/// The atlas reads each source file from the root.
///
/// Each reader and writer of the atlas takes an instance, so a test points
/// them at a temporary directory instead of the repository.
final class AtlasLocations {
  /// The folder of the shots beside a page, by its name.
  static const shotsDirectory = 'shots';

  static final _configs = Expando<AutomationRunnerConfig>();
  static final _pageConfigs = Expando<AtlasPageConfig>();
  static final _sourceHashes = Expando<AtlasSourceHash>();

  static const _localePlaceholder = '{locale}';
  static const _pubspecPath = 'pubspec.yaml';
  static const _dataDirectory = 'data';
  static const _declarationsDirectory = 'declarations';
  static const _shotCacheDirectory = 'shot_cache';
  static const _remoteShotsDirectory = 'shots';
  static const _headlessDirectory = 'headless';
  static const _headlessBaselineDirectory = 'headless_baseline';
  static const _baselineWorktreesDirectory = 'baseline_worktrees';
  static const _pageFileName = 'index.html';
  static const _bundleDirectoryPrefix = 'bundle';
  static const _jsonExtension = '.json';
  static const _pngExtension = '.png';

  /// The directory that each source path starts from.
  final String rootPath;

  /// The project the atlas serves.
  final AtlasProject project;

  /// The store folder, absolute or relative to the current directory. It is
  /// `null` when the output folder of the project applies.
  final String? _store;

  /// The cache of the screenshots of a remote storage, absolute or relative
  /// to the current directory. It is `null` when the folder under the build
  /// folder applies.
  final String? _shotsCache;

  /// The [rootPath] parameter names the repository the commands read. The
  /// [store] parameter replaces the output folder of the project. The
  /// [shotsCache] parameter replaces the cache folder of the screenshots of a
  /// remote storage.
  const AtlasLocations(
    this.rootPath,
    this.project, {
    String? store,
    String? shotsCache,
  }) : _store = store,
       _shotsCache = shotsCache;

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

  /// The hash that the atlas compares a source file of the project with. The
  /// getter builds it once per instance from [AtlasProject.staleSettings].
  AtlasSourceHash get sourceHash {
    return _sourceHashes[this] ??= AtlasSourceHash(project.staleSettings);
  }

  /// The locale a capture runs in when the command names none. The series of
  /// this locale is the fallback of all other locales.
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

  /// The directory that holds one snapshot per captured variant and locale.
  String get dataPath => p.join(storePath, _dataDirectory);

  /// Whether a remote storage keeps the screenshots, not the store folder.
  bool get hasShotStorage => project.shotStorage != null;

  /// The shots folder of the store. It holds the screenshots while no remote
  /// storage keeps them.
  String get storeShotsPath => p.join(storePath, shotsDirectory);

  /// The cache of the screenshots of a remote storage: the frames a capture
  /// shot and the files a command read from the storage. It is under the
  /// build folder, outside the repository.
  String get shotsCachePath {
    final cache = _shotsCache;

    return cache == null
        ? resolve(p.join(project.paths.build, _remoteShotsDirectory))
        : p.absolute(cache);
  }

  /// The directory that the commands read and write the screenshot files in,
  /// each named by its identifier: [shotsCachePath] with a remote storage,
  /// else [storeShotsPath].
  String get shotsPath => hasShotStorage ? shotsCachePath : storeShotsPath;

  /// The directory that holds the declarations of each manifest file. The
  /// source hash of the file content that the atlas read names each record.
  String get declarationsPath => p.join(storePath, _declarationsDirectory);

  /// The rendered page.
  String get pagePath => p.join(storePath, _pageFileName);

  /// The directory that holds the WebP encode of each shot that a bundle
  /// inlined. The content hash of the shot names each file.
  String get bundleShotCachePath {
    return resolve(p.join(project.paths.build, _shotCacheDirectory));
  }

  /// The directory that holds the detached worktree of each commit that a
  /// baseline walk checks out. It is under the build folder, outside the
  /// repository.
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

  /// The translations the app shows in [locale]: what
  /// [AtlasProject.translations] returns, else the file
  /// [AtlasPaths.translations] names, else none.
  ///
  /// Throws an [AtlasException] when the template names no file for the
  /// default locale, or the file is malformed. A missing file of another
  /// locale gives none.
  Map<String, Object?> readTranslations(String locale) {
    final values = project.translations(locale);
    final template = project.paths.translations;

    if (values.isNotEmpty || template == null) {
      return values;
    }

    final file = File(resolve(template.replaceAll(_localePlaceholder, locale)));

    if (!file.existsSync()) {
      if (locale == defaultLocale) {
        throw AtlasException('No translations at ${file.path}.');
      }

      return const {};
    }

    return AtlasJson.decodeObject(
      file.readAsStringSync(),
      'The translations file ${file.path}',
    );
  }

  /// The prose of each design screen: what [AtlasProject.screenDescriptions]
  /// returns, else the file [AtlasPaths.screenDescriptions] names, else none.
  ///
  /// Throws an [AtlasException] when that file is missing or malformed.
  Map<String, Map<String, String>> readScreenDescriptions() {
    final descriptions = project.screenDescriptions;
    final path = project.paths.screenDescriptions;

    if (descriptions.isNotEmpty || path == null) {
      return descriptions;
    }

    final file = File(resolve(path));

    if (!file.existsSync()) {
      throw AtlasException('No screen descriptions at ${file.path}.');
    }

    final json = AtlasJson.decodeObject(
      file.readAsStringSync(),
      'The screen descriptions ${file.path}',
    );

    return {
      for (final MapEntry(:key, :value) in json.entries)
        key: {
          for (final MapEntry(key: locale, value: text) in AtlasJson.readObject(
            value,
            'The description of $key',
          ).entries)
            locale: '$text',
        },
    };
  }

  /// Resolves a path relative to the root.
  String resolve(String relativePath) {
    return p.normalize(p.join(rootPath, relativePath));
  }

  /// The bundle page of the [edition], for the series of [locale]. When
  /// [locale] is `null`, the page covers all page locales. The path is the
  /// file `bundle.<edition>[.<locale>]/index.html` under the build folder,
  /// outside the repository.
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

  /// The headless report of one variant of a flow walked in [locale]. It is
  /// the baseline report when [isBaseline] is `true`. The path is under the
  /// build folder, outside the repository.
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

  /// The variant that gives the name of the snapshot file at [snapshotPath].
  String resolveSnapshotVariant(String snapshotPath) {
    return p.basenameWithoutExtension(p.basenameWithoutExtension(snapshotPath));
  }

  /// The locale that gives the name of the snapshot file at [snapshotPath].
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

  /// The screenshot file named by the [shot] identifier, in [shotsPath].
  String resolveShotPath(String shot) {
    return p.join(shotsPath, '$shot$_pngExtension');
  }

  /// The screenshot file named by the [shot] identifier, in
  /// [storeShotsPath].
  String resolveStoreShotPath(String shot) {
    return p.join(storeShotsPath, '$shot$_pngExtension');
  }

  /// The declarations record of the manifest file content whose source hash
  /// is [sourceHash].
  String resolveDeclarationsPath(String sourceHash) {
    return p.join(declarationsPath, '$sourceHash$_jsonExtension');
  }
}
