import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_runner/flutter_automation_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_declarations_store.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_page_part.dart';
import 'package:flutter_automation_atlas/src/atlas_page_renderer.dart';
import 'package:flutter_automation_atlas/src/atlas_shot.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_encoder.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_publisher.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_source.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_table.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/hash_shot_encoder.dart';
import 'test_utils/test_atlas_root.dart';

const _dataPattern =
    r'<script type="application/json" id="atlas-data">(.*?)</script>';
const _shotsPattern =
    r'<script type="application/json" id="atlas-shots">(.*?)</script>';
const _metaPattern =
    r'<script type="application/json" id="atlas-meta">(.*?)</script>';
const _loginScreen = 'login-route';
const _itemsScreen = 'items-route';
const _detailsScreen = 'details-route';
const _loginDesign = 'login/design';
const _detailsDesign = 'details/design';
const _loginDesignLink = 'https://design.example/login';
const _detailsDesignLink = 'https://design.example/details';
const _stageShot = '0123456789ab';
const _endShot = 'ba9876543210';
const _sourceLabel = '1.2.0 (test)';
const _storedShot = 'cccccccccccc';
const _strandedShot = 'eeeeeeeeeeee';
const _referencedDeclarations = '333333333333';
const _strandedDeclarations = '444444444444';
const _shotBytes = [1, 2, 3, 4];
const _ukLocale = 'uk';
const _enLocale = 'en';
const _shotDataUriPrefix = 'data:image/webp;base64,';
const _renderedFlowCount = 2;
const _renderedVariantCount = 3;
const _renderedShotCount = 2;
const _publishedVariants = {
  'catalog_flow': ['openExistingItem', 'openNewItem', 'uncaptured'],
  'cart_flow': ['cartEmptied'],
};
const _flowTitle = {'en': 'Browse items', 'uk': 'Переглянути товари'};
const _targetRect = {'left': 0.05, 'top': 0.4, 'right': 0.95, 'bottom': 0.55};
const _tabRecord = {
  'kind': 'analytics',
  'target': 'sink',
  'name': 'tab_tap',
  'parameters': {'screen_name': _loginScreen},
};
const _itemsViewRecord = {
  'kind': 'analytics',
  'target': 'sink',
  'name': 'screen_opened',
  'parameters': {'screen_name': _itemsScreen},
};
const _reviewTapRecord = {
  'kind': 'analytics',
  'target': 'sink',
  'name': 'review_tap',
  'parameters': {'screen_name': _itemsScreen},
};
const _detailsViewRecord = {
  'kind': 'analytics',
  'target': 'sink',
  'name': 'screen_opened',
  'parameters': {'screen_name': _detailsScreen},
};
const _requestRecord = {
  'kind': 'request',
  'method': 'GET',
  'path': '/items/42',
  'status': 200,
};
final _secondRequestKind = fakeAtlasJournalSchema.requestKinds.last;
final _secondRequestRecord = {
  'kind': _secondRequestKind,
  'method': 'POST',
  'path': '/items/42/reviews',
  'status': 200,
};
const _stateRecord = {'kind': 'state', 'owner': 'ItemsOwner', 'created': true};
const _tapLabel = 'browse items';
const _tapTitle = {'en': 'Browse the items', 'uk': 'Переглянути товари'};
const _tapStep = {
  'action': 'tap',
  'label': _tapLabel,
  'title': _tapTitle,
  'finder': {'by': 'valueKey', 'value': 'bottom_bar.button.primary'},
};
const _probeSeriesStep = {
  'action': 'probeSeries',
  'label': 'read the cart list',
  'durationMs': 1000,
  'probes': [
    {
      'name': 'list',
      'finder': {'by': 'valueKey', 'value': 'cart.list'},
    },
  ],
};
const _scrollLabel = 'items list';
const _scrollTitle = {'en': 'Scroll the items', 'uk': 'Прогорнути товари'};
const _scrollDy = -300.0;
const _scrollStep = {
  'action': 'scroll',
  'label': _scrollLabel,
  'title': _scrollTitle,
  'dy': _scrollDy,
  'finder': {'by': 'valueKey', 'value': 'items.list'},
};
const _loginDescription = {
  'uk': 'Вхід через пошту.',
  'en': 'Signs in with an email.',
};
const _detailsDescription = {
  'uk': 'Деталі товару.',
  'en': 'The details of an item.',
};
const _pushEntry = {
  'title': {'en': 'From a push', 'uk': 'З пуша'},
  'launchedBy': 'push',
};
const _itemsTitleValue = 'Товари без повтору';
const _ukTranslations = {
  'itemsTitle': _itemsTitleValue,
  'detailsTitle': 'Деталі',
};
const _enTranslations = {'itemsTitle': 'Items', 'detailsTitle': 'Details'};
const _stageTranslationKeys = {
  'itemsTitle': 'hash-items',
  'detailsTitle': 'hash-details',
};
const _scenario = {'auth': 'signedInOnLaunch'};
const _localeKeyFinder = {'by': 'localeKey', 'value': 'itemsTitle'};
const _requestPath = '/items/42';
const _templatePrefix = '<html><script id="atlas-data">';
const _fullPubspec = '''
name: sample
flutter_automation:
  defaultLocale: uk
  atlas:
    maxBundleBytes: 15728640
    maxBundleImages: 500
''';
const _liteWithDesignPubspec = '''
name: sample
flutter_automation:
  defaultLocale: uk
  atlas:
    maxBundleBytes: 15728640
    maxBundleImages: 500
    editions:
      lite: [flowStages, screenDescriptions, designLinks]
''';
const _germanPubspec = '''
name: sample
flutter_automation:
  defaultLocale: de
  atlas:
    maxBundleBytes: 15728640
    maxBundleImages: 500
''';
const _deFrFlowTitle = {'de': 'Artikel ansehen', 'fr': 'Voir les articles'};
const _deFrDescription = {
  'de': 'Meldet sich per E-Mail an.',
  'fr': 'Se connecte par e-mail.',
};
final _requestsTable = AtlasTable(
  id: 'requests',
  title: {'en': 'Requests', 'uk': 'Запити'},
  columns: [
    AtlasTableColumn(key: 'path', title: {'en': 'Path', 'uk': 'Шлях'}),
  ],
  rows: [
    {
      'path': _requestPath,
      'status': 'onFrames',
      'stages': {
        'catalog_flow/openNewItem': [0],
      },
    },
  ],
  journalKind: 'request',
);
final _localeKeysTable = AtlasTable(
  id: AtlasTable.localeKeysId,
  title: {'en': 'Keys', 'uk': 'Ключі'},
  columns: [
    AtlasTableColumn(key: 'key', title: {'en': 'Key', 'uk': 'Ключ'}),
  ],
  rows: [
    {'key': 'itemsTitle', 'status': 'onFrames', 'usages': <Object?>[]},
  ],
);

final _builtAt = DateTime.utc(2026, 11, 19, 9, 30);

