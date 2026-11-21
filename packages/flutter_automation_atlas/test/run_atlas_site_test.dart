import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_references.dart';
import 'package:flutter_automation_atlas/src/atlas_site_server.dart';
import 'package:flutter_automation_atlas/src/atlas_versions.dart';
import 'package:flutter_automation_atlas/src/run_atlas.dart';

import 'test_utils/fake_atlas_shot_storage.dart';
import 'test_utils/recording_stdout.dart';
import 'test_utils/test_atlas_root.dart';
import 'test_utils/test_git.dart';
import 'test_utils/write_shot_store.dart';

const _stageShot =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _endShot =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _laterStageShot =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _strandedShot =
    '432f17ef04f7432f17ef04f7432f17ef04f7432f17ef04f7432f17ef04f7432f';
const _firstLabel = 'v1.0.0b10_TEST';
const _secondLabel = 'v1.0.0b20_TEST';
const _sourceLabel = '1.0.0 (20)';
const _oldAge = Duration(days: 8);
const _movedUrlTemplate = 'https://moved.example/{shot}.png';
const _gzipMagic = [0x1f, 0x8b];

void main() {
  group('AtlasRun Site Tests', () {
    _atlasRun_should_writeSamePageBytesForVersionsOfOneTemplate();
    _atlasRun_should_writeVersionRowAndSettingsOfTheSite();
    _atlasRun_should_needShotThatOnlyVersionDataNames();
    _atlasRun_should_publishSiteThatTheServerHandsToThePage();
    _atlasRun_should_rejectPublishVersionWithoutItsOptions();
    _atlasRun_should_stopPublishVersionWithoutStorage();
    _atlasRun_should_rejectOpenWithoutSite();
    _atlasRun_should_pruneOnlyWithApply();
    _atlasRun_should_rejectPruneOfBothSingleParts();
  });
}

void _atlasRun_should_writeSamePageBytesForVersionsOfOneTemplate() {
  test(
    'AtlasRun should write same page bytes for versions of one template',
    () async {
      await _runInRepository((root, storage) async {
        await _publish(root, _firstLabel, position: '10');

        writeShotStore(root, stageShot: _laterStageShot, endShot: _endShot);

        await _publish(root, _secondLabel, position: '20');

        final firstPage = _readVersionFile(root, _firstLabel, 'index.html');
        final secondPage = _readVersionFile(root, _secondLabel, 'index.html');

        expect(firstPage, secondPage);
        expect(utf8.decode(firstPage), isNot(contains(_firstLabel)));
        expect(
          _readVersionData(root, _firstLabel),
          isNot(_readVersionData(root, _secondLabel)),
        );
      });
    },
  );
}

void _atlasRun_should_writeVersionRowAndSettingsOfTheSite() {
  test('AtlasRun should write version row and settings of the site', () async {
    await _runInRepository((root, storage) async {
      await _publish(root, _secondLabel, position: '20');
      await _publish(root, _firstLabel, position: '10');

      final versions = AtlasVersions(_resolveSitePath(root));
      final rows = versions.read();

      expect(rows.map((row) => row.label), [_firstLabel, _secondLabel]);
      expect(rows.map((row) => row.position), [10, 20]);
      expect(rows.first.sourceLabel, _sourceLabel);
      expect(DateTime.tryParse(rows.first.builtAt), isNotNull);
      expect(versions.readConfig(), {'shotUrlTemplate': storage.urlTemplate});
      expect(
        File(p.join(versions.sitePath, 'index.html')).readAsStringSync(),
        contains('./$_secondLabel/'),
      );
      expect(storage.uploads, isEmpty);
    });
  });
}

