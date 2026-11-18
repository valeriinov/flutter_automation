import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_selection.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_source_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_check.dart';

import 'test_utils/add_test_headless_hashes.dart';
import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/test_atlas_root.dart';

const _flow = 'settings_atlas';
const _variant = 'profileOpened';
final _uk = fakeAtlasLocales.first;
const _en = 'en';
const _label = 'settings tab';
const _mainPath = 'lib/main.dart';
const _mainSource = 'void main() {}';
const _changedMainSource = 'void main() { runApp(); }';
const _otherRenderer = 'Flutter 3.41.0 · linux_x64';
const _endFrameHash = 'd4e5f6a1b2c3';
final _manifest = {_mainPath: AtlasSourceHash.hashSource(_mainSource)};

void main() {
  group('AtlasHeadlessSelection Tests', () {
    _atlasHeadlessSelection_should_selectStageCodeWithoutCurrent();
    _atlasHeadlessSelection_should_selectCodeWithReportOfOtherCode();
    _atlasHeadlessSelection_should_skipVariantWithCurrentReport();
    _atlasHeadlessSelection_should_skipStageCodeWithChangedTextKeys();
    _atlasHeadlessSelection_should_skipStageCodeWithMockDifference();
    _atlasHeadlessSelection_should_skipVariantInAnotherLocale();
    _atlasHeadlessSelection_should_skipSnapshotWithoutStageHashes();
    _atlasHeadlessSelection_should_skipSnapshotWithoutEndHash();
    _atlasHeadlessSelection_should_skipSnapshotOfAnotherRenderer();
  });
}

void _atlasHeadlessSelection_should_selectStageCodeWithoutCurrent() {
  test(
    'AtlasHeadlessSelection should select stage code without current',
    () async {
      await TestAtlasRoot.run((root) {
        final variant = _writeVariant(root);
        final isUncompared = AtlasHeadlessSelection(
          root.paths,
          _uk,
        ).isUncompared(_createStaleness(variant));

        expect(isUncompared, isTrue);
      });
    },
  );
}

void _atlasHeadlessSelection_should_selectCodeWithReportOfOtherCode() {
  test(
    'AtlasHeadlessSelection should select code with report of other code',
    () async {
      await TestAtlasRoot.run((root) {
        final variant = _writeVariant(root);

        _writeCurrentReport(root);
        root.writeSource(_mainPath, _changedMainSource);

        final selected = AtlasHeadlessSelection(
          root.paths,
          _uk,
        ).select([_createStaleness(variant, reason: AtlasStaleReason.code)]);

        expect(selected, [variant]);
      });
    },
  );
}

void _atlasHeadlessSelection_should_skipVariantWithCurrentReport() {
  test(
    'AtlasHeadlessSelection should skip variant with current report',
    () async {
      await TestAtlasRoot.run((root) {
        final variant = _writeVariant(root);

        _writeCurrentReport(root);

        final isUncompared = AtlasHeadlessSelection(
          root.paths,
          _uk,
        ).isUncompared(_createStaleness(variant));

        expect(isUncompared, isFalse);
      });
    },
  );
}

void _atlasHeadlessSelection_should_skipStageCodeWithChangedTextKeys() {
  test(
    'AtlasHeadlessSelection should skip stage code with changed locale keys',
    () async {
      await TestAtlasRoot.run((root) {
        final variant = _writeVariant(root);
        final isUncompared = AtlasHeadlessSelection(root.paths, _uk)
            .isUncompared(
              _createStaleness(variant, changedTranslationKeys: ['back']),
            );

        expect(isUncompared, isFalse);
      });
    },
  );
}

void _atlasHeadlessSelection_should_skipStageCodeWithMockDifference() {
  test(
    'AtlasHeadlessSelection should skip stage code with mock difference',
    () async {
      await TestAtlasRoot.run((root) {
        final variant = _writeVariant(root);
        final isUncompared = AtlasHeadlessSelection(root.paths, _uk)
            .isUncompared(
              _createStaleness(
                variant,
                mockDifference: 'GET /items/creation-limit answered 500',
              ),
            );

        expect(isUncompared, isFalse);
      });
    },
  );
}