void main() {
  group('AtlasPageRenderer Tests', () {
    _atlasPageRenderer_should_renderFromThePackageTemplate();
    _atlasPageRenderer_should_assemblePageData();
    _atlasPageRenderer_should_splitStageJournals();
    _atlasPageRenderer_should_addStepTitleAndScrollToMatchingStages();
    _atlasPageRenderer_should_omitStepTitleOnLabelMismatch();
    _atlasPageRenderer_should_omitStepTitleOnActionMismatch();
    _atlasPageRenderer_should_escapeClosingTags();
    _atlasPageRenderer_should_deleteUnreferencedShots();
    _atlasPageRenderer_should_deleteUnreferencedDeclarations();
    _atlasPageRenderer_should_reportAShotTheDirectoryLacks();
    _atlasPageRenderer_should_keepShotsAndWriteNoPageOnBuild();
    _atlasPageRenderer_should_rejectTemplateWithoutPlaceholder();
    _atlasPageRenderer_should_keepUnpublishedSnapshotStored();
    _atlasPageRenderer_should_showDefaultLocaleAndKeepShotsOfEveryLocale();
    _atlasPageRenderer_should_referenceDefaultStagesFromFallback();
    _atlasPageRenderer_should_groupFlowsByAreaAndGroup();
    _atlasPageRenderer_should_rejectGroupOutsideGroupOrder();
    _atlasPageRenderer_should_listScenarioFlowsInDeclarationOrder();
    _atlasPageRenderer_should_reportSnapshotOfUnlistedVariant();
    _atlasPageRenderer_should_carryTextOfEveryPageLocale();
    _atlasPageRenderer_should_rejectTableIdOfPageData();
    _atlasPageRenderer_should_describeShownDesignScreens();
    _atlasPageRenderer_should_rejectShownScreenWithoutDescription();
    _atlasPageRenderer_should_carryVariantEntryAndStateOf();
    _atlasPageRenderer_should_writeEveryLocaleOnce();
    _atlasPageRenderer_should_nameStageKeysInOrder();
    _atlasPageRenderer_should_indexStageSearchTexts();
    _atlasPageRenderer_should_showBothTablesOfAFullProject();
    _atlasPageRenderer_should_carryPageMeta();
    _atlasPageRenderer_should_showSourceLabelAndBuildDateInBundleFooter();
    _atlasPageRenderer_should_leaveBuildDateOutOfRepositoryPage();
  });
  group('AtlasPageRenderer Edition Tests', () {
    _atlasPageRenderer_should_keepFullDataOfTheProject();
    _atlasPageRenderer_should_leaveFullOnlyDataOutOfLite();
    _atlasPageRenderer_should_leaveFullOnlyDataOutOfLiteBundle();
    _atlasPageRenderer_should_showDesignLinksWhenLiteListsThePart();
    _atlasPageRenderer_should_hideSectionsOfPartsOutsideTheEdition();
  });
  group('AtlasPageRenderer Bundle Tests', () {
    _atlasPageRenderer_should_inlineEveryShownShotInBundle();
    _atlasPageRenderer_should_leaveMissingShotOutOfBundle();
    _atlasPageRenderer_should_keepShotSheetsOffRenderedPage();
    _atlasPageRenderer_should_bundleOnlyTheSeriesOfItsLocale();
    _atlasPageRenderer_should_bundleEveryLocaleInOneFile();
    _atlasPageRenderer_should_nameBundleByEdition();
    _atlasPageRenderer_should_rejectBundleOfLocaleOffPage();
    _atlasPageRenderer_should_linkShotsOfAUrlsBundle();
    _atlasPageRenderer_should_stopBundleWhenPublishFails();
    _atlasPageRenderer_should_stopBundleWhenPublisherLeavesAShotUnlinked();
    _atlasPageRenderer_should_rejectUrlsBundleWithoutPublisher();
    _atlasPageRenderer_should_copyShotsBesideAFilesBundle();
    _atlasPageRenderer_should_writeSheetFilesBesideASheetsBundle();
    _atlasPageRenderer_should_bundleBothLocalesOfASheetsBundleInOnePage();
    _atlasPageRenderer_should_keepOnlyItsSheetsInTheShotsFolder();
    _atlasPageRenderer_should_keepShotsFoldersOfEditionsApart();
    _atlasBundleRendering_should_describeEachLimitItPasses();
  });
}

void _atlasPageRenderer_should_renderFromThePackageTemplate() {
  test('AtlasPageRenderer should render from the package template', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);

      final rendering = await AtlasPageRenderer(root.paths).render();

      final page = File(root.paths.pagePath).readAsStringSync();

      expect(rendering.page, page);
      expect(page, startsWith('<!doctype html>'));
      expect(page, isNot(contains('/*ATLAS_')));
      expect(_readData(page), contains('flows'));
    });
  });
}

void _atlasPageRenderer_should_assemblePageData() {
  test('AtlasPageRenderer should assemble page data', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);

      final rendering = await AtlasPageRenderer(root.paths).render();

      final data = _readRenderedData(root);
      final flows = data['flows'] as List<Object?>;
      final catalogFlow = flows.last as Map<String, Object?>;
      final variants = catalogFlow['variants'] as List<Object?>;
      final newItem = variants.firstOrNull as Map<String, Object?>;
      final stage = (newItem['stages'] as List<Object?>).single as Map;
      final end = newItem['end'] as Map<String, Object?>;

      expect(flows.map((flow) => (flow as Map)['name']), [
        'cart_flow',
        'catalog_flow',
      ]);
      expect(catalogFlow['title'], _flowTitle);
      expect(variants.map((variant) => (variant as Map)['name']), [
        'openNewItem',
        'openExistingItem',
      ]);
      expect(variants.map((variant) => (variant as Map)['isDefault']), [
        false,
        true,
      ]);
      expect(newItem['proves'], {'en': 'A new item', 'uk': 'Новий товар'});
      expect(newItem['device'], testAtlasDevice);
      expect(newItem['scenario'], _scenario);
      expect(stage['shot'], _stageShot);
      expect(stage['designUrl'], _loginDesignLink);
      expect(end['designUrl'], _detailsDesignLink);
      expect(data['totals'], {
        'flows': _renderedFlowCount,
        'variants': _renderedVariantCount,
        'stages': _renderedVariantCount,
        'shots': _renderedShotCount,
        'shotsBytes': _shotBytes.length * _renderedShotCount,
      });
      expect(rendering.totals, data['totals']);
    });
  });
}

void _atlasPageRenderer_should_splitStageJournals() {
  test('AtlasPageRenderer should split stage journals', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      AtlasSnapshotStore(root.paths).write(_createTwoStageSnapshot());

      await AtlasPageRenderer(root.paths).render();

      final stages = _readNewItemStages(root);
      final firstStage = stages.first;
      final lastStage = stages.last;
      final end = _readCatalogFlowVariants(root).first['end'];

      expect(stages.map((stage) => stage.containsKey('journal')), [
        false,
        false,
      ]);
      expect(firstStage['targetRect'], _targetRect);
      expect(firstStage['afterAction'], [_tabRecord]);
      expect(firstStage['onScreenOpen'], isEmpty);
      expect(lastStage['afterAction'], [_reviewTapRecord]);
      expect(lastStage['onScreenOpen'], [_itemsViewRecord]);
      expect(end, {
        'screen': _detailsScreen,
        'designScreen': _detailsDesign,
        'shot': _endShot,
        'designUrl': _detailsDesignLink,
        'onScreenOpen': [_detailsViewRecord],
        'search': {
          'frame': {
            'screen': '$_detailsScreen · $_detailsDesign',
            'analytics': ['screen_opened'],
          },
        },
      });
    });
  });
}

void _atlasPageRenderer_should_addStepTitleAndScrollToMatchingStages() {
  test(
    'AtlasPageRenderer should add step title and scroll to matching stages',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeCatalogue(root);
        AtlasSnapshotStore(root.paths).write(
          _createNewItemSnapshot([
            _createStage(_tapLabel, 'tap'),
            _createStage(_scrollLabel, 'scroll'),
          ]),
        );

        await AtlasPageRenderer(root.paths).render();

        final stages = _readNewItemStages(root);

        expect(stages.map((stage) => stage['title']), [
          _tapTitle,
          _scrollTitle,
        ]);
        expect(stages.map((stage) => stage.containsKey('scroll')), [
          false,
          true,
        ]);
        expect(stages.last['scroll'], {'dx': 0, 'dy': _scrollDy});
      });
    },
  );
}

void _atlasPageRenderer_should_omitStepTitleOnLabelMismatch() {
  test('AtlasPageRenderer should omit step title on label mismatch', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      AtlasSnapshotStore(root.paths).write(
        _createNewItemSnapshot([
          _createStage('browse', 'tap'),
          _createStage('items', 'scroll'),
        ]),
      );

      await AtlasPageRenderer(root.paths).render();

      expect(_readNewItemStages(root).map(_findStepKeys), [isEmpty, isEmpty]);
    });
  });
}

void _atlasPageRenderer_should_omitStepTitleOnActionMismatch() {
  test('AtlasPageRenderer should omit step title on action mismatch', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      AtlasSnapshotStore(root.paths).write(
        _createNewItemSnapshot([
          _createStage(_tapLabel, 'enterText'),
          _createStage(_scrollLabel, 'tap'),
        ]),
      );

      await AtlasPageRenderer(root.paths).render();

      expect(_readNewItemStages(root).map(_findStepKeys), [isEmpty, isEmpty]);
    });
  });
}

