import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_page_renderer.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_version_tags.dart';
import 'package:flutter_automation_atlas/src/atlas_versions.dart';

import 'test_utils/create_shot_snapshot.dart';
import 'test_utils/test_atlas_root.dart';
import 'test_utils/test_git.dart';

const _storeShot =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _firstLabel = 'v1';
const _secondLabel = 'v2';
const _firstPosition = 10;
const _secondPosition = 20;
const _thirdLabel = 'v3';
const _thirdPosition = 30;
const _firstTag = 'test-v1';
const _secondTag = 'test-v2';
const _sitePath = 'site/test';
const _liteSitePath = 'site/lite';
const _firstData = [0x1f, 0x8b, 1];
const _changedData = [0x1f, 0x8b, 2];
const _tagged = {'versionTagTemplate': 'test-{version}'};
const _untagged = {'keptVersions': 5};

void main() {
  group('AtlasVersionTags Tests', () {
    _atlasVersionTags_should_tagTheCommitThatAddedTheDataNotALaterChange();
    _atlasVersionTags_should_tagTheCommitThatLastAddedTheData();
    _atlasVersionTags_should_skipVersionOutsideTheMainBranch();
    _atlasVersionTags_should_skipTagThatOriginHolds();
    _atlasVersionTags_should_tagVersionOfTwoSitesOnce();
    _atlasVersionTags_should_giveNoTagWithoutVersionTagTemplate();
    _atlasVersionTags_should_createNoLocalTag();
    _atlasVersionTags_should_pushNothingWithoutTagToPut();
    _atlasVersionTags_should_refuseShallowClone();
  });
}

void _atlasVersionTags_should_tagTheCommitThatAddedTheDataNotALaterChange() {
  test('AtlasVersionTags should tag the commit that added the data not a '
      'later change', () async {
    await _runInRepository((root) {
      final path = root.directory.path;
      final site = _readSite(root, _sitePath, _tagged);

      _publishVersion(site, _firstLabel, _firstPosition);

      final firstCommit = commitTestGit(path, 'first version');

      _writeVersionData(site, _firstLabel, _changedData);
      commitTestGit(path, 'changed data');
      runTestGit(path, ['checkout', '--quiet', '-b', 'capture']);
      _publishVersion(site, _secondLabel, _secondPosition);

      final secondCommit = commitTestGit(path, 'second version');

      runTestGit(path, ['checkout', '--quiet', 'main']);
      runTestGit(path, ['merge', '--quiet', '--no-ff', 'capture']);
      pushTestGit(path, 'main');

      final tags = AtlasVersionTags(root.paths).run();

      expect(tags.map((tag) => tag.name), [_firstTag, _secondTag]);
      expect(tags.map((tag) => tag.commit), [firstCommit, secondCommit]);
      expect(_readOriginTags(path), {
        _firstTag: firstCommit,
        _secondTag: secondCommit,
      });
    });
  });
}

void _atlasVersionTags_should_tagTheCommitThatLastAddedTheData() {
  test(
    'AtlasVersionTags should tag the commit that last added the data',
    () async {
      await _runInRepository((root) {
        final path = root.directory.path;
        final site = _readSite(root, _sitePath, _tagged);

        _publishVersion(site, _firstLabel, _firstPosition);
        commitTestGit(path, 'first version');
        _resolveVersionDataFile(site, _firstLabel).deleteSync();
        commitTestGit(path, 'removed data');
        _writeVersionData(site, _firstLabel, _changedData);

        final secondCommit = commitTestGit(path, 'added data again');

        pushTestGit(path, 'main');

        final tags = AtlasVersionTags(root.paths).run();

        expect(tags.map((tag) => tag.commit), [secondCommit]);
        expect(_readOriginTags(path), {_firstTag: secondCommit});
      });
    },
  );
}

