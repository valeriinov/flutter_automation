import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_page_renderer.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/headless_chrome.dart';
import 'test_utils/test_atlas_root.dart';

const _flowCount = 6;
const _variant = 'openItem';
const _shot =
    '1111111111111111111111111111111111111111111111111111111111111111';
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
const _waitForPage = '''
new Promise((resolve) => {
  const check = () => document.querySelector('.flow-tab-title')
    ? resolve(true) : setTimeout(check, 50);
  check();
})
''';

void main() {
  group('Atlas Page Scroll Arrows Tests', () {
    _atlasPage_should_hideTheArrowsWhenTheFlowsFit();
    _atlasPage_should_showTheArrowsTowardsTheHiddenFlows();
    _atlasPage_should_scrollTheFlowsWithTheRightArrow();
    _atlasPage_should_showTheRightArrowWhenTheLanguageWidensTheFlows();
  });
}

void _atlasPage_should_hideTheArrowsWhenTheFlowsFit() {
  test('AtlasPage should hide the arrows when the flows fit', () async {
    await _withPage((chrome) async {
      final arrows = await _readArrows(chrome, width: 100000, scroll: 0);

      expect(arrows, {'left': false, 'right': false});
    });
  }, skip: _resolveSkip());
}

void _atlasPage_should_showTheArrowsTowardsTheHiddenFlows() {
  test('AtlasPage should show the arrows towards the hidden flows', () async {
    await _withPage((chrome) async {
      final start = await _readArrows(chrome, width: 300, scroll: 0);
      final middle = await _readArrows(chrome, width: 300, scroll: 0.5);
      final end = await _readArrows(chrome, width: 300, scroll: 1);

      expect(start, {'left': false, 'right': true});
      expect(middle, {'left': true, 'right': true});
      expect(end, {'left': true, 'right': false});
    });
  }, skip: _resolveSkip());
}

void _atlasPage_should_scrollTheFlowsWithTheRightArrow() {
  test('AtlasPage should scroll the flows with the right arrow', () async {
    await _withPage((chrome) async {
      await _readArrows(chrome, width: 300, scroll: 0);

      final scrollLeft = await chrome.evaluate('''
document.querySelector('#flow-tabs ~ .strip-arrow.is-right').click();
new Promise((resolve) => {
  const tabs = document.getElementById('flow-tabs');
  const deadline = Date.now() + 5000;
  const check = () => tabs.scrollLeft > 100 || Date.now() > deadline
    ? resolve(tabs.scrollLeft) : setTimeout(check, 50);
  check();
})
''');

      expect(scrollLeft, greaterThan(100));
    });
  }, skip: _resolveSkip());
}

void _atlasPage_should_showTheRightArrowWhenTheLanguageWidensTheFlows() {
  test(
    'AtlasPage should show the right arrow when the language widens the flows',
    () async {
      await _withPage((chrome) async {
        final arrows = await chrome.evaluate('''
(() => {
  const bar = document.querySelector('.flows-bar');
  const tabs = document.getElementById('flow-tabs');
  document.getElementById('lang-en').click();
  bar.style.width = '300px';
  bar.style.width = (300 + tabs.scrollWidth - tabs.clientWidth) + 'px';
  const isShown = (side) =>
    !document.querySelector('#flow-tabs ~ .strip-arrow.is-' + side).hidden;
  return new Promise((resolve) => setTimeout(() => {
    const before = isShown('right');
    document.getElementById('lang-uk').click();
    setTimeout(() => resolve({ before, after: isShown('right') }), 100);
  }, 100));
})()
''');

        expect(arrows, {'before': false, 'after': true});
      });
    },
    skip: _resolveSkip(),
  );
}

Object _resolveSkip() {
  return tryFindChrome() == null ? 'Chrome is not installed' : false;
}

Future<Object?> _readArrows(
  HeadlessChrome chrome, {
  required int width,
  required double scroll,
}) {
  return chrome.evaluate('''
(() => {
  document.querySelector('.flows-bar').style.width = '${width}px';
  const tabs = document.getElementById('flow-tabs');
  tabs.style.scrollBehavior = 'auto';
  tabs.scrollLeft = (tabs.scrollWidth - tabs.clientWidth) * $scroll;
  tabs.style.scrollBehavior = '';
  return new Promise((resolve) => setTimeout(() => {
    const isShown = (side) =>
      !document.querySelector('#flow-tabs ~ .strip-arrow.is-' + side).hidden;
    resolve({ left: isShown('left'), right: isShown('right') });
  }, 100));
})()
''');
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
    ..writeShot(_shot, _shotBytes)
    ..writeTranslations('uk', const {})
    ..writeTranslations('en', const {})
    ..writePublishedVariants({
      for (int index = 0; index < _flowCount; index++)
        _flowName(index): [_variant],
    });

  final store = AtlasSnapshotStore(root.paths);

  for (int index = 0; index < _flowCount; index++) {
    root.writeFlow(_flowName(index), {
      'title': {
        'en': 'Browse the items of shelf $index',
        'uk': 'Переглянути товари полиці $index',
      },
      'variants': {
        _variant: {
          'title': {'en': 'Open an item', 'uk': 'Відкрити товар'},
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
    store.write(
      createAtlasSnapshot(
        flow: _flowName(index),
        variant: _variant,
        locale: 'uk',
        stages: const [
          AtlasStage(
            label: 'open',
            action: 'tap',
            journal: [],
            ok: true,
            target: {'by': 'valueKey', 'value': 'items.button.open'},
            block: null,
            targetRect: null,
            screen: 'items-route',
            designScreen: null,
            shot: _shot,
            error: null,
          ),
        ],
        end: const AtlasEnd(
          screen: 'items-route',
          designScreen: null,
          shot: _shot,
        ),
      ),
    );
  }
}

String _flowName(int index) {
  return 'shelf_${index}_flow';
}