void _atlasPageRenderer_should_escapeClosingTags() {
  test('AtlasPageRenderer should escape closing tags', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root, label: 'tap </script> away');

      await AtlasPageRenderer(root.paths).render();

      final page = File(root.paths.pagePath).readAsStringSync();

      expect(page, contains(r'tap <\/script> away'));
      expect(page, isNot(contains('tap </script> away')));
      expect(
        _readRenderedData(root)['flows'].toString(),
        contains('</script>'),
      );
    });
  });
}

void _atlasPageRenderer_should_deleteUnreferencedShots() {
  test('AtlasPageRenderer should delete unreferenced shots', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      root.writeShot('ffffffffffff', _shotBytes);

      final rendering = await AtlasPageRenderer(root.paths).render();

      expect(rendering.deletedShots, ['ffffffffffff.png']);
      expect(
        File(root.paths.resolveShotPath('ffffffffffff')).existsSync(),
        isFalse,
      );
      expect(File(root.paths.resolveShotPath(_stageShot)).existsSync(), isTrue);
    });
  });
}

void _atlasPageRenderer_should_deleteUnreferencedDeclarations() {
  test('AtlasPageRenderer should delete unreferenced declarations', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      AtlasSnapshotStore(root.paths).write(
        _createSnapshot(
          'cart_flow',
          'cartEmptied',
          'browse',
          manifest: const {'lib/cart.dart': _referencedDeclarations},
        ),
      );

      AtlasDeclarationsStore(root.paths)
        ..maybeWrite(sourceHash: _referencedDeclarations, source: '')
        ..maybeWrite(sourceHash: _strandedDeclarations, source: '');

      final rendering = await AtlasPageRenderer(root.paths).render();

      expect(rendering.deletedDeclarations, ['$_strandedDeclarations.json']);
      expect(
        File(
          root.paths.resolveDeclarationsPath(_referencedDeclarations),
        ).existsSync(),
        isTrue,
      );
    });
  });
}

void _atlasPageRenderer_should_reportAShotTheDirectoryLacks() {
  test('AtlasPageRenderer should report a shot the directory lacks', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      File(root.paths.resolveShotPath(_endShot)).deleteSync();

      final rendering = await AtlasPageRenderer(root.paths).build();

      expect(rendering.missingShots, [_endShot]);
    });
  });
}

void _atlasPageRenderer_should_keepShotsAndWriteNoPageOnBuild() {
  test(
    'AtlasPageRenderer should keep shots and write no page on build',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeCatalogue(root);
        root.writeShot(_strandedShot, _shotBytes);

        final shots = _readShotFiles(root);

        final rendering = await AtlasPageRenderer(root.paths).build();

        expect(rendering.page, contains('id="atlas-data"'));
        expect(rendering.deletedShots, isEmpty);
        expect(File(root.paths.pagePath).existsSync(), isFalse);
        expect(_readShotFiles(root), shots);
        expect(shots.keys, contains('$_strandedShot.png'));
      });
    },
  );
}

void _atlasPageRenderer_should_rejectTemplateWithoutPlaceholder() {
  test(
    'AtlasPageRenderer should reject template without placeholder',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeCatalogue(root);

        final renderer = AtlasPageRenderer(
          root.paths,
          template: '$_templatePrefix/*ATLAS_DATA*/</script></html>',
        );

        await expectLater(
          renderer.render(),
          throwsA(
            isA<AtlasException>().having(
              (error) => error.message,
              'message',
              contains('/*ATLAS_SHOTS*/'),
            ),
          ),
        );
      });
    },
  );
}

void _atlasPageRenderer_should_keepUnpublishedSnapshotStored() {
  test('AtlasPageRenderer should keep unpublished snapshot stored', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);

      root
        ..writePublishedVariants({
          'catalog_flow': ['openNewItem', 'openExistingItem'],
        })
        ..writeShot(_storedShot, _shotBytes);

      AtlasSnapshotStore(root.paths).write(
        _createSnapshot(
          'cart_flow',
          'cartEmptied',
          'browse',
          stageShot: _storedShot,
        ),
      );

      final rendering = await AtlasPageRenderer(root.paths).render();

      final flows = _readRenderedData(root)['flows'] as List<Object?>;

      expect(flows.map((flow) => (flow as Map)['name']), ['catalog_flow']);
      expect(rendering.unlistedSnapshots, isEmpty);
      expect(rendering.deletedShots, isEmpty);
      expect(
        File(root.paths.resolveShotPath(_storedShot)).existsSync(),
        isTrue,
      );
    });
  });
}

void _atlasPageRenderer_should_showDefaultLocaleAndKeepShotsOfEveryLocale() {
  test('AtlasPageRenderer should show default locale and keep shots of every '
      'locale', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      _writeEnSnapshot(root);

      final rendering = await AtlasPageRenderer(root.paths).render();

      final existingItem = _readCatalogFlowVariants(root).last;
      final series = existingItem['series'] as Map<String, Object?>;
      final enSeries = series[_enLocale] as Map<String, Object?>;
      final enStages = enSeries['stages'] as List<Object?>;
      final ukStages = existingItem['stages'] as List<Object?>;

      expect(rendering.totals['variants'], _renderedVariantCount);
      expect(rendering.totals['shots'], _renderedShotCount + 1);
      expect(enSeries, isNot(contains('fallbackLocale')));
      expect((enStages.single as Map)['label'], 'english');
      expect((enStages.single as Map)['shot'], _storedShot);
      expect((ukStages.single as Map)['label'], 'browse');
      expect(rendering.deletedShots, isEmpty);
      expect(rendering.unlistedSnapshots, isEmpty);
    });
  });
}

void _atlasPageRenderer_should_referenceDefaultStagesFromFallback() {
  test(
    'AtlasPageRenderer should reference default stages from fallback',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeCatalogue(root);

        await AtlasPageRenderer(root.paths).render();

        final variants = (_readRenderedData(root)['flows'] as List<Object?>)
            .cast<Map<String, Object?>>()
            .expand((flow) => flow['variants'] as List<Object?>)
            .cast<Map<String, Object?>>();

        expect(variants, hasLength(_renderedVariantCount));
        expect(variants.map((variant) => variant['series']), [
          for (int index = 0; index < _renderedVariantCount; index++)
            {
              _enLocale: {'fallbackLocale': _ukLocale},
            },
        ]);
      });
    },
  );
}

void _atlasPageRenderer_should_groupFlowsByAreaAndGroup() {
  test('AtlasPageRenderer should group flows by area and group', () async {
    await TestAtlasRoot.runWith(
      project: FakeAtlasProject(groupOrder: _areaGroups),
      (root) async {
        _writeCatalogue(root);

        root
          ..writeFlowGroup('catalog_flow', _areaGroups.first.toJson())
          ..writeFlowGroup('cart_flow', _areaGroups.last.toJson());

        await AtlasPageRenderer(root.paths).render();

        expect(_readRenderedData(root)['areas'], [
          {
            'name': 'shop',
            'title': {'uk': 'Магазин', 'en': 'Shop'},
            'groups': [
              {
                'name': 'shop.catalog',
                'title': {'uk': 'Каталог', 'en': 'Catalog'},
                'flows': ['catalog_flow'],
              },
            ],
          },
          {
            'name': 'support',
            'title': {'uk': 'Підтримка', 'en': 'Support'},
            'groups': [
              {
                'name': 'support.help',
                'title': {'uk': 'Довідка', 'en': 'Help'},
                'flows': ['cart_flow'],
              },
            ],
          },
        ]);
      },
    );
  });
}

void _atlasPageRenderer_should_rejectGroupOutsideGroupOrder() {
  test('AtlasPageRenderer should reject group outside group order', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      root.writeFlowGroup('catalog_flow', {
        'name': 'unlisted.group',
        'title': _flowTitle,
      });

      await expectLater(
        AtlasPageRenderer(root.paths).render(),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            allOf(contains('unlisted.group'), contains('groupOrder')),
          ),
        ),
      );
    });
  });
}

