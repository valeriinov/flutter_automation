import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_builder.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/test_atlas_root.dart';

const _device = testAtlasDevice;
final _uk = fakeAtlasLocales.first;
const _defHash = testAtlasDefHash;
const _okStatus = 200;
const _stepHash = '111111111111';
const _frameTexts = ['Кошики', '3 товари', 'Кошик → Оплата'];
const _itemCountForms = {'few': 'товари', 'other': 'товарів'};
const _cartsScreen = {
  'screenName': 'carts-route',
  'designScreenName': 'home/buyer',
};
const _detailsScreen = {
  'screenName': 'cart-details-route',
  'designScreenName': 'cart/details',
};
const _cartsWidgets = ['CartsScreen', 'CartsView'];
const _detailsWidgets = ['CartDetailsScreen', 'CartDetailsView'];
const _toastText = 'Товар видалено';
const _detailsTitle = 'Деталі товару';
const _toastTranslations = {
  'cartsTitle': 'Кошики',
  'detailsTitle': _detailsTitle,
  'deletedToast': _toastText,
};
const _cartTarget = {'by': 'valueKey', 'value': 'cart_search.card'};
const _targetRect = {'left': 0.05, 'top': 0.4, 'right': 0.95, 'bottom': 0.55};
const _lateCartsRecord = {
  'seq': 0,
  'kind': 'state',
  'owner': 'CartsOwner',
  'status': 'CartsStatusBase',
  'isLoading': false,
};
const _lateDetailsRecord = {
  'seq': 3,
  'kind': 'state',
  'owner': 'CartDetailsOwner',
  'status': 'CartDetailsStatusBase',
  'isLoading': false,
};
const _endRecord = {
  'seq': 5,
  'kind': 'request',
  'path': '/baskets/list',
  'status': _okStatus,
};
const _leadingStep = {
  'label': 'carts shown',
  'action': 'waitFor',
  'ok': true,
  'journal': [
    {'seq': 0, 'kind': 'request', 'path': '/settings'},
  ],
  'screen': _cartsScreen,
};
const _openDetailsStep = {
  'label': 'open cart details',
  'action': 'tap',
  'target': _cartTarget,
  'block': 'quote_open_cart_details',
  'targetRect': _targetRect,
  'screenshot': 'shop_flow_shopFromExistingItem_2.png',
  'journalBeforeAction': [_lateCartsRecord],
  'ok': true,
  'journal': [
    {
      'seq': 1,
      'kind': 'analytics',
      'name': 'cart_opened',
      'parameters': {'session_id': 'volatile'},
    },
  ],
  'screen': _cartsScreen,
};
const _detailsShownStep = {
  'label': 'cart details shown',
  'action': 'waitFor',
  'ok': true,
  'journal': [
    {'seq': 2, 'kind': 'request', 'path': '/carts/1', 'status': _okStatus},
  ],
  'screen': _detailsScreen,
};
const _confirmStep = {
  'label': 'confirm',
  'action': 'tap',
  'screenshot': 'shop_flow_shopFromExistingItem_3.png',
  'journalBeforeAction': [_lateDetailsRecord],
  'ok': true,
  'journal': [
    {
      'seq': 4,
      'kind': 'request',
      'path': '/baskets/create',
      'status': _okStatus,
    },
  ],
  'screen': _detailsScreen,
};

void main() {
  group('AtlasSnapshotBuilder Tests', () {
    _atlasSnapshotBuilder_should_openNoStageForStepsBeforeFirstAction();
    _atlasSnapshotBuilder_should_mergeJournalOfActionAndFollowing();
    _atlasSnapshotBuilder_should_appendJournalBeforeActionToPrevious();
    _atlasSnapshotBuilder_should_dropJournalBeforeFirstAction();
    _atlasSnapshotBuilder_should_appendEndJournalToLastStage();
    _atlasSnapshotBuilder_should_openStageOnStepsCarryingScreenshot();
    _atlasSnapshotBuilder_should_reportFirstErrorOfStage();
    _atlasSnapshotBuilder_should_readEndFromLastCapturedStep();
    _atlasSnapshotBuilder_should_hashManifestFiles();
    _atlasSnapshotBuilder_should_writeOneDeclarationsRecordPerContent();
    _atlasSnapshotBuilder_should_holdStepHashAndSourcesOfEachStage();
    _atlasSnapshotBuilder_should_leaveMockFilesOutOfManifest();
    _atlasSnapshotBuilder_should_openFirstJournalWithLaunchRecord();
    _atlasSnapshotBuilder_should_holdTextsAndTheKeysTheyRender();
    _atlasSnapshotBuilder_should_holdEndTextsAndTheKeysTheyRender();
    _atlasSnapshotBuilder_should_holdWidgetsOfFrameBeforeEachAction();
    _atlasSnapshotBuilder_should_holdEndWidgets();
    _atlasSnapshotBuilder_should_addTextsReadAfterStepsToNextStage();
    _atlasSnapshotBuilder_should_addTextsReadAfterLastStageToEnd();
    _atlasSnapshotBuilder_should_keepJournalsWhenTextsReadAfterSteps();
    _atlasSnapshotBuilder_should_addSameTextsAfterUnshotStage();
    _atlasSnapshotBuilder_should_readKeysFromTranslationsOfItsLocale();
    _atlasSnapshotBuilder_should_leaveOutMarkedKeyTranslationsLack();
  });
}