void _atlasHeadlessSelection_should_skipVariantInAnotherLocale() {
  test(
    'AtlasHeadlessSelection should skip variant in another locale',
    () async {
      await TestAtlasRoot.run((root) {
        final variant = _writeVariant(root, locale: _en);
        final isUncompared = AtlasHeadlessSelection(
          root.paths,
          _en,
        ).isUncompared(_createStaleness(variant));

        expect(isUncompared, isFalse);
      });
    },
  );
}

void _atlasHeadlessSelection_should_skipSnapshotWithoutStageHashes() {
  test(
    'AtlasHeadlessSelection should skip snapshot without stage hashes',
    () async {
      await TestAtlasRoot.run((root) {
        final variant = _writeVariant(root, journalHashes: const [null]);
        final isUncompared = AtlasHeadlessSelection(
          root.paths,
          _uk,
        ).isUncompared(_createStaleness(variant));

        expect(isUncompared, isFalse);
      });
    },
  );
}

void _atlasHeadlessSelection_should_skipSnapshotWithoutEndHash() {
  test(
    'AtlasHeadlessSelection should skip snapshot without end hash',
    () async {
      await TestAtlasRoot.run((root) {
        final variant = _writeVariant(root, endFrameHash: null);
        final isUncompared = AtlasHeadlessSelection(
          root.paths,
          _uk,
        ).isUncompared(_createStaleness(variant));

        expect(isUncompared, isFalse);
      });
    },
  );
}

void _atlasHeadlessSelection_should_skipSnapshotOfAnotherRenderer() {
  test(
    'AtlasHeadlessSelection should skip snapshot of another renderer',
    () async {
      await TestAtlasRoot.run((root) {
        final variant = _writeVariant(root, renderer: _otherRenderer);
        final isUncompared = AtlasHeadlessSelection(
          root.paths,
          _uk,
        ).isUncompared(_createStaleness(variant));

        expect(isUncompared, isFalse);
      });
    },
  );
}

AtlasVariantDefinition _writeVariant(
  TestAtlasRoot root, {
  String? locale,
  List<String?>? journalHashes,
  String? endFrameHash = testHeadlessFrameHash,
  String? renderer,
}) {
  root
    ..writeFlow(_flow, {
      'variants': {
        _variant: {
          'items': [
            {
              'action': 'tap',
              'label': _label,
              'finder': {'by': 'text', 'value': _label},
            },
          ],
        },
      },
    })
    ..writeSource(_mainPath, _mainSource)
    ..writeFlutterConfig();

  AtlasSnapshotStore(root.paths).write(
    addTestHeadlessHashes(
      createAtlasSnapshot(
        flow: _flow,
        variant: _variant,
        locale: locale,
        manifest: _manifest,
        stages: const [
          AtlasStage(
            label: _label,
            action: 'tap',
            journal: [],
            ok: true,
            target: {'by': 'text', 'value': _label},
            block: null,
            targetRect: null,
            screen: null,
            designScreen: null,
            shot: null,
            error: null,
          ),
        ],
      ),
      journalHashes: journalHashes,
      endFrameHash: endFrameHash,
      renderer: renderer,
    ),
  );

  return AtlasDefinitions.read(root.paths).variants.single;
}

void _writeCurrentReport(TestAtlasRoot root) {
  root.writeHeadlessReport(
    AtlasHeadlessReport(
      frameHashes: const [testHeadlessFrameHash],
      endFrameHash: _endFrameHash,
      error: null,
      sourceHashes: _manifest,
    ),
    flow: _flow,
    variant: _variant,
  );
}

AtlasStaleness _createStaleness(
  AtlasVariantDefinition variant, {
  AtlasStaleReason reason = AtlasStaleReason.stageCode,
  List<String> changedTranslationKeys = const [],
  String? mockDifference,
}) {
  return AtlasStaleness(
    variant: variant,
    reason: reason,
    changedPaths: const [_mainPath],
    changedTranslationKeys: changedTranslationKeys,
    stages: const [0],
    attributedPaths: const {},
    mockDifference: mockDifference,
  );
}
