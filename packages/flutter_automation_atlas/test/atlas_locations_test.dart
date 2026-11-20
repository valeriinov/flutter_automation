import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';

import 'test_utils/fake_atlas_project.dart';
import 'test_utils/test_atlas_root.dart';

const _rootPath = '/repo';
const _snapshotPath = '/repo/atlas_store/data/shop_flow/shopFromSearch.en.json';
final _locations = AtlasLocations(_rootPath, FakeAtlasProject());

void main() {
  group('AtlasLocations Tests', () {
    _atlasLocations_should_nameSnapshotByVariantAndLocale();
    _atlasLocations_should_readVariantAndLocaleBackFromSnapshotPath();
    _atlasLocations_should_rejectSnapshotPathWithoutLocale();
    _atlasLocations_should_keepStoreFilesUnderStoreFolder();
    _atlasLocations_should_preferStoreFolderOverProjectOutput();
    _atlasLocations_should_keepBundlePageUnderBuild();
    _atlasLocations_should_keepBaselineWorktreeOfCommitUnderItsDirectory();
    _atlasLocations_should_keepHeadlessReportsUnderBuild();
    _atlasLocations_should_readPackagePrefixFromPubspecOfItsRoot();
    _atlasLocations_should_takeLocalesFromProject();
    _atlasLocations_should_readTranslationsOfLocaleFromPathsTemplate();
    _atlasLocations_should_readNoTranslationsWithoutFile();
    _atlasLocations_should_preferProjectTranslationsOverFile();
    _atlasLocations_should_readScreenDescriptionsFromPathsFile();
    _atlasLocations_should_rejectMissingTranslationsFileOfDefaultLocale();
    _atlasLocations_should_rejectMissingScreenDescriptionsFile();
  });
}

void _atlasLocations_should_nameSnapshotByVariantAndLocale() {
  test('AtlasLocations should name snapshot by variant and locale', () {
    final path = _locations.resolveSnapshotPath(
      flow: 'shop_flow',
      variant: 'shopFromSearch',
      locale: 'en',
    );

    expect(path, _snapshotPath);
  });
}

void _atlasLocations_should_readVariantAndLocaleBackFromSnapshotPath() {
  test(
    'AtlasLocations should read variant and locale back from snapshot path',
    () {
      final variant = _locations.resolveSnapshotVariant(_snapshotPath);
      final locale = _locations.resolveSnapshotLocale(_snapshotPath);

      expect(variant, 'shopFromSearch');
      expect(locale, 'en');
    },
  );
}

void _atlasLocations_should_rejectSnapshotPathWithoutLocale() {
  test('AtlasLocations should reject snapshot path without locale', () {
    const path = '/repo/data/shop_flow/shopFromSearch.json';

    expect(
      () => _locations.resolveSnapshotLocale(path),
      throwsA(
        isA<AtlasException>().having(
          (error) => error.message,
          'message',
          contains(path),
        ),
      ),
    );
  });
}

void _atlasLocations_should_keepStoreFilesUnderStoreFolder() {
  test('AtlasLocations should keep store files under store folder', () {
    expect(_locations.storePath, '/repo/atlas_store');
    expect(_locations.pagePath, '/repo/atlas_store/index.html');
    expect(
      _locations.resolveShotPath('abc'),
      '/repo/atlas_store/shots/abc.png',
    );
    expect(
      _locations.resolveDeclarationsPath('def'),
      '/repo/atlas_store/declarations/def.json',
    );
  });
}

void _atlasLocations_should_preferStoreFolderOverProjectOutput() {
  test('AtlasLocations should prefer store folder over project output', () {
    final locations = AtlasLocations(
      _rootPath,
      FakeAtlasProject(),
      store: '/shared/atlas',
    );

    expect(locations.storePath, '/shared/atlas');
    expect(locations.dataPath, '/shared/atlas/data');
    expect(locations.pagePath, '/shared/atlas/index.html');
  });
}

void _atlasLocations_should_keepBundlePageUnderBuild() {
  test('AtlasLocations should keep bundle page under build', () {
    final path = _locations.resolveBundlePagePath('lite');
    final localePath = _locations.resolveBundlePagePath('lite', locale: 'en');

    expect(path, '/repo/build/atlas/bundle.lite/index.html');
    expect(localePath, '/repo/build/atlas/bundle.lite.en/index.html');
    expect(_locations.bundleShotCachePath, '/repo/build/atlas/shot_cache');
    expect(
      _locations.resolveBundleShotsPath(path),
      p.join('/repo/build/atlas/bundle.lite', 'shots'),
    );
  });
}

void _atlasLocations_should_keepBaselineWorktreeOfCommitUnderItsDirectory() {
  test('AtlasLocations should keep baseline worktree of commit under its '
      'directory', () {
    final path = _locations.resolveBaselineWorktreePath('fd749c6ee');

    expect(
      _locations.baselineWorktreesPath,
      '/repo/build/atlas/baseline_worktrees',
    );
    expect(path, '/repo/build/atlas/baseline_worktrees/fd749c6ee');
  });
}