void _atlasSnapshotBuilder_should_openNoStageForStepsBeforeFirstAction() {
  test(
    'AtlasSnapshotBuilder should open no stage for steps before first action',
    () async {
      await TestAtlasRoot.run((root) {
        final snapshot = _build(root, [
          _leadingStep,
          _openDetailsStep,
          _detailsShownStep,
        ]);
        final stage = snapshot.stages.firstOrNull;

        expect(snapshot.stages, hasLength(1));
        expect(stage?.label, 'open cart details');
        expect(stage?.target, _cartTarget);
        expect(stage?.block, 'quote_open_cart_details');
        expect(stage?.targetRect, _targetRect);
        expect(stage?.screen, 'carts-route');
        expect(stage?.designScreen, 'home/buyer');
        expect(stage?.shot, 'shop_flow_shopFromExistingItem_2.png');
        expect(
          stage?.journal.none(
            (record) => record is Map && record['path'] == '/settings',
          ),
          isTrue,
        );
      });
    },
  );
}

void _atlasSnapshotBuilder_should_mergeJournalOfActionAndFollowing() {
  test(
    'AtlasSnapshotBuilder should merge journal of action and following',
    () async {
      await TestAtlasRoot.run((root) {
        final snapshot = _build(root, [
          _leadingStep,
          _openDetailsStep,
          _detailsShownStep,
        ]);

        expect(snapshot.stages.firstOrNull?.journal, [
          {
            'kind': 'analytics',
            'name': 'cart_opened',
            'parameters': <String, Object?>{},
          },
          {'kind': 'request', 'path': '/carts/1', 'status': _okStatus},
        ]);
      });
    },
  );
}

void _atlasSnapshotBuilder_should_appendJournalBeforeActionToPrevious() {
  test(
    'AtlasSnapshotBuilder should append journal before action to previous',
    () async {
      await TestAtlasRoot.run((root) {
        final snapshot = _build(root, [
          _openDetailsStep,
          _detailsShownStep,
          _confirmStep,
        ]);

        expect(snapshot.stages.firstOrNull?.journal.lastOrNull, {
          'kind': 'state',
          'owner': 'CartDetailsOwner',
          'status': 'CartDetailsStatusBase',
          'isLoading': false,
        });
        expect(snapshot.stages.lastOrNull?.journal, [
          {'kind': 'request', 'path': '/baskets/create', 'status': _okStatus},
        ]);
      });
    },
  );
}

void _atlasSnapshotBuilder_should_dropJournalBeforeFirstAction() {
  test(
    'AtlasSnapshotBuilder should drop journal before first action',
    () async {
      await TestAtlasRoot.run((root) {
        final snapshot = _build(root, [_leadingStep, _openDetailsStep]);

        expect(
          snapshot.stages.single.journal.none(
            (record) => record is Map && record['owner'] == 'CartsOwner',
          ),
          isTrue,
        );
      });
    },
  );
}

void _atlasSnapshotBuilder_should_appendEndJournalToLastStage() {
  test(
    'AtlasSnapshotBuilder should append end journal to last stage',
    () async {
      await TestAtlasRoot.run((root) {
        final snapshot = _build(
          root,
          [_openDetailsStep, _detailsShownStep, _confirmStep],
          reportFields: {
            'endJournal': [_endRecord],
          },
        );

        expect(snapshot.stages.lastOrNull?.journal, [
          {'kind': 'request', 'path': '/baskets/create', 'status': _okStatus},
          {'kind': 'request', 'path': '/baskets/list', 'status': _okStatus},
        ]);
      });
    },
  );
}