void _atlasPageRenderer_should_listScenarioFlowsInDeclarationOrder() {
  test(
    'AtlasPageRenderer should list scenario flows in declaration order',
    () async {
      await TestAtlasRoot.runWith(
        project: FakeAtlasProject(groupOrder: _areaGroups),
        (root) async {
          _writeCatalogue(root);

          final group = _areaGroups.first.toJson();

          root
            ..writeFlowGroup('catalog_flow', group)
            ..writeFlowGroup('cart_flow', group);

          await AtlasPageRenderer(root.paths).render();

          final areas = _readRenderedData(root)['areas'] as List<Object?>;
          final groups = (areas.single as Map)['groups'] as List<Object?>;

          expect((groups.single as Map)['flows'], [
            'catalog_flow',
            'cart_flow',
          ]);
        },
      );
    },
  );
}

void _atlasPageRenderer_should_reportSnapshotOfUnlistedVariant() {
  test(
    'AtlasPageRenderer should report snapshot of unlisted variant',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeCatalogue(root);
        AtlasSnapshotStore(
          root.paths,
        ).write(_createSnapshot('catalog_flow', 'removedVariant', 'browse'));

        final rendering = await AtlasPageRenderer(root.paths).render();

        expect(rendering.unlistedSnapshots, ['catalog_flow removedVariant']);
      });
    },
  );
}

void _atlasPageRenderer_should_carryTextOfEveryPageLocale() {
  test('AtlasPageRenderer should carry text of every page locale', () async {
    await TestAtlasRoot.runWith(
      project: FakeAtlasProject(locales: const ['de', 'fr']),
      (root) async {
        root
          ..writeSource('pubspec.yaml', _germanPubspec)
          ..writePublishedVariants({
            'catalog_flow': ['openNewItem'],
          })
          ..writeShot(_stageShot, _shotBytes)
          ..writeShot(_endShot, _shotBytes)
          ..writeTranslations('de', const {})
          ..writeTranslations('fr', const {})
          ..writeFlow('catalog_flow', {
            'title': _deFrFlowTitle,
            'variants': {
              'openNewItem': {
                'title': _deFrFlowTitle,
                'proves': _deFrFlowTitle,
                'items': [
                  {..._tapStep, 'title': _deFrFlowTitle},
                ],
              },
            },
          });

        root.project.descriptions[_loginDesign] = _deFrDescription;
        root.project.descriptions[_detailsDesign] = _deFrDescription;

        AtlasSnapshotStore(root.paths).write(
          _createSnapshot(
            'catalog_flow',
            'openNewItem',
            _tapLabel,
            locale: 'de',
          ),
        );

        await AtlasPageRenderer(root.paths).render();

        final data = _readRenderedData(root);
        final flow = (data['flows'] as List<Object?>).single as Map;
        final stage = _readNewItemStages(root).single;

        expect(flow['title'], _deFrFlowTitle);
        expect(stage['title'], _deFrFlowTitle);
        expect(data['screenDescriptions'], {
          _loginDesign: _deFrDescription,
          _detailsDesign: _deFrDescription,
        });
        expect(
          ((stage['search'] as Map)['arrow'] as Map)['step'],
          contains('voir les articles'),
        );
      },
    );
  });
}

void _atlasPageRenderer_should_rejectTableIdOfPageData() {
  test('AtlasPageRenderer should reject table id of page data', () async {
    for (final id in ['flows', 'areas', 'locales', 'totals']) {
      await TestAtlasRoot.run((root) async {
        _writeCatalogue(root);
        root.project.tablesToReturn.add(
          AtlasTable(
            id: id,
            title: _flowTitle,
            columns: const [],
            rows: const [],
          ),
        );

        await expectLater(
          AtlasPageRenderer(root.paths).render(),
          throwsA(
            isA<AtlasException>().having(
              (error) => error.message,
              'message',
              allOf(contains(id), contains('names of the page data')),
            ),
          ),
        );
      });
    }
  });
}

void _atlasPageRenderer_should_describeShownDesignScreens() {
  test('AtlasPageRenderer should describe shown design screens', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);

      root.project.descriptions['unshown/design'] = _loginDescription;

      await AtlasPageRenderer(root.paths).render();

      expect(_readRenderedData(root)['screenDescriptions'], {
        _loginDesign: _loginDescription,
        _detailsDesign: _detailsDescription,
      });
    });
  });
}

void _atlasPageRenderer_should_rejectShownScreenWithoutDescription() {
  test(
    'AtlasPageRenderer should reject shown screen without description',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeCatalogue(root);
        root.project.descriptions.remove(_detailsDesign);

        await expectLater(
          AtlasPageRenderer(root.paths).render(),
          throwsA(
            isA<AtlasException>().having(
              (error) => error.message,
              'message',
              contains(_detailsDesign),
            ),
          ),
        );
      });
    },
  );
}

void _atlasPageRenderer_should_carryVariantEntryAndStateOf() {
  test('AtlasPageRenderer should carry variant entry and stateOf', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      root.writeFlow('catalog_flow', {
        'title': _flowTitle,
        'defaultVariant': 'openExistingItem',
        'variants': {
          'openNewItem': {
            'stateOf': 'openExistingItem',
            'items': [_tapStep],
          },
          'openExistingItem': {
            'entry': _pushEntry,
            'items': [_tapStep],
          },
          'uncaptured': {
            'items': [_tapStep],
          },
        },
      });

      await AtlasPageRenderer(root.paths).render();

      final variants = _readVariants(_readRenderedData(root), 'catalog_flow');

      expect(variants['openNewItem']?['stateOf'], 'openExistingItem');
      expect(variants['openNewItem']?.containsKey('entry'), isFalse);
      expect(variants['openExistingItem']?['entry'], _pushEntry);
      expect(variants['openExistingItem']?.containsKey('stateOf'), isFalse);
    });
  });
}

void _atlasPageRenderer_should_writeEveryLocaleOnce() {
  test('AtlasPageRenderer should write every locale once', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      AtlasSnapshotStore(root.paths).write(
        _createNewItemSnapshot([_createKeysStage(_stageTranslationKeys)]),
      );

      await AtlasPageRenderer(root.paths).render();

      final page = File(root.paths.pagePath).readAsStringSync();

      expect(_readRenderedData(root)['locales'], {
        _ukLocale: _ukTranslations,
        _enLocale: _enTranslations,
      });
      expect(_itemsTitleValue.allMatches(page), hasLength(1));
      expect(page, isNot(contains('hash-items')));
    });
  });
}

void _atlasPageRenderer_should_nameStageKeysInOrder() {
  test('AtlasPageRenderer should name stage keys in order', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      AtlasSnapshotStore(root.paths).write(
        _createNewItemSnapshot([_createKeysStage(_stageTranslationKeys)]),
      );

      await AtlasPageRenderer(root.paths).render();

      final stage = _readNewItemStages(root).single;

      expect(stage['keys'], [
        {'k': 'detailsTitle'},
        {'k': 'itemsTitle'},
      ]);
      expect(stage, isNot(contains('localeKeys')));
    });
  });
}

void _atlasPageRenderer_should_indexStageSearchTexts() {
  test('AtlasPageRenderer should index stage search texts', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      AtlasSnapshotStore(root.paths).write(
        _createNewItemSnapshot([
          _createStage(_tapLabel, 'tap').copyWithJournal([
            _tabRecord,
            _requestRecord,
            _secondRequestRecord,
            _stateRecord,
          ]),
        ]),
      );

      await AtlasPageRenderer(root.paths).render();

      final stage = _readNewItemStages(root).single;
      final end = _readCatalogFlowVariants(root).first['end'] as Map;

      expect(stage['search'], {
        'frame': {'screen': ''},
        'arrow': {
          'step': 'browse items · переглянути товари browse the items',
          'analytics': ['tab_tap'],
          'request': ['get /items/42 /items/{id}'],
          _secondRequestKind: ['post /items/42/reviews /items/{id}/reviews'],
        },
      });
      expect(end['search'], {
        'frame': {'screen': '$_detailsScreen · $_detailsDesign'},
      });
    });
  });
}

