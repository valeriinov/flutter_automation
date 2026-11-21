import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';
import 'package:flutter_automation_atlas/src/atlas_locale_keys_table.dart';
import 'package:flutter_automation_atlas/src/atlas_page_renderer.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/test_atlas_root.dart';

const _tapStep = {
  'action': 'tap',
  'label': 'search',
  'finder': {'by': 'valueKey', 'value': 'item_search.button.search'},
};
const _listPath = 'tool/uncovered.json';
const _keyHash = 'abcdef012345';
const _dataPattern =
    r'<script type="application/json" id="atlas-data">(.*?)</script>';
const _metaPattern =
    r'<script type="application/json" id="atlas-meta">(.*?)</script>';

void main() {
  group('AtlasLocaleKeysTable Tests', () {
    _atlasLocaleKeysTable_should_listEveryTranslationKeyWithItsStatus();
    _atlasLocaleKeysTable_should_listUsagesByPatternInSortedFiles();
    _atlasLocaleKeysTable_should_listStagesOfUnpublishedSnapshotsToo();
    _atlasLocaleKeysTable_should_listNoUsagesWithoutPattern();
    _atlasLocaleKeysTable_should_failOnMissingList();
    _atlasLocaleKeysTable_should_holdNoKeysWithoutTranslations();
    _atlasPageRenderer_should_addTableOfProjectWithoutLocaleKeysTable();
    _atlasPageRenderer_should_keepLocaleKeysTableOfProject();
  });
}

void _atlasLocaleKeysTable_should_listEveryTranslationKeyWithItsStatus() {
  test('AtlasLocaleKeysTable should list every key with its status', () async {
    await TestAtlasRoot.runWith(project: _createProject(), (root) {
      _writeStore(root);
      root.writeText(
        p.join(root.paths.storePath, _listPath),
        jsonEncode({
          'shared': 'codeOnly',
          'legacy': {'reason': 'unused', 'place': 'Cart', 'widget': 'Badge'},
          'sent': 'unused',
        }),
      );

      final table = AtlasLocaleKeysTable(root.paths).build();

      expect(table.id, AtlasTable.localeKeysId);
      expect(table.rows.map((row) => row['key']), [
        'title',
        'hint',
        'shared',
        'legacy',
        'sent',
        'later',
      ]);
      expect(table.rows.map((row) => row['status']), [
        'onFrames',
        'onFrames',
        'codeOnly',
        'unused',
        'unused',
        'pending',
      ]);
      expect(table.rows[3]['place'], 'Cart');
      expect(table.rows[3]['widget'], 'Badge');
      expect(table.rows[4], isNot(contains('place')));
      expect(table.rows.first['stages'], {
        'item_search/itemsFound': [0],
      });
      expect(table.rows[1]['stages'], {
        'item_search/itemsFound': [1],
      });
    });
  });
}

void _atlasLocaleKeysTable_should_listUsagesByPatternInSortedFiles() {
  test('AtlasLocaleKeysTable should list usages by pattern', () async {
    await TestAtlasRoot.runWith(project: _createProject(), (root) {
      _writeStore(root);

      root
        ..writeSource(
          'lib/b.dart',
          'final a = Texts.title;\nfinal b = Texts.hint + Texts.title;\n',
        )
        ..writeSource('lib/a/c.dart', 'final c = Texts.title;')
        ..writeSource('lib/gen/texts.g.dart', 'final d = Texts.title;')
        ..writeSource('lib/notes.txt', 'Texts.title')
        ..writeSource('test/other.dart', 'final e = Texts.title;')
        ..writeText(p.join(root.paths.storePath, _listPath), '{}');

      final table = AtlasLocaleKeysTable(root.paths).build();

      expect(table.rows.first['usages'], [
        'lib/a/c.dart:1',
        'lib/b.dart:1',
        'lib/b.dart:2',
      ]);
      expect(table.rows[1]['usages'], ['lib/b.dart:2']);
      expect(table.rows.last['usages'], isEmpty);
    });
  });
}

void _atlasLocaleKeysTable_should_listStagesOfUnpublishedSnapshotsToo() {
  test('AtlasLocaleKeysTable should list stages of unpublished too', () async {
    await TestAtlasRoot.runWith(project: _createProject(), (root) {
      _writeStore(root);
      root.writeText(p.join(root.paths.storePath, _listPath), '{}');
      AtlasSnapshotStore(root.paths).write(
        createAtlasSnapshot(
          flow: 'item_search',
          variant: 'noItemsFound',
          stages: [
            _createStage({'later': _keyHash}),
          ],
        ),
      );

      final table = AtlasLocaleKeysTable(root.paths).build();
      final later = table.rows.last;

      expect(later['stages'], {
        'item_search/noItemsFound': [0],
      });
      expect(later['status'], 'pending');
    });
  });
}