void _atlasSnapshotBuilder_should_openStageOnStepsCarryingScreenshot() {
  test(
    'AtlasSnapshotBuilder should open stage on steps carrying screenshot',
    () async {
      await TestAtlasRoot.run((root) {
        final snapshot = _build(root, [
          _leadingStep,
          {
            'label': 'scroll to the card',
            'action': 'scroll',
            'target': _cartTarget,
            'screenshot': 'shop_flow_shopFromExistingItem_2.png',
            'ok': true,
            'journal': <Object?>[],
            'screen': _cartsScreen,
          },
          {
            'label': 'hold the feed',
            'action': 'scroll',
            'target': _cartTarget,
            'ok': true,
            'journal': <Object?>[],
            'screen': _cartsScreen,
          },
          {
            'label': 'type an amount',
            'action': 'enterText',
            'screenshot': null,
            'ok': false,
            'error': 'Could not capture the screen before type an amount',
          },
        ], isOk: false);
        final lastStage = snapshot.stages.lastOrNull;

        expect(snapshot.stages.map((stage) => stage.label), [
          'scroll to the card',
          'type an amount',
        ]);
        expect(lastStage?.shot, isNull);
        expect(lastStage?.ok, isFalse);
        expect(
          lastStage?.error,
          'Could not capture the screen before type an amount',
        );
      });
    },
  );
}

void _atlasSnapshotBuilder_should_reportFirstErrorOfStage() {
  test('AtlasSnapshotBuilder should report first error of stage', () async {
    await TestAtlasRoot.run((root) {
      final snapshot = _build(root, [
        _openDetailsStep,
        {
          'label': 'cart details shown',
          'action': 'waitFor',
          'ok': false,
          'error': 'timed out',
        },
      ], isOk: false);
      final stage = snapshot.stages.firstOrNull;

      expect(snapshot.ok, isFalse);
      expect(stage?.ok, isFalse);
      expect(stage?.error, 'timed out');
      expect(stage?.screen, isNull);
    });
  });
}

void _atlasSnapshotBuilder_should_readEndFromLastCapturedStep() {
  test(
    'AtlasSnapshotBuilder should read end from last captured step',
    () async {
      await TestAtlasRoot.run((root) {
        final snapshot = _build(root, [
          _openDetailsStep,
          _detailsShownStep,
          {
            'label': 'confirm',
            'action': 'tap',
            'screenshot': 'shop_flow_shopFromExistingItem_3.png',
            'ok': false,
            'error': 'gone',
          },
        ], isOk: false);

        expect(snapshot.end.screen, 'cart-details-route');
        expect(snapshot.end.designScreen, 'cart/details');
        expect(snapshot.end.shot, 'end.png');
      });
    },
  );
}

void _atlasSnapshotBuilder_should_hashManifestFiles() {
  test('AtlasSnapshotBuilder should hash manifest files', () async {
    await TestAtlasRoot.run((root) {
      root.writeSource(
        'lib/main.dart',
        'void main() => runApp(App().automationTarget(AppTarget.root));',
      );

      final snapshot = _build(
        root,
        [_openDetailsStep],
        reportFields: {
          'manifest': ['lib/main.dart', 'lib/missing.dart'],
        },
      );

      expect(snapshot.manifest, {
        'lib/main.dart': testSourceHash.hashSource(
          'void main() => runApp(App());',
        ),
      });
      expect(snapshot.flow, 'shop_flow');
      expect(snapshot.device, _device);
      expect(snapshot.defHash, _defHash);
    });
  });
}

void _atlasSnapshotBuilder_should_writeOneDeclarationsRecordPerContent() {
  test(
    'AtlasSnapshotBuilder should write one declarations record per content',
    () async {
      await TestAtlasRoot.run((root) {
        root
          ..writeSource('lib/shared.dart', 'class Shared {}')
          ..writeSource('lib/carts.dart', 'class Carts {}')
          ..writeSource('lib/items.dart', 'class Items {}');

        final cartsSnapshot = _build(
          root,
          [_openDetailsStep],
          reportFields: {
            'manifest': ['lib/shared.dart', 'lib/carts.dart'],
          },
        );
        final itemsSnapshot = _build(
          root,
          [_openDetailsStep],
          reportFields: {
            'variant': 'shopFromNewItem',
            'manifest': ['lib/shared.dart', 'lib/items.dart'],
          },
        );
        final recordNames = Directory(root.paths.declarationsPath)
            .listSync()
            .map((record) => p.basenameWithoutExtension(record.path))
            .sorted();

        expect(
          recordNames,
          {
            ...cartsSnapshot.manifest.values,
            ...itemsSnapshot.manifest.values,
          }.sorted(),
        );
      });
    },
  );
}