void _atlasPageRenderer_should_showBothTablesOfAFullProject() {
  test('AtlasPageRenderer should show both tables of a full project', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);

      await AtlasPageRenderer(root.paths).render();

      final data = _readRenderedData(root);
      final meta = _readMeta(File(root.paths.pagePath).readAsStringSync());
      final tables = meta['tables'] as List<Object?>;

      expect(data['requests'], _requestsTable.rows);
      expect(data[AtlasTable.localeKeysId], _localeKeysTable.rows);
      expect(tables.map((table) => (table as Map)['id']), [
        'requests',
        AtlasTable.localeKeysId,
      ]);
      expect((tables.first as Map)['journalKind'], 'request');
      expect(((tables.first as Map)['columns'] as List<Object?>).single, {
        'key': 'path',
        'title': {'en': 'Path', 'uk': 'Шлях'},
      });
    });
  });
}

void _atlasPageRenderer_should_carryPageMeta() {
  test('AtlasPageRenderer should carry page meta', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);

      await AtlasPageRenderer(root.paths, sourceLabel: 'v1 test').render();

      final meta = _readMeta(File(root.paths.pagePath).readAsStringSync());

      expect(meta['projectName'], 'Sample');
      expect(meta['sourceLabel'], 'v1 test');
      expect(meta['locales'], [_ukLocale, _enLocale]);
      expect(meta['parts'], AtlasPagePart.values.map((part) => part.name));
      expect(meta['journal'], {
        'analytics': 'analytics',
        'state': 'state',
        'requests': fakeAtlasJournalSchema.requestKinds.toList(),
        'stateKey': 'owner',
        'createdKey': 'created',
        'parametersKey': 'parameters',
      });
    });
  });
}

void _atlasPageRenderer_should_showSourceLabelAndBuildDateInBundleFooter() {
  test('AtlasPageRenderer should show source label and build date in bundle '
      'footer', () async {
    final store = await Directory.systemTemp.createTemp('atlas-store-');

    addTearDown(() {
      if (store.existsSync()) {
        store.deleteSync(recursive: true);
      }
    });

    await TestAtlasRoot.runWith(store: store.path, (root) async {
      _writeCatalogue(root);

      final rendering =
          await AtlasPageRenderer(
            root.paths,
            shotEncoder: const HashShotEncoder(),
            sourceLabel: _sourceLabel,
            clock: () => _builtAt,
          ).renderBundle(
            edition: _fullEdition(root),
            source: AtlasShotSource.files,
          );

      final page = File(rendering.path).readAsStringSync();
      final meta = _readMeta(page);

      expect(meta['sourceLabel'], _sourceLabel);
      expect(meta['builtAt'], _builtAt.toIso8601String());
      expect(meta.containsKey('footer'), isFalse);
      expect(page, isNot(contains('Generated by')));
      expect(page, isNot(contains(p.relative(store.path))));
    });
  });
}

void _atlasPageRenderer_should_leaveBuildDateOutOfRepositoryPage() {
  test(
    'AtlasPageRenderer should leave build date out of repository page',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeCatalogue(root);

        await AtlasPageRenderer(root.paths, clock: () => _builtAt).render();

        final meta = _readMeta(File(root.paths.pagePath).readAsStringSync());

        expect(meta.containsKey('builtAt'), isFalse);
      });
    },
  );
}

void _atlasPageRenderer_should_keepFullDataOfTheProject() {
  test('AtlasPageRenderer should keep full data of the project', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      AtlasSnapshotStore(root.paths).write(_createTwoStageSnapshot());

      await AtlasPageRenderer(root.paths).render();

      final data = _readRenderedData(root);
      final stage = _readNewItemStages(root).first;

      expect(
        data.keys,
        containsAll([
          'flows',
          'areas',
          'screenDescriptions',
          'locales',
          'requests',
          AtlasTable.localeKeysId,
          'totals',
        ]),
      );
      expect(stage['afterAction'], [_tabRecord]);
      expect(stage['target'], {
        'by': 'valueKey',
        'value': 'main_nav.tab.items',
      });
      expect(
        _readCatalogFlowVariants(root).first.containsKey('scenario'),
        isTrue,
      );
    });
  });
}

void _atlasPageRenderer_should_leaveFullOnlyDataOutOfLite() {
  test('AtlasPageRenderer should leave full only data out of lite', () async {
    await TestAtlasRoot.run((root) async {
      _writeFullOnlyCatalogue(root);

      final rendering = await AtlasPageRenderer(root.paths).build(
        edition: root.paths.pageConfig.resolveEdition(AtlasEdition.liteName),
      );

      final page = rendering.page;
      final data = _readData(page);

      _expectNoFullOnlyText(page);
      expect(page, contains('Signs in with an email.'));
      expect(data.containsKey('requests'), isFalse);
      expect(data.containsKey('locales'), isFalse);
      expect(data.containsKey(AtlasTable.localeKeysId), isFalse);
      expect(_readMeta(page)['tables'], isEmpty);
    });
  });
}

void _atlasPageRenderer_should_leaveFullOnlyDataOutOfLiteBundle() {
  test(
    'AtlasPageRenderer should leave full only data out of lite bundle',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeFullOnlyCatalogue(root);

        final rendering = await _createRenderer(root).renderBundle(
          edition: root.paths.pageConfig.resolveEdition(AtlasEdition.liteName),
          source: AtlasShotSource.files,
        );

        final page = File(rendering.path).readAsStringSync();
        final decoded = jsonEncode(_readBundleData(page));

        _expectNoFullOnlyText(decoded);
        _expectNoFullOnlyText(page);
        expect(decoded, contains('Signs in with an email.'));
      });
    },
  );
}

void _atlasPageRenderer_should_showDesignLinksWhenLiteListsThePart() {
  test(
    'AtlasPageRenderer should show design links when lite lists the part',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeFullOnlyCatalogue(root);
        root.writeSource('pubspec.yaml', _liteWithDesignPubspec);

        final rendering = await AtlasPageRenderer(root.paths).build(
          edition: root.paths.pageConfig.resolveEdition(AtlasEdition.liteName),
        );

        final data = _readData(rendering.page);

        expect(rendering.page, contains(_loginDesignLink));
        expect(
          _readMeta(rendering.page)['parts'],
          contains(AtlasPagePart.designLinks.name),
        );
        expect(
          data['flows'].toString(),
          contains('designUrl: $_loginDesignLink'),
        );
        expect(rendering.page, isNot(contains(_requestPath)));
        expect(rendering.page, isNot(contains('itemsTitle')));
      });
    },
  );
}

void _atlasPageRenderer_should_hideSectionsOfPartsOutsideTheEdition() {
  test(
    'AtlasPageRenderer should hide sections of parts outside the edition',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeFullOnlyCatalogue(root);

        final rendering = await AtlasPageRenderer(root.paths).build(
          edition: root.paths.pageConfig.resolveEdition(AtlasEdition.liteName),
        );

        final parts = _readMeta(rendering.page)['parts'] as List<Object?>;

        expect(parts, [
          AtlasPagePart.flowStages.name,
          AtlasPagePart.screenDescriptions.name,
        ]);
        expect(_readFirstStage(rendering.page)['afterAction'], isEmpty);
      });
    },
  );
}

void _atlasPageRenderer_should_inlineEveryShownShotInBundle() {
  test('AtlasPageRenderer should inline every shown shot in bundle', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      root.writeShot(_strandedShot, _shotBytes);

      final rendering = await _createRenderer(root).renderBundle(
        edition: _fullEdition(root),
        source: AtlasShotSource.inline,
        locale: _ukLocale,
      );

      final page = File(rendering.path).readAsStringSync();

      expect(_readShots(page), {
        'shotSheets': [
          _hashSheetDataUri([_stageShot, _endShot]),
        ],
        'shotCells': {
          _stageShot: [0, 0, 0, 1, 1],
          _endShot: [0, 1, 0, 1, 1],
        },
      });
      expect(rendering.bytes, File(rendering.path).lengthSync());
      expect(rendering.images, 1);
      expect(File(root.paths.pagePath).existsSync(), isFalse);
      expect(_readShotFiles(root).keys, contains('$_strandedShot.png'));
    });
  });
}

void _atlasPageRenderer_should_leaveMissingShotOutOfBundle() {
  test('AtlasPageRenderer should leave missing shot out of bundle', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      File(root.paths.resolveShotPath(_endShot)).deleteSync();

      final rendering = await _createRenderer(root).renderBundle(
        edition: _fullEdition(root),
        source: AtlasShotSource.inline,
        locale: _ukLocale,
      );

      expect(_readShots(File(rendering.path).readAsStringSync()), {
        'shotSheets': [
          _hashSheetDataUri([_stageShot]),
        ],
        'shotCells': {
          _stageShot: [0, 0, 0, 1, 1],
        },
      });
    });
  });
}

