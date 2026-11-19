import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_declarations_store.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/read_test_declarations.dart';
import 'test_utils/test_atlas_root.dart';

const _referencedHash = '111111111111';
const _unreferencedHash = '222222222222';
const _source = 'class Carts {}';
const _recordWithoutFormat =
    '{"declarations":[{"key":"Carts","hash":"000000000000"}]}';
const _themeSource = '''
class UiSizesExt {
  final double gapLg;

  const UiSizesExt({required this.gapLg});
}
''';

void main() {
  group('AtlasDeclarationsStore Tests', () {
    _atlasDeclarationsStore_should_keepRecordsOutOfSnapshotsRead();
    _atlasDeclarationsStore_should_keepWrittenRecordUnchanged();
    _atlasDeclarationsStore_should_deleteOnlyUnreferencedRecords();
    _atlasDeclarationsStore_should_readHashesByDeclarationKey();
    _atlasDeclarationsStore_should_readNoHashesWithoutRecord();
    _atlasDeclarationsStore_should_readNoHashesFromRecordWithoutFormat();
    _atlasDeclarationsStore_should_rewriteRecordWithoutFormat();
  });
}

void _atlasDeclarationsStore_should_keepRecordsOutOfSnapshotsRead() {
  test(
    'AtlasDeclarationsStore should keep records out of snapshots read',
    () async {
      await TestAtlasRoot.run((root) {
        AtlasSnapshotStore(root.paths).write(
          createAtlasSnapshot(
            flow: 'shop_flow',
            variant: 'shopFromExistingItem',
            manifest: const {'lib/carts.dart': _referencedHash},
          ),
        );
        AtlasDeclarationsStore(
          root.paths,
        ).maybeWrite(sourceHash: _referencedHash, source: _source);

        final snapshots = AtlasSnapshotStore(root.paths).readEveryLocale();

        expect(
          File(
            root.paths.resolveDeclarationsPath(_referencedHash),
          ).existsSync(),
          isTrue,
        );
        expect(snapshots, hasLength(1));
      });
    },
  );
}

void _atlasDeclarationsStore_should_keepWrittenRecordUnchanged() {
  test('AtlasDeclarationsStore should keep written record unchanged', () async {
    await TestAtlasRoot.run((root) {
      final store = AtlasDeclarationsStore(root.paths)
        ..maybeWrite(sourceHash: _referencedHash, source: _source);
      final record = File(root.paths.resolveDeclarationsPath(_referencedHash));
      final written = record.readAsStringSync();

      store.maybeWrite(sourceHash: _referencedHash, source: 'class Items {}');
      expect(record.readAsStringSync(), written);
    });
  });
}

void _atlasDeclarationsStore_should_deleteOnlyUnreferencedRecords() {
  test(
    'AtlasDeclarationsStore should delete only unreferenced records',
    () async {
      await TestAtlasRoot.run((root) {
        final store = AtlasDeclarationsStore(root.paths)
          ..maybeWrite(sourceHash: _referencedHash, source: _source)
          ..maybeWrite(sourceHash: _unreferencedHash, source: _source);
        final deleted = store.deleteUnreferenced({_referencedHash});

        expect(deleted, ['$_unreferencedHash.json']);
        expect(
          File(
            root.paths.resolveDeclarationsPath(_referencedHash),
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            root.paths.resolveDeclarationsPath(_unreferencedHash),
          ).existsSync(),
          isFalse,
        );
      });
    },
  );
}

void _atlasDeclarationsStore_should_readHashesByDeclarationKey() {
  test(
    'AtlasDeclarationsStore should read hashes by declaration key',
    () async {
      await TestAtlasRoot.run((root) {
        final store = AtlasDeclarationsStore(root.paths)
          ..maybeWrite(sourceHash: _referencedHash, source: _themeSource);
        final hashes = store.tryReadHashes(_referencedHash);

        expect(hashes, {
          for (final declaration in readTestDeclarations(
            _themeSource,
          ).declarations)
            declaration.key: declaration.hash,
        });
        expect(hashes?.keys, contains('UiSizesExt.gapLg'));
        expect(
          _readRecordFieldNames(
            root.paths.resolveDeclarationsPath(_referencedHash),
          ),
          {'key', 'hash'},
        );
      });
    },
  );
}

void _atlasDeclarationsStore_should_readNoHashesWithoutRecord() {
  test('AtlasDeclarationsStore should read no hashes without record', () async {
    await TestAtlasRoot.run((root) {
      final hashes = AtlasDeclarationsStore(
        root.paths,
      ).tryReadHashes(_unreferencedHash);

      expect(hashes, isNull);
    });
  });
}

void _atlasDeclarationsStore_should_readNoHashesFromRecordWithoutFormat() {
  test(
    'AtlasDeclarationsStore should read no hashes from record without format',
    () async {
      await TestAtlasRoot.run((root) {
        _writeRecordWithoutFormat(root);

        final hashes = AtlasDeclarationsStore(
          root.paths,
        ).tryReadHashes(_referencedHash);

        expect(hashes, isNull);
      });
    },
  );
}

void _atlasDeclarationsStore_should_rewriteRecordWithoutFormat() {
  test('AtlasDeclarationsStore should rewrite record without format', () async {
    await TestAtlasRoot.run((root) {
      _writeRecordWithoutFormat(root);

      final hashes =
          (AtlasDeclarationsStore(root.paths)
                ..maybeWrite(sourceHash: _referencedHash, source: _source))
              .tryReadHashes(_referencedHash);

      expect(hashes, {
        'Carts': readTestDeclarations(_source).declarations.single.hash,
      });
    });
  });
}

void _writeRecordWithoutFormat(TestAtlasRoot root) {
  File(root.paths.resolveDeclarationsPath(_referencedHash))
    ..createSync(recursive: true)
    ..writeAsStringSync(_recordWithoutFormat);
}

Set<String> _readRecordFieldNames(String path) {
  final record = jsonDecode(File(path).readAsStringSync());
  final declarations = record is Map<String, Object?>
      ? record['declarations']
      : null;

  return {
    if (declarations is List<Object?>)
      for (final declaration in declarations.whereType<Map<String, Object?>>())
        ...declaration.keys,
  };
}
