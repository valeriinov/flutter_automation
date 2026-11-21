import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_page_renderer.dart';
import 'package:flutter_automation_atlas/src/atlas_versions.dart';

import 'test_utils/test_git.dart';

const _firstLabel = 'v1.0.0b10_TEST';
const _secondLabel = 'v1.0.0b20_TEST';
const _firstPosition = 10;
const _secondPosition = 20;
const _earlierPosition = 5;
const _middlePosition = 15;
const _tagTemplate = 'atlas/{version}-site';
const _builtAt = '2026-11-21T10:00:00.000Z';
const _page = '<html>page</html>';
const _firstData = [0x1f, 0x8b, 1];
const _secondData = [0x1f, 0x8b, 2];
const _urlTemplate = 'https://shots.example/{shot}.png';
const _formerUrlTemplate = 'https://former.example/{shot}.png';
const _keptVersions = 5;

final _rendering = _createRendering(_firstData);

void main() {
  group('AtlasVersions Tests', () {
    _atlasVersions_should_refuseVersionFolderOnTheMainBranch();
    _atlasVersions_should_replaceVersionFolderBeforeTheMerge();
    _atlasVersions_should_putVersionWithSmallerPositionBeforeTheLast();
    _atlasVersions_should_keepOtherFieldsOfTheSettingsFile();
    _atlasVersions_should_rejectLabelThatIsNoFolderName();
    _atlasVersions_should_removeFolderAndRowOfAVersion();
    _atlasVersions_should_stopOnMalformedVersionsFile();
    _atlasVersions_should_stopOnVersionRowWhoseLabelIsNoFolderName();
    _atlasVersions_should_refuseToRemoveFolderOutsideTheSiteFolder();
    _atlasVersions_should_deleteSitePageWhenNoVersionStays();
    _atlasVersions_should_refuseVersionFolderThatOriginTookOnTheMainBranch();
    _atlasVersions_should_publishInRepositoryWithoutOrigin();
    _atlasVersions_should_publishWhenOriginHoldsNoMainBranch();
    _atlasVersions_should_stopWhenGitFailsOnTheMainBranch();
    _atlasVersions_should_keepEachPositionWithoutKeptVersions();
    _atlasVersions_should_keepPositionInsideTheLatestKeptVersions();
    _atlasVersions_should_notKeepPositionOutsideTheLatestKeptVersions();
    _atlasVersions_should_notCountRowOfTheSamePositionAsLater();
    _atlasVersions_should_stopOnMalformedKeptVersions();
    _atlasVersions_should_resolveTagOfAVersionByTheTemplate();
    _atlasVersions_should_readLabelOnlyOfATagOfTheTemplate();
    _atlasVersions_should_stopOnMalformedVersionTagTemplate();
  });
}

void _atlasVersions_should_refuseVersionFolderOnTheMainBranch() {
  test('AtlasVersions should refuse version folder on the main branch', () {
    _runInRepository((root, versions) {
      versions.publish(_createVersion(_firstLabel, _firstPosition), _rendering);
      commitTestGit(root, 'version');
      pushTestGit(root, 'main');
      expect(
        () => versions.publish(
          _createVersion(_firstLabel, _firstPosition),
          _createRendering(_secondData),
        ),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('origin/main'),
          ),
        ),
      );
      expect(_readData(versions, _firstLabel), _firstData);
    });
  });
}

void _atlasVersions_should_replaceVersionFolderBeforeTheMerge() {
  test('AtlasVersions should replace version folder before the merge', () {
    _runInRepository((root, versions) {
      final strayFile = File(
        p.join(versions.resolveVersionPath(_firstLabel), 'stray.txt'),
      );

      versions.publish(_createVersion(_firstLabel, _firstPosition), _rendering);
      strayFile.writeAsStringSync('stray');
      runTestGit(root, ['checkout', '--quiet', '-b', 'capture']);
      commitTestGit(root, 'version');
      pushTestGit(root, 'capture');
      versions.publish(
        _createVersion(_firstLabel, _firstPosition),
        _createRendering(_secondData),
      );
      expect(_readData(versions, _firstLabel), _secondData);
      expect(strayFile.existsSync(), isFalse);
      expect(versions.read().map((version) => version.label), [_firstLabel]);
    });
  });
}