void _atlasVersionTags_should_skipVersionOutsideTheMainBranch() {
  test(
    'AtlasVersionTags should skip version outside the main branch',
    () async {
      await _runInRepository((root) {
        final path = root.directory.path;
        final site = _readSite(root, _sitePath, _tagged);

        _publishVersion(site, _firstLabel, _firstPosition);

        final firstCommit = commitTestGit(path, 'first version');

        pushTestGit(path, 'main');
        runTestGit(path, ['checkout', '--quiet', '-b', 'capture']);
        _publishVersion(site, _secondLabel, _secondPosition);
        commitTestGit(path, 'second version');
        pushTestGit(path, 'capture');
        _publishVersion(site, _thirdLabel, _thirdPosition);

        final tags = AtlasVersionTags(root.paths).run();

        expect(tags.map((tag) => tag.name), [_firstTag]);
        expect(_readOriginTags(path), {_firstTag: firstCommit});
      });
    },
  );
}

void _atlasVersionTags_should_skipTagThatOriginHolds() {
  test('AtlasVersionTags should skip tag that origin holds', () async {
    await _runInRepository((root) {
      final path = root.directory.path;
      final site = _readSite(root, _sitePath, _tagged);

      _publishVersion(site, _firstLabel, _firstPosition);
      commitTestGit(path, 'first version');
      runTestGit(path, ['commit', '--quiet', '--allow-empty', '-m', 'later']);
      pushTestGit(path, 'main');

      final laterCommit = runTestGit(path, ['rev-parse', 'HEAD']);

      runTestGit(path, ['tag', _firstTag]);
      pushTestGit(path, _firstTag);
      runTestGit(path, ['tag', '--delete', _firstTag]);

      final tags = AtlasVersionTags(root.paths).run();

      expect(tags, isEmpty);
      expect(_readOriginTags(path), {_firstTag: laterCommit});
    });
  });
}

void _atlasVersionTags_should_tagVersionOfTwoSitesOnce() {
  test('AtlasVersionTags should tag version of two sites once', () async {
    await _runInRepository((root) {
      final path = root.directory.path;

      _publishVersion(
        _readSite(root, _liteSitePath, _tagged),
        _firstLabel,
        _firstPosition,
      );

      final liteCommit = commitTestGit(path, 'lite site');

      _publishVersion(
        _readSite(root, _sitePath, _tagged),
        _firstLabel,
        _firstPosition,
      );
      commitTestGit(path, 'test site');
      pushTestGit(path, 'main');

      final tags = AtlasVersionTags(root.paths).run();

      expect(tags.map((tag) => tag.name), [_firstTag]);
      expect(_readOriginTags(path), {_firstTag: liteCommit});
    });
  });
}

void _atlasVersionTags_should_giveNoTagWithoutVersionTagTemplate() {
  test(
    'AtlasVersionTags should give no tag without version tag template',
    () async {
      await _runInRepository((root) {
        final path = root.directory.path;

        _publishVersion(
          _readSite(root, _sitePath, _untagged),
          _firstLabel,
          _firstPosition,
        );
        _publishVersion(
          _readSite(root, _liteSitePath, _tagged),
          _secondLabel,
          _secondPosition,
        );
        commitTestGit(path, 'versions');
        pushTestGit(path, 'main');

        final tags = AtlasVersionTags(root.paths).run();

        expect(tags.map((tag) => tag.name), [_secondTag]);
        expect(_readOriginTags(path).keys, [_secondTag]);
      });
    },
  );
}

void _atlasVersionTags_should_createNoLocalTag() {
  test('AtlasVersionTags should create no local tag', () async {
    await _runInRepository((root) {
      final path = root.directory.path;

      _publishVersion(
        _readSite(root, _sitePath, _tagged),
        _firstLabel,
        _firstPosition,
      );
      commitTestGit(path, 'first version');
      pushTestGit(path, 'main');

      final tags = AtlasVersionTags(root.paths).run();

      expect(tags.single.name, _firstTag);
      expect(_readOriginTags(path).keys, [_firstTag]);
      expect(runTestGit(path, ['tag', '--list']), isEmpty);
    });
  });
}