void _atlasSnapshotBuilder_should_leaveMockFilesOutOfManifest() {
  test(
    'AtlasSnapshotBuilder should leave mock files out of manifest',
    () async {
      await TestAtlasRoot.run((root) {
        root
          ..writeSource('lib/main.dart', 'void main() {}')
          ..writeSource(
            'lib/support/mock/mock_installer.dart',
            'class MockInstaller {}',
          );

        final snapshot = _build(
          root,
          [_openDetailsStep],
          reportFields: {
            'manifest': [
              'lib/main.dart',
              'lib/support/mock/mock_installer.dart',
            ],
          },
        );

        expect(snapshot.manifest.keys, ['lib/main.dart']);
      });
    },
  );
}

void _atlasSnapshotBuilder_should_openFirstJournalWithLaunchRecord() {
  test(
    'AtlasSnapshotBuilder should open first journal with launch record',
    () async {
      await TestAtlasRoot.run((root) {
        final snapshot = _build(
          root,
          [_openDetailsStep, _openDetailsStep],
          reportFields: {
            'launch': {
              'kind': 'launch',
              'features': ['login'],
              'anchor': '2026-10-03T09:00:00.000Z',
              'launchedAt': '2026-10-03T09:12:00.000Z',
            },
          },
        );
        final firstStage = snapshot.stages.first;

        expect(firstStage.journal.first, {
          'kind': 'launch',
          'features': ['login'],
        });
        expect(
          snapshot.stages.last.journal.first,
          isNot(firstStage.journal.first),
        );
        expect(
          snapshot.stages.map((stage) => (stage.anchor, stage.launchedAt)),
          everyElement((
            '2026-10-03T09:00:00.000Z',
            '2026-10-03T09:12:00.000Z',
          )),
        );
      });
    },
  );
}

void _atlasSnapshotBuilder_should_holdStepHashAndSourcesOfEachStage() {
  test(
    'AtlasSnapshotBuilder should hold step hash and sources of each stage',
    () async {
      await TestAtlasRoot.run((root) {
        root
          ..writeSource('lib/main.dart', 'void main() {}')
          ..writeSource('lib/carts_screen.dart', 'class CartsScreen {}')
          ..writeSource(
            'lib/app/router.dart',
            "import 'package:sample/carts_screen.dart';",
          )
          ..writeSource(
            'lib/app/router.g.dart',
            '/// [CartsScreen]\n'
                'class CartsRoute extends GeneratedRoute<void> {}\n',
          );

        final snapshot = AtlasSnapshotBuilder(root.paths, _uk).build(
          report: {
            'flow': 'shop_flow',
            'variant': 'shopFromExistingItem',
            'ok': true,
            'steps': [_leadingStep, _openDetailsStep, _detailsShownStep],
            'manifest': ['lib/main.dart', 'lib/carts_screen.dart'],
          },
          device: _device,
          defHash: _defHash,
          stepHashes: const [_stepHash],
        );
        final stage = snapshot.stages.firstOrNull;

        expect(stage?.stepHash, _stepHash);
        expect(stage?.sources, {
          'lib/carts_screen.dart': testSourceHash.hashSource(
            'class CartsScreen {}',
          ),
        });
      });
    },
  );
}

void _atlasSnapshotBuilder_should_holdTextsAndTheKeysTheyRender() {
  test(
    'AtlasSnapshotBuilder should hold texts and the keys they render',
    () async {
      await TestAtlasRoot.run((root) {
        root.writeTranslations('uk', {
          'cartsTitle': 'Кошики',
          'itemCount': _itemCountForms,
          'unused': 'Невидимий',
        });

        final snapshot = _build(root, [
          _leadingStep,
          {
            ..._openDetailsStep,
            'texts': [
              LocaleKeyMarker.mark('cartsTitle', 'Кошики'),
              LocaleKeyMarker.mark('itemCount', '3 товари'),
              'Кошик → Оплата',
            ],
          },
          _detailsShownStep,
        ]);
        final stage = snapshot.stages.firstOrNull;

        expect(stage?.texts, _frameTexts);
        expect(stage?.localeKeys, {
          'cartsTitle': AtlasContentHash.hashJson('Кошики'),
          'itemCount': AtlasContentHash.hashJson(_itemCountForms),
        });
      });
    },
  );
}