void _atlasVersions_should_putVersionWithSmallerPositionBeforeTheLast() {
  test(
    'AtlasVersions should put version with smaller position before the last',
    () {
      _runInRepository((root, versions) {
        versions
          ..publish(_createVersion(_secondLabel, _secondPosition), _rendering)
          ..publish(_createVersion(_firstLabel, _firstPosition), _rendering);

        final rows = jsonDecode(
          File(p.join(versions.sitePath, 'versions.json')).readAsStringSync(),
        );

        expect(rows, [
          {
            'version': _firstLabel,
            'position': _firstPosition,
            'builtAt': _builtAt,
          },
          {
            'version': _secondLabel,
            'position': _secondPosition,
            'builtAt': _builtAt,
          },
        ]);
        expect(
          File(p.join(versions.sitePath, 'index.html')).readAsStringSync(),
          allOf(contains('./$_secondLabel/'), isNot(contains(_firstLabel))),
        );
      });
    },
  );
}

void _atlasVersions_should_keepOtherFieldsOfTheSettingsFile() {
  test('AtlasVersions should keep other fields of the settings file', () {
    _runInRepository((root, versions) {
      File(p.join(versions.sitePath, AtlasVersions.configFileName))
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            'keptVersions': _keptVersions,
            'shotUrlTemplate': _formerUrlTemplate,
          }),
        );

      versions.publish(_createVersion(_firstLabel, _firstPosition), _rendering);
      expect(versions.readConfig(), {
        'keptVersions': _keptVersions,
        'shotUrlTemplate': _urlTemplate,
      });
    });
  });
}

void _atlasVersions_should_rejectLabelThatIsNoFolderName() {
  test('AtlasVersions should reject label that is no folder name', () {
    _runInRepository((root, versions) {
      for (final label in ['../outside', 'a/b', '', '.hidden']) {
        expect(
          () => versions.publish(
            _createVersion(label, _firstPosition),
            _rendering,
          ),
          throwsA(isA<AtlasException>()),
        );
      }

      expect(Directory(versions.sitePath).existsSync(), isFalse);
    });
  });
}

void _atlasVersions_should_removeFolderAndRowOfAVersion() {
  test('AtlasVersions should remove folder and row of a version', () {
    _runInRepository((root, versions) {
      versions
        ..publish(_createVersion(_firstLabel, _firstPosition), _rendering)
        ..publish(_createVersion(_secondLabel, _secondPosition), _rendering)
        ..remove([_secondLabel]);

      expect(
        Directory(versions.resolveVersionPath(_secondLabel)).existsSync(),
        isFalse,
      );
      expect(versions.read().map((version) => version.label), [_firstLabel]);
      expect(
        File(p.join(versions.sitePath, 'index.html')).readAsStringSync(),
        contains('./$_firstLabel/'),
      );
    });
  });
}

void _atlasVersions_should_stopOnMalformedVersionsFile() {
  test('AtlasVersions should stop on malformed versions file', () {
    _runInRepository((root, versions) {
      File(p.join(versions.sitePath, 'versions.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync('{"version": "$_firstLabel"}');

      expect(versions.read, throwsA(isA<AtlasException>()));
    });
  });
}

void _atlasVersions_should_stopOnVersionRowWhoseLabelIsNoFolderName() {
  test(
    'AtlasVersions should stop on version row whose label is no folder name',
    () {
      _runInRepository((root, versions) {
        for (final label in ['', '..', root]) {
          File(p.join(versions.sitePath, 'versions.json'))
            ..createSync(recursive: true)
            ..writeAsStringSync(
              jsonEncode([
                {'version': label, 'position': _firstPosition},
              ]),
            );

          expect(versions.read, throwsA(isA<AtlasException>()), reason: label);
        }
      });
    },
  );
}

void _atlasVersions_should_refuseToRemoveFolderOutsideTheSiteFolder() {
  test(
    'AtlasVersions should refuse to remove folder outside the site folder',
    () {
      _runInRepository((root, versions) {
        versions.publish(
          _createVersion(_firstLabel, _firstPosition),
          _rendering,
        );

        for (final label in ['', '..', root]) {
          expect(
            () => versions.remove([label]),
            throwsA(isA<AtlasException>()),
            reason: label,
          );
        }

        expect(_readData(versions, _firstLabel), _firstData);
        expect(File(p.join(root, 'README.md')).existsSync(), isTrue);
      });
    },
  );
}

void _atlasVersions_should_deleteSitePageWhenNoVersionStays() {
  test('AtlasVersions should delete site page when no version stays', () {
    _runInRepository((root, versions) {
      versions
        ..publish(_createVersion(_firstLabel, _firstPosition), _rendering)
        ..remove([_firstLabel]);

      expect(versions.read(), isEmpty);
      expect(
        File(p.join(versions.sitePath, 'index.html')).existsSync(),
        isFalse,
      );
    });
  });
}

void _atlasVersions_should_refuseVersionFolderThatOriginTookOnTheMainBranch() {
  test('AtlasVersions should refuse version folder that origin took on the '
      'main branch', () {
    _runInRepository((root, versions) {
      final clone = cloneTestGit(
        runTestGit(root, ['remote', 'get-url', 'origin']),
      );

      AtlasVersions(
        p.join(clone, 'site', 'test'),
      ).publish(_createVersion(_firstLabel, _firstPosition), _rendering);
      commitTestGit(clone, 'version');
      pushTestGit(clone, 'main');
      expect(
        () => versions.publish(
          _createVersion(_firstLabel, _firstPosition),
          _createRendering(_secondData),
        ),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            contains('origin/main'),
          ),
        ),
      );
      expect(
        Directory(versions.resolveVersionPath(_firstLabel)).existsSync(),
        isFalse,
      );
    });
  });
}

