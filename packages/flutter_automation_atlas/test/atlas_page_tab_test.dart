import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_page_renderer.dart';

import 'test_utils/headless_chrome.dart';
import 'test_utils/test_atlas_root.dart';

const _iconPath = 'tool/icon.png';
// A PNG of one transparent pixel.
const _iconBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==';
const _bareAtlasPubspec = '''
name: sample
flutter_automation:
  defaultLocale: uk
''';
const _titledPubspec =
    '''
name: sample
flutter_automation:
  defaultLocale: uk
  atlas:
    icon: $_iconPath
    editions:
      full:
        title: {en: Team atlas, uk: Атлас команди}
''';
const _readTab = '''
new Promise((resolve) => {
  const check = () => {
    const icon = document.querySelector('link[rel="icon"]');
    if (!icon) { setTimeout(check, 50); return; }
    resolve({
      title: document.title,
      heading: document.querySelector('h1').innerText.trim(),
      icon: icon.getAttribute('href'),
    });
  };
  check();
})
''';
const _switchToUk =
    "document.querySelector('#lang-uk').click();"
    'new Promise((resolve) => setTimeout(resolve, 100))';

void main() {
  group('Atlas Page Tab Tests', () {
    _atlasPage_should_drawIconAndShowOwnTitleWithoutSettings();
    _atlasPage_should_showTitleAndIconOfTheEdition();
  });
}

void _atlasPage_should_drawIconAndShowOwnTitleWithoutSettings() {
  test(
    'AtlasPage should draw icon and show own title without settings',
    () async {
      await _withPage(_bareAtlasPubspec, (chrome) async {
        final tab = await chrome.evaluate(_readTab) as Map;

        expect(tab['title'], endsWith(' · Screen flows'));
        expect(tab['heading'], 'Screen flows');
        expect(tab['icon'], startsWith('data:image/png;base64,'));
        expect(tab['icon'], isNot(contains(_iconBase64)));
      });
    },
    skip: _resolveSkip(),
  );
}

void _atlasPage_should_showTitleAndIconOfTheEdition() {
  test('AtlasPage should show title and icon of the edition', () async {
    await _withPage(_titledPubspec, (chrome) async {
      final english = await chrome.evaluate(_readTab) as Map;

      await chrome.evaluate(_switchToUk);

      final ukrainian = await chrome.evaluate(_readTab) as Map;

      expect(english['title'], endsWith(' · Team atlas'));
      expect(english['heading'], 'Team atlas');
      expect(english['icon'], 'data:image/png;base64,$_iconBase64');
      expect(ukrainian['title'], endsWith(' · Атлас команди'));
      expect(ukrainian['heading'], 'Атлас команди');
    });
  }, skip: _resolveSkip());
}

Object _resolveSkip() {
  return tryFindChrome() == null ? 'Chrome is not installed' : false;
}

Future<void> _withPage(
  String pubspec,
  Future<void> Function(HeadlessChrome chrome) body,
) {
  return TestAtlasRoot.run((root) async {
    root
      ..writeSource('pubspec.yaml', pubspec)
      ..writePublishedVariants(const {})
      ..writeTranslations('uk', const {})
      ..writeTranslations('en', const {});

    File(root.paths.resolve(_iconPath))
      ..createSync(recursive: true)
      ..writeAsBytesSync(base64Decode(_iconBase64));

    await AtlasPageRenderer(root.paths).render();

    final chrome = await HeadlessChrome.open(
      tryFindChrome() ?? '',
      File(root.paths.pagePath).uri,
    );

    try {
      await body(chrome);
    } finally {
      await chrome.close();
    }
  });
}