void _atlasRun_should_needShotThatOnlyVersionDataNames() {
  test('AtlasRun should need shot that only version data names', () async {
    await _runInRepository((root, storage) async {
      writeShotStore(root, stageShot: _laterStageShot, endShot: _endShot);

      await _publish(root, _firstLabel, position: '10');

      Directory(root.paths.dataPath).deleteSync(recursive: true);

      final shots = await AtlasShotReferences(root.paths.storePath).read();

      expect(shots, {_stageShot, _endShot, _laterStageShot});

      await expectLater(
        _runIn(root, ['delete-shots', _laterStageShot]),
        throwsA(isA<AtlasException>()),
      );

      expect(storage.deletions, isEmpty);
    });
  });
}

void _atlasRun_should_publishSiteThatTheServerHandsToThePage() {
  test(
    'AtlasRun should publish site that the server hands to the page',
    () async {
      await _runInRepository((root, storage) async {
        await _publish(root, _firstLabel, position: '10');
        await _publish(root, _secondLabel, position: '20');

        final sitePath = _resolveSitePath(root);

        final server = await AtlasSiteServer.start(sitePath);

        addTearDown(server.stop);

        final firstPage = server.resolvePageAddress(_firstLabel);
        final secondPage = server.resolvePageAddress(_secondLabel);
        final pages = [await _get(firstPage), await _get(secondPage)];

        final data = await _get(firstPage.resolve('./data.json.gz'));
        final versions = await _get(firstPage.resolve('../versions.json'));
        final config = await _get(firstPage.resolve('../atlas-config.json'));

        File(
          p.join(sitePath, AtlasVersions.configFileName),
        ).writeAsStringSync(jsonEncode({'shotUrlTemplate': _movedUrlTemplate}));
        File(
          p.join(sitePath, _secondLabel, AtlasVersions.dataFileName),
        ).deleteSync();

        final movedConfig = await _get(
          firstPage.resolve('../atlas-config.json'),
        );
        final lostData = await _get(secondPage.resolve('./data.json.gz'));

        expect(pages.map((page) => page.status), [
          HttpStatus.ok,
          HttpStatus.ok,
        ]);
        expect(pages.first.bytes, pages.last.bytes);
        expect(data.bytes.take(_gzipMagic.length), _gzipMagic);
        expect(
          jsonDecode(utf8.decode(gzip.decode(data.bytes))),
          containsPair('version', _firstLabel),
        );
        expect(
          (jsonDecode(utf8.decode(versions.bytes)) as List<Object?>).map(
            (row) => (row as Map<String, Object?>)['version'],
          ),
          [_firstLabel, _secondLabel],
        );
        expect(jsonDecode(utf8.decode(config.bytes)), {
          'shotUrlTemplate': storage.urlTemplate,
        });
        expect(jsonDecode(utf8.decode(movedConfig.bytes)), {
          'shotUrlTemplate': _movedUrlTemplate,
        });
        expect(movedConfig.cacheControl, 'no-store');
        expect(lostData.status, HttpStatus.notFound);
      });
    },
  );
}

void _atlasRun_should_rejectPublishVersionWithoutItsOptions() {
  test('AtlasRun should reject publish-version without its options', () async {
    await _runInRepository((root, storage) async {
      const options = {
        '--site': 'site/test',
        '--version': _firstLabel,
        '--position': '10',
        '--edition': 'full',
      };

      for (final missing in options.keys) {
        await expectLater(
          _runIn(root, [
            'publish-version',
            for (final MapEntry(key: option, :value) in options.entries)
              if (option != missing) ...[option, value],
          ]),
          throwsA(
            isA<AtlasException>().having(
              (error) => error.message,
              'message',
              startsWith('usage:'),
            ),
          ),
          reason: missing,
        );
      }

      await expectLater(
        _publish(root, _firstLabel, position: 'tenth'),
        throwsA(isA<AtlasException>()),
      );

      expect(Directory(_resolveSitePath(root)).existsSync(), isFalse);
    });
  });
}