void _atlasPageRenderer_should_keepShotSheetsOffRenderedPage() {
  test('AtlasPageRenderer should keep shot sheets off rendered page', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);

      final renderer = _createRenderer(root);
      final page = (await renderer.build()).page;

      await renderer.renderBundle(
        edition: _fullEdition(root),
        source: AtlasShotSource.inline,
        locale: _ukLocale,
      );
      await renderer.render();

      expect(_readShots(File(root.paths.pagePath).readAsStringSync()), {
        'shotSheets': <Object?>[],
        'shotCells': <String, Object?>{},
      });
      expect(File(root.paths.pagePath).readAsStringSync(), page);
    });
  });
}

void _atlasPageRenderer_should_bundleOnlyTheSeriesOfItsLocale() {
  test(
    'AtlasPageRenderer should bundle only the series of its locale',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeCatalogue(root);
        _writeEnSnapshot(root);

        final renderer = _createRenderer(root);

        final ukRendering = await renderer.renderBundle(
          edition: _fullEdition(root),
          source: AtlasShotSource.inline,
          locale: _ukLocale,
        );
        final enRendering = await renderer.renderBundle(
          edition: _fullEdition(root),
          source: AtlasShotSource.inline,
          locale: _enLocale,
        );

        final ukPage = File(ukRendering.path).readAsStringSync();
        final enPage = File(enRendering.path).readAsStringSync();
        final ukData = _readBundleData(ukPage);
        final enData = _readBundleData(enPage);
        final enVariants = _readVariants(enData, 'catalog_flow');
        final enStages = enVariants['openExistingItem']?['stages'];

        expect(ukData['seriesLocale'], _ukLocale);
        expect(enData['seriesLocale'], _enLocale);
        expect(
          _readVariants(
            ukData,
            'catalog_flow',
          ).values.map((variant) => variant['series']),
          [<String, Object?>{}, <String, Object?>{}],
        );
        expect(
          (enData['flows'] as List<Object?>).map(
            (flow) => (flow as Map)['name'],
          ),
          ['catalog_flow'],
        );
        expect(((enStages as List<Object?>).single as Map)['label'], 'english');
        expect(_readShots(enPage)['shotCells'], {
          _storedShot: [0, 0, 0, 1, 1],
          _endShot: [0, 1, 0, 1, 1],
        });
        expect(ukRendering.images, 1);
        expect(enRendering.images, 1);
        expect(enData['locales'], {
          _ukLocale: _ukTranslations,
          _enLocale: _enTranslations,
        });
      });
    },
  );
}

void _atlasPageRenderer_should_bundleEveryLocaleInOneFile() {
  test('AtlasPageRenderer should bundle every locale in one file', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      _writeEnSnapshot(root);

      final rendering = await _createRenderer(root).renderBundle(
        edition: _fullEdition(root),
        source: AtlasShotSource.files,
      );

      final data = _readBundleData(File(rendering.path).readAsStringSync());
      final existingItem = _readVariants(
        data,
        'catalog_flow',
      )['openExistingItem'];
      final series = existingItem?['series'] as Map<String, Object?>;

      expect(data, isNot(contains('seriesLocale')));
      expect(series.keys, [_enLocale]);
      expect(rendering.path, endsWith('bundle.full/index.html'));
    });
  });
}

void _atlasPageRenderer_should_nameBundleByEdition() {
  test('AtlasPageRenderer should name bundle by edition', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);

      final renderer = _createRenderer(root);

      final full = await renderer.renderBundle(
        edition: _fullEdition(root),
        source: AtlasShotSource.files,
        locale: _ukLocale,
      );
      final lite = await renderer.renderBundle(
        edition: root.paths.pageConfig.resolveEdition(AtlasEdition.liteName),
        source: AtlasShotSource.files,
        locale: _ukLocale,
      );

      expect(p.basename(p.dirname(full.path)), 'bundle.full.uk');
      expect(p.basename(p.dirname(lite.path)), 'bundle.lite.uk');
      expect(File(full.path).existsSync(), isTrue);
      expect(File(lite.path).existsSync(), isTrue);
    });
  });
}

void _atlasPageRenderer_should_rejectBundleOfLocaleOffPage() {
  test('AtlasPageRenderer should reject bundle of locale off page', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);

      await expectLater(
        _createRenderer(root).renderBundle(
          edition: _fullEdition(root),
          source: AtlasShotSource.files,
          locale: 'de',
        ),
        throwsA(isA<AtlasException>()),
      );

      expect(
        File(
          root.paths.resolveBundlePagePath(AtlasEdition.fullName, locale: 'de'),
        ).existsSync(),
        isFalse,
      );
    });
  });
}

void _atlasPageRenderer_should_linkShotsOfAUrlsBundle() {
  test('AtlasPageRenderer should link shots of a urls bundle', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);

      final publisher = _FakeShotPublisher();

      root.project.publisher = publisher;

      final rendering = await _createRenderer(root).renderBundle(
        edition: _fullEdition(root),
        source: AtlasShotSource.urls,
        locale: _ukLocale,
      );

      final page = File(rendering.path).readAsStringSync();
      final shots = _readShots(page);

      expect(publisher.published.toSet(), {_stageShot, _endShot});
      expect(shots['shotUrls'], {
        _stageShot: 'https://shots.example/$_stageShot.png',
        _endShot: 'https://shots.example/$_endShot.png',
      });
      expect(shots['shotSheets'], isEmpty);
      expect(page, isNot(contains('data:image')));
      expect(rendering.images, 0);
    });
  });
}

void _atlasPageRenderer_should_stopBundleWhenPublishFails() {
  test('AtlasPageRenderer should stop bundle when publish fails', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);

      root.project.publisher = _FakeShotPublisher(failure: 'the host is down');

      await expectLater(
        _createRenderer(root).renderBundle(
          edition: _fullEdition(root),
          source: AtlasShotSource.urls,
          locale: _ukLocale,
        ),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('the host is down'),
          ),
        ),
      );

      expect(
        File(
          root.paths.resolveBundlePagePath(
            AtlasEdition.fullName,
            locale: _ukLocale,
          ),
        ).existsSync(),
        isFalse,
      );
    });
  });
}

void _atlasPageRenderer_should_stopBundleWhenPublisherLeavesAShotUnlinked() {
  test('AtlasPageRenderer should stop bundle when publisher leaves a shot '
      'unlinked', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);

      root.project.publisher = _FakeShotPublisher(skipped: _endShot);

      await expectLater(
        _createRenderer(root).renderBundle(
          edition: _fullEdition(root),
          source: AtlasShotSource.urls,
          locale: _ukLocale,
        ),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains(_endShot),
          ),
        ),
      );
    });
  });
}

void _atlasPageRenderer_should_rejectUrlsBundleWithoutPublisher() {
  test(
    'AtlasPageRenderer should reject urls bundle without publisher',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeCatalogue(root);

        await expectLater(
          _createRenderer(root).renderBundle(
            edition: _fullEdition(root),
            source: AtlasShotSource.urls,
          ),
          throwsA(
            isA<AtlasException>().having(
              (error) => error.message,
              'message',
              contains('shotPublisher'),
            ),
          ),
        );
      });
    },
  );
}

void _atlasPageRenderer_should_copyShotsBesideAFilesBundle() {
  test('AtlasPageRenderer should copy shots beside a files bundle', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      root.writeShot(_strandedShot, _shotBytes);

      final rendering = await _createRenderer(root).renderBundle(
        edition: _fullEdition(root),
        source: AtlasShotSource.files,
        locale: _ukLocale,
      );

      final shots = Directory(
        p.join(p.dirname(rendering.path), 'shots'),
      ).listSync().map((file) => p.basename(file.path)).toSet();

      expect(shots, {'$_stageShot.png', '$_endShot.png'});
      expect(_readShots(File(rendering.path).readAsStringSync()), {
        'shotSheets': <Object?>[],
        'shotCells': <String, Object?>{},
      });
      expect(rendering.images, 0);
    });
  });
}

