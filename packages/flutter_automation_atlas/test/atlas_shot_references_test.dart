import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_references.dart';

import 'test_utils/test_git.dart';

const _testShot =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _prodShot =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _branchShot =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _linkedShot =
    '4444444444444444444444444444444444444444444444444444444444444444';
const _packedShot =
    '5555555555555555555555555555555555555555555555555555555555555555';
const _plainShot =
    '6666666666666666666666666666666666666666666666666666666666666666';
const _shortShot = '0123456789ab';

void main() {
  group('AtlasShotReferences Tests', () {
    _atlasShotReferences_should_readSnapshotsOfEachStoreFolder();
    _atlasShotReferences_should_readFilesOfARemoteBranch();
    _atlasShotReferences_should_readLinksAndPackedDataOfAPage();
    _atlasShotReferences_should_readPlainDataOfAPage();
    _atlasShotReferences_should_stopOnRepositoryNamingNoShot();
    _atlasShotReferences_should_readFolderOutsideARepository();
    _atlasShotReferences_should_stopOnRepositoryThatGitDoesNotRead();
  });
}

void _atlasShotReferences_should_readSnapshotsOfEachStoreFolder() {
  test(
    'AtlasShotReferences should read snapshots of each store folder',
    () async {
      await _runInRepository((root) async {
        _writeSnapshot(root, 'test/data/flow/a.uk.json', _testShot);
        _writeSnapshot(root, 'prod/data/flow/a.uk.json', _prodShot);
        _writeSnapshot(root, 'test/data/flow/b.uk.json', _shortShot);

        final shots = await AtlasShotReferences(p.join(root, 'test')).read();

        expect(shots, {_testShot, _prodShot});
      });
    },
  );
}

void _atlasShotReferences_should_readFilesOfARemoteBranch() {
  test('AtlasShotReferences should read files of a remote branch', () async {
    await _runInRepository((root) async {
      _writeSnapshot(root, 'test/data/flow/a.uk.json', _testShot);
      commitTestGit(root, 'main');
      _writeSnapshot(root, 'test/data/flow/a.uk.json', _branchShot);

      final branchCommit = commitTestGit(root, 'capture');

      runTestGit(root, [
        'update-ref',
        'refs/remotes/origin/capture',
        branchCommit,
      ]);
      runTestGit(root, ['reset', '--quiet', '--hard', 'HEAD~1']);

      final shots = await AtlasShotReferences(p.join(root, 'test')).read();

      expect(shots, {_testShot, _branchShot});
    });
  });
}

void _atlasShotReferences_should_readLinksAndPackedDataOfAPage() {
  test(
    'AtlasShotReferences should read links and packed data of a page',
    () async {
      await _runInRepository((root) async {
        _writeFile(
          root,
          'site/test/index.html',
          _buildPage(
            data: jsonEncode(
              base64Encode(gzip.encode(utf8.encode(_encodeFlows(_packedShot)))),
            ),
            shots: jsonEncode({
              'shotUrls': {
                _shortShot: 'https://shots.example/files/$_linkedShot.png',
              },
            }),
          ),
        );

        final shots = await AtlasShotReferences(root).read();

        expect(shots, {_linkedShot, _packedShot});
      });
    },
  );
}

void _atlasShotReferences_should_readPlainDataOfAPage() {
  test('AtlasShotReferences should read plain data of a page', () async {
    await _runInRepository((root) async {
      _writeFile(
        root,
        'test/index.html',
        _buildPage(data: _encodeFlows(_plainShot), shots: '{}'),
      );

      final shots = await AtlasShotReferences(root).read();

      expect(shots, {_plainShot});
    });
  });
}

void _atlasShotReferences_should_stopOnRepositoryNamingNoShot() {
  test(
    'AtlasShotReferences should stop on repository naming no shot',
    () async {
      await _runInRepository((root) async {
        _writeSnapshot(root, 'test/data/flow/a.uk.json', _shortShot);

        await expectLater(
          AtlasShotReferences(root).read(),
          throwsA(isA<AtlasException>()),
        );
      });
    },
  );
}

void _atlasShotReferences_should_readFolderOutsideARepository() {
  test('AtlasShotReferences should read folder outside a repository', () async {
    final directory = await Directory.systemTemp.createTemp('atlas-shots-');

    addTearDown(() => directory.delete(recursive: true));
    _writeSnapshot(directory.path, 'data/flow/a.uk.json', _testShot);

    final shots = await AtlasShotReferences(directory.path).read();

    expect(shots, {_testShot});
  });
}

void _atlasShotReferences_should_stopOnRepositoryThatGitDoesNotRead() {
  test(
    'AtlasShotReferences should stop on repository that git does not read',
    () async {
      final directory = await Directory.systemTemp.createTemp('atlas-shots-');

      addTearDown(() => directory.delete(recursive: true));
      _writeFile(directory.path, '.git', 'gitdir: /nowhere');
      _writeSnapshot(directory.path, 'test/data/flow/a.uk.json', _testShot);

      await expectLater(
        AtlasShotReferences(p.join(directory.path, 'test')).read(),
        throwsA(isA<AtlasException>()),
      );
    },
  );
}

Future<void> _runInRepository(Future<void> Function(String root) body) async {
  final directory = await Directory.systemTemp.createTemp('atlas-shots-');

  try {
    runTestGit(directory.path, ['init', '--quiet', '--initial-branch', 'main']);

    await body(directory.resolveSymbolicLinksSync());
  } finally {
    await directory.delete(recursive: true);
  }
}

void _writeSnapshot(String root, String path, String shot) {
  _writeFile(
    root,
    path,
    const JsonEncoder.withIndent('  ').convert({
      'stages': [
        {'label': 'open', 'shot': shot},
      ],
      'end': {'shot': null},
    }),
  );
}

void _writeFile(String root, String path, String content) {
  File(p.join(root, path))
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}

String _encodeFlows(String shot) {
  return jsonEncode({
    'flows': [
      {
        'variants': [
          {
            'stages': [
              {'shot': shot},
            ],
          },
        ],
      },
    ],
  });
}

String _buildPage({required String data, required String shots}) {
  return '<html><script type="application/json" id="atlas-data">$data'
      '</script><script type="application/json" id="atlas-shots">$shots'
      '</script></html>';
}