void _atlasRun_should_stopPublishVersionWithoutStorage() {
  test('AtlasRun should stop publish-version without storage', () async {
    await _runInRepository((root, storage) async {
      root.project.storage = null;

      await expectLater(
        _publish(root, _firstLabel, position: '10'),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('shotStorage'),
          ),
        ),
      );

      expect(Directory(_resolveSitePath(root)).existsSync(), isFalse);
    });
  });
}

void _atlasRun_should_rejectOpenWithoutSite() {
  test('AtlasRun should reject open without site', () async {
    await TestAtlasRoot.run((root) async {
      await expectLater(
        _runIn(root, ['open', '--version', _firstLabel]),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            startsWith('usage:'),
          ),
        ),
      );
    });
  });
}

void _atlasRun_should_pruneOnlyWithApply() {
  test('AtlasRun should prune only with apply', () async {
    await _runInRepository((root, storage) async {
      storage.files[_strandedShot] = [1, 2, 3];
      storage.uploadTimes[_strandedShot] = DateTime.now().subtract(_oldAge);

      await _publish(root, _firstLabel, position: '10');

      final reportLines = await RecordingStdout.captureLines(
        () => _runIn(root, ['prune', '--site', _resolveSitePath(root)]),
      );

      expect(reportLines.first, contains(_strandedShot));
      expect(storage.deletions, isEmpty);

      await RecordingStdout.captureLines(
        () => _runIn(root, ['prune', '--storage-only', '--apply']),
      );

      expect(storage.deletions, [
        [_strandedShot],
      ]);
    });
  });
}

void _atlasRun_should_rejectPruneOfBothSingleParts() {
  test('AtlasRun should reject prune of both single parts', () async {
    await _runInRepository((root, storage) async {
      storage.files[_strandedShot] = [1, 2, 3];
      storage.uploadTimes[_strandedShot] = DateTime.now().subtract(_oldAge);

      await expectLater(
        _runIn(root, ['prune', '--repo-only', '--storage-only', '--apply']),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            startsWith('usage:'),
          ),
        ),
      );

      expect(storage.deletions, isEmpty);
    });
  });
}

Future<void> _runInRepository(
  Future<void> Function(TestAtlasRoot root, FakeAtlasShotStorage storage) body,
) {
  return TestAtlasRoot.run((root) async {
    final storage = await startFakeAtlasShotStorage(root);

    final path = root.directory.path;

    initTestGit(path);
    addTestGitOrigin(path);
    writeShotStore(root, stageShot: _stageShot, endShot: _endShot);
    commitTestGit(path, 'main');
    pushTestGit(path, 'main');

    await body(root, storage);
  });
}

Future<void> _publish(
  TestAtlasRoot root,
  String label, {
  required String position,
}) {
  return RecordingStdout.captureLines(
    () => _runIn(root, [
      'publish-version',
      '--site',
      _resolveSitePath(root),
      '--version',
      label,
      '--position',
      position,
      '--edition',
      'full',
      '--source-label',
      _sourceLabel,
    ]),
  );
}

Future<void> _runIn(TestAtlasRoot root, List<String> args) {
  return AtlasRun(args, root.project, rootPath: root.directory.path).run();
}

String _resolveSitePath(TestAtlasRoot root) {
  return p.join(root.directory.path, 'site', 'test');
}

List<int> _readVersionFile(TestAtlasRoot root, String label, String name) {
  return File(p.join(_resolveSitePath(root), label, name)).readAsBytesSync();
}

List<int> _readVersionData(TestAtlasRoot root, String label) {
  return _readVersionFile(root, label, AtlasVersions.dataFileName);
}

Future<({int status, String? cacheControl, List<int> bytes})> _get(
  Uri address,
) async {
  final client = HttpClient()..autoUncompress = false;

  try {
    final request = await client.getUrl(address);
    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      [],
      (all, chunk) => all..addAll(chunk),
    );

    return (
      status: response.statusCode,
      cacheControl: response.headers.value(HttpHeaders.cacheControlHeader),
      bytes: bytes,
    );
  } finally {
    client.close(force: true);
  }
}