void _atlasPageRenderer_should_writeSheetFilesBesideASheetsBundle() {
  test(
    'AtlasPageRenderer should write sheet files beside a sheets bundle',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeCatalogue(root);

        final rendering = await _createRenderer(root).renderBundle(
          edition: _fullEdition(root),
          source: AtlasShotSource.sheets,
          locale: _ukLocale,
        );

        final page = File(rendering.path).readAsStringSync();
        final sheetBytes = utf8.encode('$_stageShot,$_endShot');
        final sheetName = AtlasShotSheet(bytes: sheetBytes, cells: {}).fileName;
        final sheetFiles = _readSheetFiles(rendering.path);

        expect(_readShots(page), {
          'shotSheets': ['shots/$sheetName'],
          'shotCells': {
            _stageShot: [0, 0, 0, 1, 1],
            _endShot: [0, 1, 0, 1, 1],
          },
        });
        expect(sheetFiles.keys, [sheetName]);
        expect(sheetFiles[sheetName]?.readAsBytesSync(), sheetBytes);
        expect(rendering.images, sheetFiles.length);
        expect(page, isNot(contains('data:image')));
      });
    },
  );
}

void _atlasPageRenderer_should_bundleBothLocalesOfASheetsBundleInOnePage() {
  test('AtlasPageRenderer should bundle both locales of a sheets bundle in one '
      'page', () async {
    await TestAtlasRoot.run((root) async {
      _writeCatalogue(root);
      _writeEnSnapshot(root);

      final rendering = await _createRenderer(root).renderBundle(
        edition: _fullEdition(root),
        source: AtlasShotSource.sheets,
      );

      final page = File(rendering.path).readAsStringSync();
      final data = _readBundleData(page);
      final series =
          _readVariants(data, 'catalog_flow')['openExistingItem']?['series']
              as Map<String, Object?>;
      final sheets = (_readShots(page)['shotSheets'] as List<Object?>);

      expect(data, isNot(contains('seriesLocale')));
      expect(series.keys, [_enLocale]);
      expect(data['locales'], {
        _ukLocale: _ukTranslations,
        _enLocale: _enTranslations,
      });
      expect(sheets, isNotEmpty);
      expect(_readSheetFiles(rendering.path).length, sheets.length);
      expect(rendering.images, sheets.length);
      expect(page, isNot(contains('data:image')));
    });
  });
}

void _atlasPageRenderer_should_keepOnlyItsSheetsInTheShotsFolder() {
  test(
    'AtlasPageRenderer should keep only its sheets in the shots folder',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeCatalogue(root);

        final renderer = _createRenderer(root);
        final pagePath = root.paths.resolveBundlePagePath(
          AtlasEdition.fullName,
          locale: _ukLocale,
        );
        final shotsPath = root.paths.resolveBundleShotsPath(pagePath);

        await renderer.renderBundle(
          edition: _fullEdition(root),
          source: AtlasShotSource.files,
          locale: _ukLocale,
        );

        File(p.join(shotsPath, 'stale.webp')).writeAsBytesSync([1]);
        Directory(p.join(shotsPath, 'nested')).createSync();

        final rendering = await renderer.renderBundle(
          edition: _fullEdition(root),
          source: AtlasShotSource.sheets,
          locale: _ukLocale,
        );

        final sheets = _readShots(
          File(rendering.path).readAsStringSync(),
        )['shotSheets'];

        expect(
          _readSheetFiles(rendering.path).keys,
          (sheets as List<Object?>).map((sheet) => p.basename('$sheet')),
        );
        expect(Directory(p.join(shotsPath, 'nested')).existsSync(), isFalse);
      });
    },
  );
}

void _atlasPageRenderer_should_keepShotsFoldersOfEditionsApart() {
  test(
    'AtlasPageRenderer should keep shots folders of editions apart',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeCatalogue(root);

        final renderer = _createRenderer(root);

        final full = await renderer.renderBundle(
          edition: _fullEdition(root),
          source: AtlasShotSource.sheets,
        );
        final lite = await renderer.renderBundle(
          edition: root.paths.pageConfig.resolveEdition(AtlasEdition.liteName),
          source: AtlasShotSource.sheets,
        );

        expect(p.dirname(full.path), isNot(p.dirname(lite.path)));
        expect(_readSheetFiles(full.path), isNotEmpty);
        expect(_readSheetFiles(lite.path), isNotEmpty);
      });
    },
  );
}

void _atlasBundleRendering_should_describeEachLimitItPasses() {
  test('AtlasBundleRendering should describe each limit it passes', () {
    const over = AtlasBundleRendering(path: 'a.html', bytes: 11, images: 7);
    const within = AtlasBundleRendering(path: 'a.html', bytes: 10, images: 5);

    expect(
      over.tryDescribeOverLimit(maxBytes: 10, maxImages: 5),
      allOf(contains('11 bytes'), contains('7 images')),
    );
    expect(
      over.tryDescribeOverLimit(maxBytes: 11, maxImages: 5),
      allOf(isNot(contains('bytes')), contains('7 images')),
    );
    expect(within.tryDescribeOverLimit(maxBytes: 10, maxImages: 5), isNull);
  });
}

final _areaGroups = [
  AutomationFlowGroup(
    name: 'shop.catalog',
    title: AutomationLocalizedText({'uk': 'Каталог', 'en': 'Catalog'}),
    area: AutomationFlowArea(
      name: 'shop',
      title: AutomationLocalizedText({'uk': 'Магазин', 'en': 'Shop'}),
    ),
  ),
  AutomationFlowGroup(
    name: 'support.help',
    title: AutomationLocalizedText({'uk': 'Довідка', 'en': 'Help'}),
    area: AutomationFlowArea(
      name: 'support',
      title: AutomationLocalizedText({'uk': 'Підтримка', 'en': 'Support'}),
    ),
  ),
];

AtlasEdition _fullEdition(TestAtlasRoot root) {
  return root.paths.pageConfig.resolveEdition(AtlasEdition.fullName);
}

void _writeCatalogue(TestAtlasRoot root, {String label = 'browse'}) {
  root
    ..writeSource('pubspec.yaml', _fullPubspec)
    ..writePublishedVariants(_publishedVariants)
    ..writeShot(_stageShot, _shotBytes)
    ..writeShot(_endShot, _shotBytes)
    ..writeTranslations(_ukLocale, _ukTranslations)
    ..writeTranslations(_enLocale, _enTranslations)
    ..writeFlow('catalog_flow', {
      'title': _flowTitle,
      'defaultVariant': 'openExistingItem',
      'variants': {
        'openNewItem': {
          'title': {'en': 'From a new item', 'uk': 'З нового товару'},
          'proves': {'en': 'A new item', 'uk': 'Новий товар'},
          'scenario': _scenario,
          'items': [_tapStep, _scrollStep],
        },
        'openExistingItem': {
          'items': [_tapStep],
        },
        'uncaptured': {
          'items': [_tapStep],
        },
      },
    })
    ..writeFlow('cart_flow', {
      'variants': {
        'cartEmptied': {
          'items': [_tapStep],
        },
      },
    })
    ..writeFlow('cart_scroll', {
      'variants': {
        'rise': {
          'items': [_probeSeriesStep],
        },
      },
    });

  root.project
    ..descriptions[_loginDesign] = _loginDescription
    ..descriptions[_detailsDesign] = _detailsDescription
    ..designLinks[_loginDesign] = _loginDesignLink
    ..designLinks[_detailsDesign] = _detailsDesignLink
    ..tablesToReturn.addAll([_requestsTable, _localeKeysTable]);

  AtlasSnapshotStore(root.paths)
    ..write(_createSnapshot('catalog_flow', 'openNewItem', label))
    ..write(_createSnapshot('catalog_flow', 'openExistingItem', label))
    ..write(_createSnapshot('cart_flow', 'cartEmptied', label));
}