void _atlasLocaleKeysTable_should_listNoUsagesWithoutPattern() {
  test('AtlasLocaleKeysTable should list no usages without pattern', () async {
    await TestAtlasRoot.runWith(project: _createProject(), (root) {
      _writeStore(root);

      root
        ..writeSource('lib/b.dart', 'final a = Texts.title;')
        ..writeText(p.join(root.paths.storePath, _listPath), '{}');

      root.project.usagePattern = null;

      final table = AtlasLocaleKeysTable(root.paths).build();

      expect(
        table.rows.every((row) => (row['usages'] as List).isEmpty),
        isTrue,
      );
    });
  });
}

void _atlasLocaleKeysTable_should_failOnMissingList() {
  test('AtlasLocaleKeysTable should fail on missing list', () async {
    await TestAtlasRoot.runWith(project: _createProject(), (root) {
      _writeStore(root);
      expect(
        AtlasLocaleKeysTable(root.paths).build,
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('No uncovered localization keys list'),
          ),
        ),
      );
    });
  });
}

void _atlasLocaleKeysTable_should_holdNoKeysWithoutTranslations() {
  test(
    'AtlasLocaleKeysTable should hold no keys without translations',
    () async {
      await TestAtlasRoot.run((root) {
        expect(AtlasLocaleKeysTable(root.paths).hasKeys, isFalse);
      });
    },
  );
}

void _atlasPageRenderer_should_addTableOfProjectWithoutLocaleKeysTable() {
  test('AtlasPageRenderer should add the built-in keys table', () async {
    await TestAtlasRoot.runWith(project: _createProject(), (root) async {
      _writeStore(root);
      root.writeText(p.join(root.paths.storePath, _listPath), '{}');

      final rendering = await AtlasPageRenderer(root.paths).build();

      final keys = _readScript(rendering.page, _dataPattern)['localeKeys'];
      final tables = _readScript(rendering.page, _metaPattern)['tables'];

      expect((keys as List<Object?>).length, 6);
      expect((keys.first as Map<String, Object?>)['key'], 'title');
      expect((tables as List<Object?>).length, 1);
    });
  });
}

void _atlasPageRenderer_should_keepLocaleKeysTableOfProject() {
  test('AtlasPageRenderer should keep the keys table of the project', () async {
    await TestAtlasRoot.runWith(project: _createProject(), (root) async {
      _writeStore(root);
      root.project.tablesToReturn.add(
        const AtlasTable(
          id: AtlasTable.localeKeysId,
          title: {'en': 'Own'},
          columns: [],
          rows: [
            {'key': 'own'},
          ],
        ),
      );

      final rendering = await AtlasPageRenderer(root.paths).build();

      final tables = _readScript(rendering.page, _metaPattern)['tables'];

      expect(_readScript(rendering.page, _dataPattern)['localeKeys'], [
        {'key': 'own'},
      ]);
      expect((tables as List<Object?>).length, 1);
    });
  });
}

FakeAtlasProject _createProject() {
  return FakeAtlasProject(
    pathsOverride: const AtlasPaths(
      runnerEntry: 'tool/run_flows.dart',
      output: 'atlas_store',
      build: 'build/atlas',
      recordings: 'assets/recordings',
      publishedVariants: 'scripts/published_variants.json',
      uncoveredLocaleKeys: _listPath,
    ),
  )..usagePattern = RegExp(r'\bTexts\.(\w+)');
}

void _writeStore(TestAtlasRoot root) {
  root
    ..writeTranslations('uk', {
      'title': 'Заголовок',
      'hint': 'Підказка',
      'shared': 'Спільне',
      'legacy': 'Старе',
      'sent': 'Надіслано',
      'later': 'Потім',
    })
    ..writeFlow('item_search', {
      'variants': {
        'itemsFound': {
          'items': [_tapStep],
        },
        'noItemsFound': {
          'items': [_tapStep],
        },
      },
    })
    ..writePublishedVariants({
      'item_search': ['itemsFound'],
    });

  AtlasSnapshotStore(root.paths).write(
    createAtlasSnapshot(
      flow: 'item_search',
      variant: 'itemsFound',
      stages: [
        _createStage({'title': _keyHash}),
        _createStage({'hint': _keyHash}),
      ],
    ),
  );
}

AtlasStage _createStage(Map<String, String> localeKeys) {
  return AtlasStage(
    label: 'search',
    action: 'tap',
    journal: const [],
    ok: true,
    target: null,
    block: null,
    targetRect: null,
    screen: 'search-route',
    designScreen: null,
    shot: null,
    error: null,
    localeKeys: localeKeys,
  );
}

Map<String, Object?> _readScript(String page, String pattern) {
  final match = RegExp(pattern, dotAll: true).firstMatch(page);

  return jsonDecode('${match?.group(1)}') as Map<String, Object?>;
}