void _atlasSnapshotBuilder_should_holdEndTextsAndTheKeysTheyRender() {
  test(
    'AtlasSnapshotBuilder should hold end texts and the keys they render',
    () async {
      await TestAtlasRoot.run((root) {
        root.writeTranslations('uk', {
          'cartsTitle': 'Кошики',
          'itemCount': _itemCountForms,
          'unused': 'Невидимий',
        });

        final snapshot = _build(
          root,
          [_openDetailsStep, _detailsShownStep],
          reportFields: {
            'endTexts': [
              LocaleKeyMarker.mark('cartsTitle', 'Кошики'),
              LocaleKeyMarker.mark('itemCount', '3 товари'),
              'Кошик → Оплата',
            ],
          },
        );

        expect(snapshot.end.texts, _frameTexts);
        expect(snapshot.end.localeKeys, {
          'cartsTitle': AtlasContentHash.hashJson('Кошики'),
          'itemCount': AtlasContentHash.hashJson(_itemCountForms),
        });
        expect(snapshot.stages.single.localeKeys, isEmpty);
      });
    },
  );
}

void _atlasSnapshotBuilder_should_holdWidgetsOfFrameBeforeEachAction() {
  test(
    'AtlasSnapshotBuilder should hold widgets of frame before each action',
    () async {
      await TestAtlasRoot.run((root) {
        final snapshot = _build(root, [
          _leadingStep,
          {..._openDetailsStep, 'widgets': _cartsWidgets},
          _detailsShownStep,
          {..._confirmStep, 'widgets': _detailsWidgets},
        ]);

        expect(snapshot.stages.map((stage) => stage.widgets), [
          _cartsWidgets,
          _detailsWidgets,
        ]);
        expect(snapshot.end.widgets, isEmpty);
      });
    },
  );
}

void _atlasSnapshotBuilder_should_holdEndWidgets() {
  test('AtlasSnapshotBuilder should hold end widgets', () async {
    await TestAtlasRoot.run((root) {
      final snapshot = _build(
        root,
        [_openDetailsStep, _detailsShownStep],
        reportFields: {'endWidgets': _detailsWidgets},
      );

      expect(snapshot.end.widgets, _detailsWidgets);
      expect(snapshot.stages.single.widgets, isEmpty);
    });
  });
}

void _atlasSnapshotBuilder_should_addTextsReadAfterStepsToNextStage() {
  test(
    'AtlasSnapshotBuilder should add texts read after steps to next stage',
    () async {
      await TestAtlasRoot.run((root) {
        root.writeTranslations('uk', _toastTranslations);

        final snapshot = _build(root, _toastSteps());
        final firstStage = snapshot.stages.firstOrNull;
        final lastStage = snapshot.stages.lastOrNull;

        expect(firstStage?.texts, ['Кошики']);
        expect(firstStage?.localeKeys.keys, ['cartsTitle']);
        expect(lastStage?.texts, [_detailsTitle, _toastText]);
        expect(lastStage?.localeKeys, {
          'detailsTitle': AtlasContentHash.hashJson(_detailsTitle),
          'deletedToast': AtlasContentHash.hashJson(_toastText),
        });
      });
    },
  );
}

void _atlasSnapshotBuilder_should_addTextsReadAfterLastStageToEnd() {
  test(
    'AtlasSnapshotBuilder should add texts read after last stage to end',
    () async {
      await TestAtlasRoot.run((root) {
        root.writeTranslations('uk', _toastTranslations);

        final snapshot = _build(
          root,
          [
            _openDetailsStep,
            {
              ..._detailsShownStep,
              'textsAfterStep': [
                LocaleKeyMarker.mark('deletedToast', _toastText),
                'Кошик → Оплата',
              ],
            },
          ],
          reportFields: {
            'endTexts': ['Кошик → Оплата'],
          },
        );

        expect(snapshot.end.texts, ['Кошик → Оплата', _toastText]);
        expect(snapshot.end.localeKeys, {
          'deletedToast': AtlasContentHash.hashJson(_toastText),
        });
      });
    },
  );
}