void _writeFullOnlyCatalogue(TestAtlasRoot root) {
  _writeCatalogue(root);

  final snapshot = _createNewItemSnapshot([
    _createKeysStage(
      _stageTranslationKeys,
    ).copyWithJournal(const [_tabRecord, _requestRecord, _stateRecord]),
  ]);

  AtlasSnapshotStore(root.paths).write(
    snapshot.copyWithStages(
      stages: [
        for (final stage in snapshot.stages)
          AtlasStage(
            label: stage.label,
            action: stage.action,
            journal: stage.journal,
            ok: true,
            target: _localeKeyFinder,
            block: null,
            targetRect: null,
            screen: stage.screen,
            designScreen: _loginDesign,
            shot: _stageShot,
            error: null,
            localeKeys: stage.localeKeys,
            texts: const [_itemsTitleValue],
          ),
      ],
      end: AtlasEnd(
        screen: _detailsScreen,
        designScreen: _detailsDesign,
        shot: _endShot,
        localeKeys: const {'detailsTitle': 'hash-details'},
        texts: const [_itemsTitleValue],
      ),
    ),
  );
}

void _expectNoFullOnlyText(String text) {
  expect(text, isNot(contains(_requestPath)));
  expect(text, isNot(contains('itemsTitle')));
  expect(text, isNot(contains('detailsTitle')));
  expect(text, isNot(contains(_itemsTitleValue)));
  expect(text, isNot(contains('signedInOnLaunch')));
  expect(text, isNot(contains('ItemsOwner')));
  expect(text, isNot(contains('https://design.example')));
}

AtlasSnapshot _createSnapshot(
  String flow,
  String variant,
  String label, {
  String? locale,
  String stageShot = _stageShot,
  Map<String, String> manifest = const {},
}) {
  return createAtlasSnapshot(
    flow: flow,
    variant: variant,
    locale: locale,
    manifest: manifest,
    stages: [
      AtlasStage(
        label: label,
        action: 'tap',
        journal: const [],
        ok: true,
        target: const {'by': 'valueKey', 'value': 'bottom_bar.button.primary'},
        block: null,
        targetRect: null,
        screen: _loginScreen,
        designScreen: _loginDesign,
        shot: stageShot,
        error: null,
      ),
    ],
    end: const AtlasEnd(
      screen: _detailsScreen,
      designScreen: _detailsDesign,
      shot: _endShot,
    ),
  );
}

void _writeEnSnapshot(TestAtlasRoot root) {
  root.writeShot(_storedShot, _shotBytes);
  AtlasSnapshotStore(root.paths).write(
    _createSnapshot(
      'catalog_flow',
      'openExistingItem',
      'english',
      locale: _enLocale,
      stageShot: _storedShot,
    ),
  );
}

AtlasSnapshot _createNewItemSnapshot(List<AtlasStage> stages) {
  final snapshot = _createSnapshot('catalog_flow', 'openNewItem', 'browse');

  return snapshot.copyWithStages(stages: stages, end: snapshot.end);
}

AtlasStage _createStage(String label, String action) {
  return AtlasStage(
    label: label,
    action: action,
    journal: const [],
    ok: true,
    target: null,
    block: null,
    targetRect: null,
    screen: null,
    designScreen: null,
    shot: _stageShot,
    error: null,
  );
}

AtlasStage _createKeysStage(Map<String, String> localeKeys) {
  return AtlasStage(
    label: 'browse',
    action: 'tap',
    journal: const [],
    ok: true,
    target: null,
    block: null,
    targetRect: null,
    screen: _loginScreen,
    designScreen: null,
    shot: _stageShot,
    error: null,
    localeKeys: localeKeys,
  );
}

AtlasSnapshot _createTwoStageSnapshot() {
  return createAtlasSnapshot(
    flow: 'catalog_flow',
    variant: 'openNewItem',
    stages: const [
      AtlasStage(
        label: 'items tab',
        action: 'tap',
        journal: [_tabRecord, _itemsViewRecord],
        ok: true,
        target: {'by': 'valueKey', 'value': 'main_nav.tab.items'},
        block: null,
        targetRect: _targetRect,
        screen: _loginScreen,
        designScreen: null,
        shot: _stageShot,
        error: null,
      ),
      AtlasStage(
        label: 'review',
        action: 'tap',
        journal: [_reviewTapRecord, _detailsViewRecord],
        ok: true,
        target: {'by': 'text', 'value': 'review'},
        block: null,
        targetRect: null,
        screen: _itemsScreen,
        designScreen: null,
        shot: _stageShot,
        error: null,
      ),
    ],
    end: const AtlasEnd(
      screen: _detailsScreen,
      designScreen: _detailsDesign,
      shot: _endShot,
    ),
  );
}

Map<String, List<int>> _readShotFiles(TestAtlasRoot root) {
  final files = Directory(root.paths.shotsPath).listSync().whereType<File>();

  return {
    for (final file in files) p.basename(file.path): file.readAsBytesSync(),
  };
}

Map<String, Map<String, Object?>> _readVariants(
  Map<String, Object?> data,
  String flowName,
) {
  final flows = (data['flows'] as List<Object?>).cast<Map<String, Object?>>();
  final flow = flows.firstWhere((flow) => flow['name'] == flowName);
  final variants = (flow['variants'] as List<Object?>)
      .cast<Map<String, Object?>>();

  return {for (final variant in variants) '${variant['name']}': variant};
}

String _readScript(String page, String pattern) {
  final match = RegExp(pattern, dotAll: true).firstMatch(page);

  expect(match, isNotNull, reason: 'the page holds no script for $pattern');

  return '${match?.group(1)}';
}

Map<String, Object?> _readData(String page) {
  return jsonDecode(_readScript(page, _dataPattern)) as Map<String, Object?>;
}

Map<String, Object?> _readRenderedData(TestAtlasRoot root) {
  return _readData(File(root.paths.pagePath).readAsStringSync());
}

Map<String, Object?> _readBundleData(String page) {
  final packed = base64Decode(
    jsonDecode(_readScript(page, _dataPattern)) as String,
  );

  return jsonDecode(utf8.decode(gzip.decode(packed))) as Map<String, Object?>;
}

Map<String, Object?> _readShots(String page) {
  return jsonDecode(_readScript(page, _shotsPattern)) as Map<String, Object?>;
}

Map<String, Object?> _readMeta(String page) {
  return jsonDecode(_readScript(page, _metaPattern)) as Map<String, Object?>;
}

Map<String, Object?> _readFirstStage(String page) {
  final variant = _readVariants(_readData(page), 'catalog_flow')['openNewItem'];

  return ((variant?['stages'] as List<Object?>).first as Map<String, Object?>);
}

List<Map<String, Object?>> _readCatalogFlowVariants(TestAtlasRoot root) {
  final flows = _readRenderedData(root)['flows'] as List<Object?>;
  final catalogFlow = flows.last as Map<String, Object?>;

  return (catalogFlow['variants'] as List<Object?>)
      .cast<Map<String, Object?>>()
      .toList();
}

List<Map<String, Object?>> _readNewItemStages(TestAtlasRoot root) {
  final newItem = _readCatalogFlowVariants(root).first;

  return (newItem['stages'] as List<Object?>)
      .cast<Map<String, Object?>>()
      .toList();
}

Iterable<String> _findStepKeys(Map<String, Object?> stage) {
  return stage.keys.where((key) => key == 'title' || key == 'scroll');
}

AtlasPageRenderer _createRenderer(TestAtlasRoot root) {
  return AtlasPageRenderer(root.paths, shotEncoder: const HashShotEncoder());
}

final class _FakeShotPublisher implements AtlasShotPublisher {
  final String? failure;
  final String? skipped;
  final List<String> published = [];

  _FakeShotPublisher({this.failure, this.skipped});

  @override
  Future<Map<String, Uri>> publish(List<AtlasShot> shots) async {
    if (failure case final message?) {
      throw StateError(message);
    }

    published.addAll(shots.map((shot) => shot.hash));

    return {
      for (final shot in shots)
        if (shot.hash != skipped)
          shot.hash: Uri.parse('https://shots.example/${shot.hash}.png'),
    };
  }
}

String _hashSheetDataUri(List<String> shots) {
  return '$_shotDataUriPrefix${base64Encode(utf8.encode(shots.join(',')))}';
}

Map<String, File> _readSheetFiles(String pagePath) {
  final directory = Directory(p.join(p.dirname(pagePath), 'shots'));

  return {
    for (final file in directory.listSync().whereType<File>())
      p.basename(file.path): file,
  };
}
