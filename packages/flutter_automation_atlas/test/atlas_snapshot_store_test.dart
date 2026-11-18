import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/test_atlas_root.dart';

final _snapshot = createAtlasSnapshot(
  flow: 'shop_flow',
  variant: 'shopFromExistingItem',
  ok: false,
  manifest: const {'lib/b.dart': '222222222222', 'lib/a.dart': '111111111111'},
  stages: const [
    AtlasStage(
      label: 'open cart details',
      action: 'tap',
      journal: [
        {'kind': 'request', 'path': '/carts/1', 'status': 200},
      ],
      ok: false,
      target: {'by': 'valueKey', 'value': 'cart_search.card'},
      block: 'quote_open_cart_details',
      targetRect: {'left': 0.05, 'top': 0.4, 'right': 0.95, 'bottom': 0.55},
      screen: 'carts-route',
      designScreen: 'home/buyer',
      shot: '0123456789ab',
      error: 'timed out',
    ),
  ],
  end: const AtlasEnd(
    screen: 'cart-details-route',
    designScreen: null,
    shot: 'ba9876543210',
  ),
);

final _uk = fakeAtlasLocales.first;
const _en = 'en';
final _enSnapshot = AtlasSnapshot(
  flow: _snapshot.flow,
  variant: _snapshot.variant,
  locale: _en,
  ok: true,
  device: _snapshot.device,
  defHash: _snapshot.defHash,
  manifest: _snapshot.manifest,
  stages: const [],
  end: _snapshot.end,
);

void main() {
  group('AtlasSnapshotStore Tests', () {
    _atlasSnapshotStore_should_writeKeysInContractOrder();
    _atlasSnapshotStore_should_rewriteReadSnapshotToSameBytes();
    _atlasSnapshotStore_should_readNothingForUncapturedVariant();
    _atlasSnapshotStore_should_readStageWithoutTargetRect();
    _atlasSnapshotStore_should_writeEachLocaleToItsOwnFile();
    _atlasSnapshotStore_should_readLocaleFromFileNameWhenJsonHasNone();
  });
}

void _atlasSnapshotStore_should_writeKeysInContractOrder() {
  test('AtlasSnapshotStore should write keys in contract order', () async {
    await TestAtlasRoot.run((root) {
      AtlasSnapshotStore(root.paths).write(_snapshot);

      final text = _readSnapshotText(root);

      expect(text, endsWith('}\n'));
      expect(text, contains('\n  "flow": "shop_flow",\n'));
      expect(
        RegExp(
          '"flow".*"variant".*"locale".*"ok".*"device".*"defHash".*"manifest".*'
          '"lib/a.dart".*"lib/b.dart".*"stages".*"label".*"action".*'
          '"target".*"block".*"targetRect".*"screen".*"designScreen".*"shot".*'
          '"journal".*'
          '"ok".*"error".*"end"',
          dotAll: true,
        ).hasMatch(text),
        isTrue,
      );
    });
  });
}

void _atlasSnapshotStore_should_rewriteReadSnapshotToSameBytes() {
  test(
    'AtlasSnapshotStore should rewrite read snapshot to same bytes',
    () async {
      await TestAtlasRoot.run((root) {
        final store = AtlasSnapshotStore(root.paths)..write(_snapshot);
        final written = _readSnapshotText(root);
        final read = store.tryRead(
          flow: 'shop_flow',
          variant: 'shopFromExistingItem',
          locale: _uk,
        );

        expect(read, isNotNull);

        if (read case final resolvedRead?) {
          store.write(resolvedRead);
          expect(
            resolvedRead.stages.single.target,
            _snapshot.stages.single.target,
          );
          expect(_readSnapshotText(root), written);
        }
      });
    },
  );
}

void _atlasSnapshotStore_should_readNothingForUncapturedVariant() {
  test(
    'AtlasSnapshotStore should read nothing for uncaptured variant',
    () async {
      await TestAtlasRoot.run((root) {
        final store = AtlasSnapshotStore(root.paths);
        final read = store.tryRead(
          flow: 'shop_flow',
          variant: 'unknown',
          locale: _uk,
        );

        expect(read, isNull);
        expect(store.readAll(locale: _uk), isEmpty);
        expect(store.readEveryLocale(), isEmpty);
      });
    },
  );
}

void _atlasSnapshotStore_should_readStageWithoutTargetRect() {
  test('AtlasSnapshotStore should read stage without target rect', () async {
    await TestAtlasRoot.run((root) {
      final store = AtlasSnapshotStore(root.paths);
      final stage = _snapshot.stages.single.toJson()..remove('targetRect');

      File(
          root.paths.resolveSnapshotPath(
            flow: 'shop_flow',
            variant: 'shopFromExistingItem',
            locale: _uk,
          ),
        )
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            ..._snapshot.toJson(),
            'stages': [stage],
          }),
        );

      final read = store.tryRead(
        flow: 'shop_flow',
        variant: 'shopFromExistingItem',
        locale: _uk,
      );

      expect(read?.stages.single.targetRect, isNull);
      expect(read?.stages.single.label, _snapshot.stages.single.label);
      expect(read?.stages.single.toJson(), stage);
    });
  });
}

void _atlasSnapshotStore_should_writeEachLocaleToItsOwnFile() {
  test('AtlasSnapshotStore should write each locale to its own file', () async {
    await TestAtlasRoot.run((root) {
      final store = AtlasSnapshotStore(root.paths)
        ..write(_snapshot)
        ..write(_enSnapshot);
      final enRead = store.tryRead(
        flow: 'shop_flow',
        variant: 'shopFromExistingItem',
        locale: _en,
      );

      expect(
        root.paths.resolveSnapshotPath(
          flow: 'shop_flow',
          variant: 'shopFromExistingItem',
          locale: _en,
        ),
        endsWith('data/shop_flow/shopFromExistingItem.en.json'),
      );
      expect(enRead?.locale, _en);
      expect(enRead?.ok, isTrue);
      expect(store.readAll(locale: _uk).map((read) => read.locale), [_uk]);
      expect(store.readAll(locale: _en).map((read) => read.locale), [_en]);
      expect(store.readEveryLocale().map((read) => read.locale), [_en, _uk]);
    });
  });
}

void _atlasSnapshotStore_should_readLocaleFromFileNameWhenJsonHasNone() {
  test('AtlasSnapshotStore should read locale from file name when json has '
      'none', () async {
    await TestAtlasRoot.run((root) {
      final store = AtlasSnapshotStore(root.paths);

      File(
          root.paths.resolveSnapshotPath(
            flow: 'shop_flow',
            variant: 'shopFromExistingItem',
            locale: _en,
          ),
        )
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(_snapshot.toJson()..remove('locale')));

      final read = store.tryRead(
        flow: 'shop_flow',
        variant: 'shopFromExistingItem',
        locale: _en,
      );

      expect(read?.locale, _en);
      expect(store.readAll(locale: _en), hasLength(1));
      expect(store.readAll(locale: _uk), isEmpty);
    });
  });
}

String _readSnapshotText(TestAtlasRoot root) {
  return File(
    root.paths.resolveSnapshotPath(
      flow: 'shop_flow',
      variant: 'shopFromExistingItem',
      locale: _uk,
    ),
  ).readAsStringSync();
}
