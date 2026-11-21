import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/run_atlas.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_shot_storage.dart';
import 'test_utils/hash_shot_encoder.dart';
import 'test_utils/test_atlas_root.dart';

const _stageShot =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _endShot =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
const _tapStep = {
  'action': 'tap',
  'label': 'open',
  'finder': {'by': 'text', 'value': 'open'},
};
const _pubspecWithLimits = '''
name: sample
flutter_automation:
  defaultLocale: uk
  atlas:
    maxBundleBytes: 15728640
    maxBundleImages: 500
''';
const _pubspecWithSmallLimit = '''
name: sample
flutter_automation:
  defaultLocale: uk
  atlas:
    maxBundleBytes: 10
    maxBundleImages: 500
''';
const _pubspecWithOneImage = '''
name: sample
flutter_automation:
  defaultLocale: uk
  atlas:
    maxBundleBytes: 15728640
    maxBundleImages: 1
''';
const _shotsOfTwoSheets = 17;
const _pubspecWithoutLimits = '''
name: sample
flutter_automation:
  defaultLocale: uk
''';

void main() {
  group('AtlasRun Page Tests', () {
    _atlasRun_should_renderThePageAndHandStoreToProjectReports();
    _atlasRun_should_showSourceLabelOnTheRenderedPage();
    _atlasRun_should_renderTheEditionTheOptionNames();
    _atlasRun_should_bundleUrlsPageWithoutInlineImages();
    _atlasRun_should_bundleSheetsIntoShotsFilesWithinTheLimit();
    _atlasRun_should_stopSheetsBundleOverTheImageLimitWithItsCount();
    _atlasRun_should_failBundleOverTheLimitWithItsSize();
    _atlasRun_should_nameTheMissingLimitKeyOnBundle();
    _atlasRun_should_rejectBundleWithoutEditionOrShots();
    _atlasRun_should_rejectBundleOfUnknownEdition();
  });
}

void _atlasRun_should_renderThePageAndHandStoreToProjectReports() {
  test(
    'AtlasRun should render the page and hand store to project reports',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStore(root);

        await _runIn(root, ['render']);

        final store = root.project.reportedStores.single;

        expect(File(root.paths.pagePath).existsSync(), isTrue);
        expect(store.isDefaultStore, isTrue);
        expect(store.rootPath, root.paths.rootPath);
      });
    },
  );
}

void _atlasRun_should_showSourceLabelOnTheRenderedPage() {
  test('AtlasRun should show source label on the rendered page', () async {
    await TestAtlasRoot.run((root) async {
      _writeStore(root);

      await _runIn(root, ['render', '--source-label', 'build 7']);

      expect(
        File(root.paths.pagePath).readAsStringSync(),
        contains('"sourceLabel":"build 7"'),
      );
    });
  });
}

void _atlasRun_should_renderTheEditionTheOptionNames() {
  test('AtlasRun should render the edition the option names', () async {
    await TestAtlasRoot.run((root) async {
      _writeStore(root);

      await _runIn(root, ['render', '--edition', 'lite']);

      expect(
        File(root.paths.pagePath).readAsStringSync(),
        isNot(contains('"journalRecords"')),
      );
    });
  });
}

void _atlasRun_should_bundleUrlsPageWithoutInlineImages() {
  test('AtlasRun should bundle urls page without inline images', () async {
    await TestAtlasRoot.run((root) async {
      final storage = await startFakeAtlasShotStorage(root);

      _writeStore(root);

      await _runIn(root, [
        'bundle',
        '--edition',
        'full',
        '--shots',
        'urls',
        '--locale',
        'all',
      ]);

      final bundle = File(
        root.paths.resolveBundlePagePath('full'),
      ).readAsStringSync();

      expect(bundle, contains('"shotUrlTemplate":"${storage.urlTemplate}"'));
      expect(bundle, isNot(contains('data:image')));
      expect(storage.uploads, isEmpty);
    });
  });
}

void _atlasRun_should_bundleSheetsIntoShotsFilesWithinTheLimit() {
  test(
    'AtlasRun should bundle sheets into shots files within the limit',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStore(root);

        await _runIn(root, [
          'bundle',
          '--edition',
          'full',
          '--shots',
          'sheets',
          '--locale',
          'all',
        ]);

        final pagePath = root.paths.resolveBundlePagePath('full');
        final page = File(pagePath).readAsStringSync();
        final sheetFiles = Directory(
          root.paths.resolveBundleShotsPath(pagePath),
        ).listSync();

        expect(sheetFiles, hasLength(1));
        expect(page, contains('"shotSheets":["shots/'));
        expect(page, isNot(contains('data:image')));
      });
    },
  );
}