void _atlasVersionTags_should_pushNothingWithoutTagToPut() {
  test('AtlasVersionTags should push nothing without tag to put', () async {
    await _runInRepository((root) {
      final path = root.directory.path;
      final originMain = _readOriginMain(path);

      runTestGit(path, ['branch', '--set-upstream-to', 'origin/main']);
      runTestGit(path, ['commit', '--quiet', '--allow-empty', '-m', 'local']);

      final tags = AtlasVersionTags(root.paths).run();

      expect(tags, isEmpty);
      expect(_readOriginMain(path), originMain);
    });
  });
}

void _atlasVersionTags_should_refuseShallowClone() {
  test('AtlasVersionTags should refuse shallow clone', () async {
    await _runInRepository((root) {
      final path = root.directory.path;

      _publishVersion(
        _readSite(root, _sitePath, _tagged),
        _firstLabel,
        _firstPosition,
      );
      commitTestGit(path, 'first version');
      runTestGit(path, ['commit', '--quiet', '--allow-empty', '-m', 'later']);
      pushTestGit(path, 'main');

      final clone = TestAtlasRoot(
        Directory(
          cloneTestGit(
            'file://${_readOriginPath(path)}',
            options: ['--depth', '1'],
          ),
        ),
        root.project,
      );

      expect(
        runTestGit(clone.directory.path, [
          'rev-parse',
          '--is-shallow-repository',
        ]),
        'true',
      );
      expect(
        () => AtlasVersionTags(clone.paths).run(),
        throwsA(
          isA<AtlasException>().having(
            (exception) => exception.message,
            'message',
            contains('shallow clone'),
          ),
        ),
      );
      expect(_readOriginTags(path), isEmpty);
    });
  });
}

Future<void> _runInRepository(void Function(TestAtlasRoot root) body) {
  return TestAtlasRoot.run((root) {
    final path = root.directory.path;

    initTestGit(path);
    addTestGitOrigin(path);
    AtlasSnapshotStore(
      root.paths,
    ).write(createShotSnapshot(stageShot: _storeShot, endShot: null));
    commitTestGit(path, 'main');
    pushTestGit(path, 'main');
    body(root);
  });
}

AtlasVersions _readSite(
  TestAtlasRoot root,
  String sitePath,
  Map<String, Object?> config,
) {
  final site = AtlasVersions(p.join(root.directory.path, sitePath));

  root.writeText(
    p.join(site.sitePath, AtlasVersions.configFileName),
    jsonEncode(config),
  );

  return site;
}

void _publishVersion(AtlasVersions site, String label, int position) {
  site.publish(
    AtlasVersion(label: label, position: position, builtAt: ''),
    AtlasVersionRendering(
      page: '<html></html>',
      data: _firstData,
      shotUrlTemplate: 'https://shots.example/{shot}.png',
      builtAt: DateTime.utc(2026, 11, 21),
    ),
  );
}

void _writeVersionData(AtlasVersions site, String label, List<int> data) {
  _resolveVersionDataFile(site, label).writeAsBytesSync(data);
}

File _resolveVersionDataFile(AtlasVersions site, String label) {
  return File(
    p.join(site.resolveVersionPath(label), AtlasVersions.dataFileName),
  );
}

String _readOriginPath(String path) {
  return runTestGit(path, ['remote', 'get-url', 'origin']);
}

String _readOriginMain(String path) {
  return runTestGit(_readOriginPath(path), ['rev-parse', 'refs/heads/main']);
}

Map<String, String> _readOriginTags(String path) {
  final refs = runTestGit(path, ['ls-remote', '--tags', '--refs', 'origin']);

  return {
    for (final ref in const LineSplitter().convert(refs))
      ref.split('\t').last.replaceFirst('refs/tags/', ''): ref
          .split('\t')
          .first,
  };
}