void _atlasSnapshotBuilder_should_keepJournalsWhenTextsReadAfterSteps() {
  test(
    'AtlasSnapshotBuilder should keep journals when texts read after steps',
    () async {
      await TestAtlasRoot.run((root) {
        final withoutTexts = _build(root, [
          _openDetailsStep,
          _detailsShownStep,
          _confirmStep,
        ]);
        final withTexts = _build(root, _toastSteps());

        expect(
          withTexts.stages.map((stage) => stage.journal),
          withoutTexts.stages.map((stage) => stage.journal),
        );
      });
    },
  );
}

void _atlasSnapshotBuilder_should_addSameTextsAfterUnshotStage() {
  test(
    'AtlasSnapshotBuilder should add same texts after unshot stage',
    () async {
      await TestAtlasRoot.run((root) {
        final shotSteps = _toastSteps();
        final unshotSteps = [
          {...?shotSteps.firstOrNull, 'screenshot': null},
          ...shotSteps.skip(1),
        ];
        final shotWalk = _build(root, shotSteps);
        final unshotWalk = _build(root, unshotSteps);

        expect(
          unshotWalk.stages.lastOrNull?.texts,
          shotWalk.stages.lastOrNull?.texts,
        );
        expect(unshotWalk.stages.lastOrNull?.texts, [
          _detailsTitle,
          _toastText,
        ]);
      });
    },
  );
}

void _atlasSnapshotBuilder_should_leaveOutMarkedKeyTranslationsLack() {
  test(
    'AtlasSnapshotBuilder should leave out marked key translations lack',
    () async {
      await TestAtlasRoot.run((root) {
        root.writeTranslations('uk', {'cartsTitle': 'Кошики'});

        final snapshot = _build(root, [
          _leadingStep,
          {
            ..._openDetailsStep,
            'texts': [LocaleKeyMarker.mark('removedTitle', 'Кошики')],
          },
          _detailsShownStep,
        ]);
        final stage = snapshot.stages.firstOrNull;

        expect(stage?.texts, ['Кошики']);
        expect(stage?.localeKeys, isEmpty);
      });
    },
  );
}

void _atlasSnapshotBuilder_should_readKeysFromTranslationsOfItsLocale() {
  test('AtlasSnapshotBuilder should read keys from translations of its '
      'locale', () async {
    await TestAtlasRoot.run((root) {
      root
        ..writeTranslations('uk', {'cartsTitle': 'Кошики'})
        ..writeTranslations('en', {'cartsTitle': 'Carts'});

      final snapshot = AtlasSnapshotBuilder(root.paths, 'en').build(
        report: {
          'flow': 'shop_flow',
          'variant': 'shopFromExistingItem',
          'ok': true,
          'steps': [
            _leadingStep,
            {
              ..._openDetailsStep,
              'texts': [LocaleKeyMarker.mark('cartsTitle', 'Carts')],
            },
            _detailsShownStep,
          ],
          'manifest': const <String>[],
        },
        device: _device,
        defHash: _defHash,
        stepHashes: const [],
      );

      expect(snapshot.locale, 'en');
      expect(snapshot.stages.firstOrNull?.localeKeys, {
        'cartsTitle': AtlasContentHash.hashJson('Carts'),
      });
    });
  });
}

List<Map<String, Object?>> _toastSteps() {
  final cartsTitle = LocaleKeyMarker.mark('cartsTitle', 'Кошики');
  final detailsTitle = LocaleKeyMarker.mark('detailsTitle', _detailsTitle);

  return [
    {
      ..._openDetailsStep,
      'texts': [cartsTitle],
      'textsAfterStep': [cartsTitle],
    },
    {
      ..._detailsShownStep,
      'textsAfterStep': [
        detailsTitle,
        LocaleKeyMarker.mark('deletedToast', _toastText),
      ],
    },
    {
      ..._confirmStep,
      'texts': [detailsTitle],
    },
  ];
}

AtlasSnapshot _build(
  TestAtlasRoot root,
  List<Map<String, Object?>> steps, {
  bool isOk = true,
  Map<String, Object?> reportFields = const {},
}) {
  return AtlasSnapshotBuilder(root.paths, _uk).build(
    report: {
      'flow': 'shop_flow',
      'variant': 'shopFromExistingItem',
      'ok': isOk,
      'steps': steps,
      'endScreenshot': 'end.png',
      'manifest': const <String>[],
      ...reportFields,
    },
    device: _device,
    defHash: _defHash,
    stepHashes: const [],
  );
}