void _atlasRun_should_stopSheetsBundleOverTheImageLimitWithItsCount() {
  test(
    'AtlasRun should stop sheets bundle over the image limit with its count',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStore(
          root,
          pubspec: _pubspecWithOneImage,
          stageCount: _shotsOfTwoSheets,
        );

        await expectLater(
          _runIn(root, ['bundle', '--edition', 'full', '--shots', 'sheets']),
          throwsA(
            isA<AtlasException>().having(
              (error) => error.message,
              'message',
              contains('holds 2 images, over the 1 image limit'),
            ),
          ),
        );
      });
    },
  );
}

void _atlasRun_should_failBundleOverTheLimitWithItsSize() {
  test('AtlasRun should fail bundle over the limit with its size', () async {
    await TestAtlasRoot.run((root) async {
      _writeStore(root, pubspec: _pubspecWithSmallLimit);

      final error = await _runIn(root, [
        'bundle',
        '--edition',
        'full',
        '--shots',
        'files',
      ]).then<Object?>((_) => null, onError: (Object error) => error);

      final size = File(root.paths.resolveBundlePagePath('full')).lengthSync();

      expect(size, greaterThan(10));
      expect(
        error,
        isA<AtlasException>().having(
          (error) => error.message,
          'message',
          contains('takes $size bytes, over the 10 byte limit'),
        ),
      );
    });
  });
}

void _atlasRun_should_nameTheMissingLimitKeyOnBundle() {
  test('AtlasRun should name the missing limit key on bundle', () async {
    await TestAtlasRoot.run((root) async {
      _writeStore(root, pubspec: _pubspecWithoutLimits);

      await expectLater(
        _runIn(root, ['bundle', '--edition', 'full', '--shots', 'files']),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('flutter_automation: atlas: maxBundleBytes:'),
          ),
        ),
      );
    });
  });
}

void _atlasRun_should_rejectBundleWithoutEditionOrShots() {
  test('AtlasRun should reject bundle without edition or shots', () async {
    await TestAtlasRoot.run((root) async {
      _writeStore(root);

      for (final args in [
        ['bundle', '--shots', 'files'],
        ['bundle', '--edition', 'full'],
        ['bundle', '--edition', 'full', '--shots', 'unknown-source'],
      ]) {
        await expectLater(
          _runIn(root, args),
          throwsA(
            isA<AtlasException>().having(
              (error) => error.message,
              'message',
              startsWith('usage: atlas'),
            ),
          ),
        );
      }
    });
  });
}

void _atlasRun_should_rejectBundleOfUnknownEdition() {
  test('AtlasRun should reject bundle of unknown edition', () async {
    await TestAtlasRoot.run((root) async {
      _writeStore(root);

      await expectLater(
        _runIn(root, ['bundle', '--edition', 'gold', '--shots', 'files']),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('full, lite'),
          ),
        ),
      );
    });
  });
}

Future<void> _runIn(TestAtlasRoot root, List<String> args) {
  return AtlasRun(
    args,
    root.project,
    rootPath: root.directory.path,
    shotEncoder: const HashShotEncoder(),
  ).run();
}

void _writeStore(
  TestAtlasRoot root, {
  String pubspec = _pubspecWithLimits,
  int stageCount = 1,
}) {
  final stageShots = [
    _stageShot,
    for (int index = 1; index < stageCount; index++)
      index.toRadixString(16).padLeft(_stageShot.length, '0'),
  ];

  for (final shot in stageShots) {
    root.writeShot(shot, [1, 2, 3]);
  }

  root
    ..writeSource('pubspec.yaml', pubspec)
    ..writePublishedVariants({
      'catalog_flow': ['openNewItem'],
    })
    ..writeShot(_stageShot, [1, 2, 3])
    ..writeShot(_endShot, [4, 5, 6])
    ..writeFlow('catalog_flow', {
      'title': {'en': 'Browse items', 'uk': 'Переглянути товари'},
      'variants': {
        'openNewItem': {
          'items': [_tapStep],
        },
      },
    });

  AtlasSnapshotStore(root.paths).write(
    createAtlasSnapshot(
      flow: 'catalog_flow',
      variant: 'openNewItem',
      stages: [
        for (final shot in stageShots)
          AtlasStage(
            label: 'open',
            action: 'tap',
            journal: const [],
            ok: true,
            target: null,
            block: null,
            targetRect: null,
            screen: null,
            designScreen: null,
            shot: shot,
            error: null,
          ),
      ],
      end: const AtlasEnd(screen: null, designScreen: null, shot: _endShot),
    ),
  );
}