void _atlasLocations_should_keepHeadlessReportsUnderBuild() {
  test('AtlasLocations should keep headless reports under build', () {
    final report = _locations.resolveHeadlessReportPath(
      flow: 'shop_flow',
      variant: 'shopFromSearch',
      locale: 'en',
    );
    final baseline = _locations.resolveHeadlessReportPath(
      flow: 'shop_flow',
      variant: 'shopFromSearch',
      locale: 'en',
      isBaseline: true,
    );

    expect(
      report,
      '/repo/build/atlas/headless/shop_flow/shopFromSearch.en.json',
    );
    expect(
      baseline,
      '/repo/build/atlas/headless_baseline/shop_flow/shopFromSearch.en.json',
    );
  });
}

void _atlasLocations_should_readPackagePrefixFromPubspecOfItsRoot() {
  test(
    'AtlasLocations should read package prefix from pubspec of its root',
    () async {
      await TestAtlasRoot.run((root) {
        expect(root.paths.packagePrefix, 'package:sample/');
      });
    },
  );
}

void _atlasLocations_should_takeLocalesFromProject() {
  test('AtlasLocations should take locales from project', () {
    final locations = AtlasLocations(
      _rootPath,
      FakeAtlasProject(locales: const ['de', 'fr']),
    );

    expect(locations.defaultLocale, 'de');
    expect(locations.pageLocales, ['de', 'fr']);
  });
}

const _pathsWithFiles = AtlasPaths(
  runnerEntry: 'tool/run_flows.dart',
  output: 'atlas_store',
  build: 'build/atlas',
  recordings: 'assets/recordings',
  publishedVariants: 'scripts/published_variants.json',
  translations: 'assets/{locale}.json',
  screenDescriptions: 'docs/screens.json',
);

void _atlasLocations_should_readTranslationsOfLocaleFromPathsTemplate() {
  test(
    'AtlasLocations should read translations of locale from paths template',
    () async {
      await TestAtlasRoot.runWith(
        project: FakeAtlasProject(pathsOverride: _pathsWithFiles),
        (root) {
          root.writeSource('assets/en.json', jsonEncode({'title': 'Shop'}));

          final translations = root.paths.readTranslations('en');

          expect(translations, {'title': 'Shop'});
        },
      );
    },
  );
}

void _atlasLocations_should_readNoTranslationsWithoutFile() {
  test('AtlasLocations should read no translations without file', () async {
    await TestAtlasRoot.runWith(
      project: FakeAtlasProject(pathsOverride: _pathsWithFiles),
      (root) {
        expect(root.paths.readTranslations('en'), isEmpty);
      },
    );
  });
}

void _atlasLocations_should_rejectMissingTranslationsFileOfDefaultLocale() {
  test('AtlasLocations should reject missing translations file of default '
      'locale', () async {
    await TestAtlasRoot.runWith(
      project: FakeAtlasProject(pathsOverride: _pathsWithFiles),
      (root) {
        expect(
          () => root.paths.readTranslations(root.paths.defaultLocale),
          throwsA(isA<AtlasException>()),
        );
      },
    );
  });
}

void _atlasLocations_should_preferProjectTranslationsOverFile() {
  test('AtlasLocations should prefer project translations over file', () async {
    await TestAtlasRoot.runWith(
      project: FakeAtlasProject(pathsOverride: _pathsWithFiles),
      (root) {
        root
          ..writeSource('assets/en.json', jsonEncode({'title': 'Shop'}))
          ..writeTranslations('en', {'title': 'Store'});

        expect(root.paths.readTranslations('en'), {'title': 'Store'});
      },
    );
  });
}

void _atlasLocations_should_readScreenDescriptionsFromPathsFile() {
  test(
    'AtlasLocations should read screen descriptions from paths file',
    () async {
      await TestAtlasRoot.runWith(
        project: FakeAtlasProject(pathsOverride: _pathsWithFiles),
        (root) {
          root.writeSource(
            'docs/screens.json',
            jsonEncode({
              'Home': {'en': 'The home screen', 'uk': 'Головний екран'},
            }),
          );

          final descriptions = root.paths.readScreenDescriptions();

          expect(descriptions, {
            'Home': {'en': 'The home screen', 'uk': 'Головний екран'},
          });
        },
      );
    },
  );
}

void _atlasLocations_should_rejectMissingScreenDescriptionsFile() {
  test(
    'AtlasLocations should reject missing screen descriptions file',
    () async {
      await TestAtlasRoot.runWith(
        project: FakeAtlasProject(pathsOverride: _pathsWithFiles),
        (root) {
          expect(
            root.paths.readScreenDescriptions,
            throwsA(isA<AtlasException>()),
          );
        },
      );
    },
  );
}
