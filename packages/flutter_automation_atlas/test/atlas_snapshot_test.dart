import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';

const _texts = ['Посилки', 'Київ → Львів'];
const _localeKeys = {'cartsTitle': 'a1b2c3', 'attempts': 'd4e5f6'};
const _widgets = ['CartsScreen', 'CartsView'];
const _end = AtlasEnd(
  screen: 'carts-route',
  designScreen: 'home/buyer',
  shot: 'end.png',
  texts: _texts,
  localeKeys: _localeKeys,
  widgets: _widgets,
);
const _stage = AtlasStage(
  label: 'open carts',
  action: 'tap',
  journal: [],
  ok: true,
  target: null,
  block: null,
  targetRect: null,
  screen: 'carts-route',
  designScreen: 'home/buyer',
  shot: 'a1b2c3d4e5f6',
  error: null,
  texts: _texts,
  widgets: _widgets,
);
const _headlessFrameHash = 'eeeeeeeeeeee';
const _headlessJournalHash = 'ffffffffffff';
const _headlessStage = AtlasStage(
  label: 'open carts',
  action: 'tap',
  journal: [],
  ok: true,
  target: null,
  block: null,
  targetRect: null,
  screen: 'carts-route',
  designScreen: 'home/buyer',
  shot: 'a1b2c3d4e5f6',
  error: null,
  headlessFrameHash: _headlessFrameHash,
  headlessJournalHash: _headlessJournalHash,
);
const _snapshotWithoutWidgets = {
  'flow': 'shop_flow',
  'variant': 'shopFromExistingItem',
  'locale': 'uk',
  'ok': true,
  'device': 'iPhone 16 · iOS 18.2',
  'defHash': '000000000000',
  'manifest': {'lib/carts_view.dart': 'bbbbbbbbbbbb'},
  'stages': [
    {
      'label': 'open carts',
      'action': 'tap',
      'screen': 'carts-route',
      'designScreen': 'home/buyer',
      'shot': 'a1b2c3d4e5f6',
      'journal': [],
      'ok': true,
      'texts': _texts,
    },
  ],
  'end': {
    'screen': 'carts-route',
    'designScreen': 'home/buyer',
    'shot': null,
    'texts': _texts,
  },
};

void main() {
  group('AtlasEnd Tests', () {
    _atlasEnd_should_readBackTextsAndKeysItWrites();
    _atlasEnd_should_readAbsentTextsAndKeysAsEmpty();
    _atlasEnd_should_keepTextsAndKeysInCopyWithShot();
    _atlasEnd_should_keepHeadlessFrameHashInCopyWithShot();
  });
  group('AtlasStage Tests', () {
    _atlasStage_should_readBackWidgetsItWrites();
    _atlasStage_should_keepWidgetsInEveryCopy();
    _atlasStage_should_readBackHeadlessHashesItWrites();
    _atlasStage_should_keepHeadlessHashesInEveryCopy();
  });
  group('AtlasSnapshot Tests', () {
    _atlasSnapshot_should_writeSnapshotWithoutWidgetsAsItReadIt();
  });
}

void _atlasEnd_should_readBackTextsAndKeysItWrites() {
  test('AtlasEnd should read back texts and keys it writes', () {
    final end = AtlasEnd.fromJson(_end.toJson());

    expect(end.screen, 'carts-route');
    expect(end.designScreen, 'home/buyer');
    expect(end.shot, 'end.png');
    expect(end.texts, _texts);
    expect(end.localeKeys, _localeKeys);
    expect(end.widgets, _widgets);
  });
}

void _atlasEnd_should_readAbsentTextsAndKeysAsEmpty() {
  test('AtlasEnd should read absent texts and keys as empty', () {
    final end = AtlasEnd.fromJson(const {
      'screen': 'carts-route',
      'designScreen': null,
      'shot': null,
    });

    expect(end.texts, isEmpty);
    expect(end.localeKeys, isEmpty);
    expect(end.widgets, isEmpty);
    expect(end.toJson(), {
      'screen': 'carts-route',
      'designScreen': null,
      'shot': null,
    });
  });
}

void _atlasEnd_should_keepTextsAndKeysInCopyWithShot() {
  test('AtlasEnd should keep texts and keys in copy with shot', () {
    final end = _end.copyWithShot('a1b2c3d4e5f6');

    expect(end.shot, 'a1b2c3d4e5f6');
    expect(end.texts, _texts);
    expect(end.localeKeys, _localeKeys);
    expect(end.widgets, _widgets);
  });
}

void _atlasEnd_should_keepHeadlessFrameHashInCopyWithShot() {
  test('AtlasEnd should keep headless frame hash in copy with shot', () {
    const end = AtlasEnd(
      screen: null,
      designScreen: null,
      shot: null,
      headlessFrameHash: _headlessFrameHash,
    );
    final copy = AtlasEnd.fromJson(end.copyWithShot('end.png').toJson());

    expect(copy.headlessFrameHash, _headlessFrameHash);
  });
}

void _atlasStage_should_readBackWidgetsItWrites() {
  test('AtlasStage should read back widgets it writes', () {
    final stage = AtlasStage.fromJson(_stage.toJson());

    expect(stage.widgets, _widgets);
    expect(stage.texts, _texts);
  });
}

void _atlasStage_should_keepWidgetsInEveryCopy() {
  test('AtlasStage should keep widgets in every copy', () {
    final copies = [
      _stage.copyWithJournal(const []),
      _stage.copyWithHashes(stepHash: null, sources: {}, localeKeys: {}),
      _stage.copyWithLaunch(anchor: null, launchedAt: null),
      _stage.copyWithShot(null),
    ];

    for (final copy in copies) {
      expect(copy.widgets, _widgets);
    }
  });
}

void _atlasStage_should_readBackHeadlessHashesItWrites() {
  test('AtlasStage should read back headless hashes it writes', () {
    final stage = AtlasStage.fromJson(_headlessStage.toJson());

    expect(stage.headlessFrameHash, _headlessFrameHash);
    expect(stage.headlessJournalHash, _headlessJournalHash);
  });
}

void _atlasStage_should_keepHeadlessHashesInEveryCopy() {
  test('AtlasStage should keep headless hashes in every copy', () {
    final copies = [
      _headlessStage.copyWithJournal(const []),
      _headlessStage.copyWithHashes(
        stepHash: null,
        sources: {},
        localeKeys: {},
      ),
      _headlessStage.copyWithLaunch(anchor: null, launchedAt: null),
      _headlessStage.copyWithShot(null),
    ];

    for (final copy in copies) {
      expect(copy.headlessFrameHash, _headlessFrameHash);
      expect(copy.headlessJournalHash, _headlessJournalHash);
    }
  });
}

void _atlasSnapshot_should_writeSnapshotWithoutWidgetsAsItReadIt() {
  test('AtlasSnapshot should write snapshot without widgets as it read it', () {
    final file = jsonEncode(_snapshotWithoutWidgets);
    final snapshot = AtlasSnapshot.fromJson(jsonDecode(file), fileLocale: 'uk');

    expect(snapshot.stages.single.widgets, isEmpty);
    expect(snapshot.end.widgets, isEmpty);
    expect(jsonEncode(snapshot.toJson()), file);
  });
}