void _atlasVersions_should_publishInRepositoryWithoutOrigin() {
  test('AtlasVersions should publish in repository without origin', () {
    _runInRepository(hasOrigin: false, (root, versions) {
      versions.publish(_createVersion(_firstLabel, _firstPosition), _rendering);
      expect(_readData(versions, _firstLabel), _firstData);
    });
  });
}

void _atlasVersions_should_publishWhenOriginHoldsNoMainBranch() {
  test('AtlasVersions should publish when origin holds no main branch', () {
    _runInRepository(hasOrigin: false, (root, versions) {
      addTestGitOrigin(root);
      versions.publish(_createVersion(_firstLabel, _firstPosition), _rendering);
      expect(_readData(versions, _firstLabel), _firstData);
    });
  });
}

void _atlasVersions_should_stopWhenGitFailsOnTheMainBranch() {
  test('AtlasVersions should stop when git fails on the main branch', () {
    final directory = Directory.systemTemp.createTempSync('atlas-versions-');
    final versions = AtlasVersions(p.join(directory.path, 'site', 'test'));

    addTearDown(() => directory.deleteSync(recursive: true));
    File(
      p.join(directory.path, '.git'),
    ).writeAsStringSync('gitdir: ${p.join(directory.path, 'no-repository')}');
    expect(
      () => versions.publish(
        _createVersion(_firstLabel, _firstPosition),
        _rendering,
      ),
      throwsA(isA<AtlasException>()),
    );
    expect(() => versions.hasMainBranch, throwsA(isA<AtlasException>()));
    expect(Directory(versions.sitePath).existsSync(), isFalse);
  });
}

void _atlasVersions_should_keepEachPositionWithoutKeptVersions() {
  test('AtlasVersions should keep each position without kept versions', () {
    _runInRepository((root, versions) {
      _publishTwoVersions(versions);

      final keepsPosition = versions.keepsPosition(_earlierPosition);

      expect(versions.readKeptVersions(), isNull);
      expect(keepsPosition, isTrue);
    });
  });
}

void _atlasVersions_should_keepPositionInsideTheLatestKeptVersions() {
  test(
    'AtlasVersions should keep position inside the latest kept versions',
    () {
      _runInRepository((root, versions) {
        _publishTwoVersions(versions);
        _writeConfig(versions, const {'keptVersions': 2});

        final keepsPosition = versions.keepsPosition(_middlePosition);

        expect(versions.readKeptVersions(), 2);
        expect(keepsPosition, isTrue);
      });
    },
  );
}

void _atlasVersions_should_notKeepPositionOutsideTheLatestKeptVersions() {
  test(
    'AtlasVersions should not keep position outside the latest kept versions',
    () {
      _runInRepository((root, versions) {
        _publishTwoVersions(versions);
        _writeConfig(versions, const {'keptVersions': 2});

        final keepsPosition = versions.keepsPosition(_earlierPosition);

        expect(keepsPosition, isFalse);
      });
    },
  );
}

void _atlasVersions_should_notCountRowOfTheSamePositionAsLater() {
  test('AtlasVersions should not count row of the same position as later', () {
    _runInRepository((root, versions) {
      _publishTwoVersions(versions);
      _writeConfig(versions, const {'keptVersions': 1});

      final keepsLatest = versions.keepsPosition(_secondPosition);
      final keepsFirst = versions.keepsPosition(_firstPosition);

      expect(keepsLatest, isTrue);
      expect(keepsFirst, isFalse);
    });
  });
}

