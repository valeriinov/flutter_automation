import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_page_renderer.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/headless_chrome.dart';
import 'test_utils/test_atlas_root.dart';

const _flow = 'catalog_flow';
const _variant = 'openItem';
const _flowTitle = {'en': 'Browse items', 'uk': 'Переглянути товари'};
const _variantTitle = {'en': 'Open an item', 'uk': 'Відкрити товар'};
const _ukShot =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _enShot =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _endShot =
    '3333333333333333333333333333333333333333333333333333333333333333';
// A PNG of one transparent pixel: the page replaces a shot it cannot decode
// with a placeholder.
final _shotBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);
const _pubspec = '''
name: sample
flutter_automation:
  defaultLocale: uk
  atlas:
    maxBundleBytes: 15728640
    maxBundleImages: 500
''';
const _readPage = '''
(() => {
  const isShown = (node) => node.offsetParent !== null;
  const texts = (selector) => [...document.querySelectorAll(selector)]
    .filter(isShown).map((node) => node.innerText.trim()).join(' | ');
  return {
    titles: texts('.flow-tab-title') + ' || ' + texts('.vselect-label'),
    shots: [...document.querySelectorAll('img')].filter(isShown)
      .map((image) => image.getAttribute('src')).join(' '),
  };
})()
''';
const _waitForPage = '''
new Promise((resolve) => {
  const check = () => document.querySelector('.flow-tab-title')
    ? resolve(true) : setTimeout(check, 50);
  check();
})
''';

void main() {
  group('Atlas Page Language Switches Tests', () {
    _atlasPage_should_changeOnlyTheInterfaceWithTheLanguageSwitch();
    _atlasPage_should_changeOnlyTheShotsWithTheSeriesSwitch();
  });
}

void _atlasPage_should_changeOnlyTheInterfaceWithTheLanguageSwitch() {
  test(
    'AtlasPage should change only the interface with the language switch',
    () async {
      await _withPage((chrome) async {
        final before = await _press(chrome, '#lang-uk');

        final after = await chrome.evaluate(_readPage) as Map;

        expect(before['titles'], contains(_flowTitle['en']));
        expect(after['titles'], contains(_flowTitle['uk']));
        expect(after['titles'], contains(_variantTitle['uk']));
        expect(after['shots'], before['shots']);
      });
    },
    skip: _resolveSkip(),
  );
}

void _atlasPage_should_changeOnlyTheShotsWithTheSeriesSwitch() {
  test(
    'AtlasPage should change only the shots with the series switch',
    () async {
      await _withPage((chrome) async {
        final before = await _press(chrome, '[data-key="series:en"]');

        final after = await chrome.evaluate(_readPage) as Map;

        expect(before['shots'], contains(_ukShot));
        expect(after['shots'], contains(_enShot));
        expect(after['titles'], before['titles']);
        expect(after['titles'], contains(_flowTitle['en']));
      });
    },
    skip: _resolveSkip(),
  );
}

Object _resolveSkip() {
  return tryFindChrome() == null ? 'Chrome is not installed' : false;
}

Future<Map<Object?, Object?>> _press(
  HeadlessChrome chrome,
  String selector,
) async {
  final before = await chrome.evaluate(_readPage) as Map;

  await chrome.evaluate(
    "document.querySelector('$selector').click();"
    'new Promise((resolve) => setTimeout(resolve, 100))',
  );

  return before;
}

Future<void> _withPage(Future<void> Function(HeadlessChrome chrome) body) {
  return TestAtlasRoot.run((root) async {
    _writeCatalogue(root);

    await AtlasPageRenderer(root.paths).render();

    final chrome = await HeadlessChrome.open(
      tryFindChrome() ?? '',
      File(root.paths.pagePath).uri,
    );

    try {
      await chrome.evaluate(_waitForPage);
      await body(chrome);
    } finally {
      await chrome.close();
    }
  });
}

void _writeCatalogue(TestAtlasRoot root) {
  root
    ..writeSource('pubspec.yaml', _pubspec)
    ..writePublishedVariants({
      _flow: [_variant],
    })
    ..writeShot(_ukShot, _shotBytes)
    ..writeShot(_enShot, _shotBytes)
    ..writeShot(_endShot, _shotBytes)
    ..writeTranslations('uk', const {})
    ..writeTranslations('en', const {})
    ..writeFlow(_flow, {
      'title': _flowTitle,
      'variants': {
        _variant: {
          'title': _variantTitle,
          'items': [
            {
              'action': 'tap',
              'label': 'open',
              'finder': {'by': 'valueKey', 'value': 'items.button.open'},
            },
          ],
        },
      },
    });

  AtlasSnapshotStore(root.paths)
    ..write(_createSnapshot('uk', _ukShot))
    ..write(_createSnapshot('en', _enShot));
}

AtlasSnapshot _createSnapshot(String locale, String shot) {
  return createAtlasSnapshot(
    flow: _flow,
    variant: _variant,
    locale: locale,
    stages: [
      AtlasStage(
        label: 'open',
        action: 'tap',
        journal: const [],
        ok: true,
        target: const {'by': 'valueKey', 'value': 'items.button.open'},
        block: null,
        targetRect: null,
        screen: 'items-route',
        designScreen: null,
        shot: shot,
        error: null,
      ),
    ],
    end: const AtlasEnd(
      screen: 'details-route',
      designScreen: null,
      shot: _endShot,
    ),
  );
}