void _atlasVersions_should_stopOnMalformedKeptVersions() {
  test('AtlasVersions should stop on malformed kept versions', () {
    _runInRepository((root, versions) {
      for (final keptVersions in [0, -1, '2', 1.5]) {
        _writeConfig(versions, {'keptVersions': keptVersions});
        expect(
          versions.readKeptVersions,
          throwsA(
            isA<AtlasException>().having(
              (error) => error.message,
              'message',
              '"keptVersions" of ${versions.sitePath} is not a whole number '
                  'above zero.',
            ),
          ),
          reason: '$keptVersions',
        );
        expect(
          () => versions.keepsPosition(_firstPosition),
          throwsA(isA<AtlasException>()),
          reason: '$keptVersions',
        );
      }
    });
  });
}

void _atlasVersions_should_resolveTagOfAVersionByTheTemplate() {
  test('AtlasVersions should resolve tag of a version by the template', () {
    _runInRepository((root, versions) {
      final untagged = versions.resolveVersionTag(_firstLabel);

      _writeConfig(versions, const {'versionTagTemplate': _tagTemplate});

      final tag = versions.resolveVersionTag(_firstLabel);

      expect(untagged, isNull);
      expect(tag, 'atlas/$_firstLabel-site');
      expect(versions.hasVersionTagTemplate, isTrue);
    });
  });
}

void _atlasVersions_should_readLabelOnlyOfATagOfTheTemplate() {
  test('AtlasVersions should read label only of a tag of the template', () {
    _runInRepository((root, versions) {
      final untagged = versions.tryReadTaggedLabel('atlas/$_firstLabel-site');

      _writeConfig(versions, const {'versionTagTemplate': _tagTemplate});

      final label = versions.tryReadTaggedLabel('atlas/$_firstLabel-site');
      final otherLabel = versions.tryReadTaggedLabel('other/$_firstLabel-site');
      final wholeTagLabel = versions.tryReadTaggedLabel(
        'xatlas/$_firstLabel-site',
      );
      final folderLabel = versions.tryReadTaggedLabel('atlas/a/b-site');

      expect(untagged, isNull);
      expect(versions.hasVersionTagTemplate, isTrue);
      expect(label, _firstLabel);
      expect(otherLabel, isNull);
      expect(wholeTagLabel, isNull);
      expect(folderLabel, isNull);
    });
  });
}

void _atlasVersions_should_stopOnMalformedVersionTagTemplate() {
  test('AtlasVersions should stop on malformed version tag template', () {
    _runInRepository((root, versions) {
      for (final tagTemplate in ['atlas-version', 1]) {
        _writeConfig(versions, {'versionTagTemplate': tagTemplate});

        final matcher = throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            '"versionTagTemplate" of ${versions.sitePath} is not a text with '
                '{version}.',
          ),
        );

        expect(
          () => versions.resolveVersionTag(_firstLabel),
          matcher,
          reason: '$tagTemplate',
        );
        expect(
          () => versions.tryReadTaggedLabel(_firstLabel),
          matcher,
          reason: '$tagTemplate',
        );
        expect(
          () => versions.hasVersionTagTemplate,
          matcher,
          reason: '$tagTemplate',
        );
      }
    });
  });
}

void _publishTwoVersions(AtlasVersions versions) {
  versions.publish(_createVersion(_firstLabel, _firstPosition), _rendering);
  versions.publish(_createVersion(_secondLabel, _secondPosition), _rendering);
}

void _writeConfig(AtlasVersions versions, Map<String, Object?> config) {
  File(p.join(versions.sitePath, AtlasVersions.configFileName))
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(config));
}

void _runInRepository(
  void Function(String root, AtlasVersions versions) body, {
  bool hasOrigin = true,
}) {
  final directory = Directory.systemTemp.createTempSync('atlas-versions-');

  try {
    final root = directory.resolveSymbolicLinksSync();

    initTestGit(root);
    File(p.join(root, 'README.md')).writeAsStringSync('atlas');
    commitTestGit(root, 'main');

    if (hasOrigin) {
      addTestGitOrigin(root);
      pushTestGit(root, 'main');
    }

    body(root, AtlasVersions(p.join(root, 'site', 'test')));
  } finally {
    directory.deleteSync(recursive: true);
  }
}

AtlasVersion _createVersion(String label, int position) {
  return AtlasVersion(label: label, position: position, builtAt: _builtAt);
}

AtlasVersionRendering _createRendering(List<int> data) {
  return AtlasVersionRendering(
    page: _page,
    data: data,
    shotUrlTemplate: _urlTemplate,
    builtAt: DateTime.utc(2026, 11, 21, 10),
  );
}

List<int> _readData(AtlasVersions versions, String label) {
  return File(
    p.join(versions.resolveVersionPath(label), AtlasVersions.dataFileName),
  ).readAsBytesSync();
}
