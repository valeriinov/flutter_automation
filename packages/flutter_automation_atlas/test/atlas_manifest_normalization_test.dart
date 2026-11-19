import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_manifest_normalization.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/test_atlas_root.dart';

const _flow = 'item_create';
const _variant = 'ownRoutePublished';
const _viewPath = 'lib/item_create_view.dart';
const _ownerPath = 'lib/item_create_owner.dart';
const _goneHash = '000000000000';
const _committedViewSource = "class ItemCreateView { final title = 'Нова'; }";
const _targetedViewSource = '''
import 'package:flutter_automation/flutter_automation.dart';

class ItemCreateView { final title = 'Нова'; }
''';
const _movedModulePath = 'lib/support/automation/automation_target.dart';
const _ownerSource = 'class ItemCreateOwner {}';

void main() {
  group('AtlasManifestNormalization Tests', () {
    _atlasManifestNormalization_should_normalizeHashOfCurrentFile();
    _atlasManifestNormalization_should_normalizeHashOfCommitted();
    _atlasManifestNormalization_should_dropGonePathOfMovedModule();
    _atlasManifestNormalization_should_keepAndReportUnresolvedHash();
    _atlasManifestNormalization_should_rewriteNothingOnSecondRun();
  });
}

void _atlasManifestNormalization_should_normalizeHashOfCurrentFile() {
  test(
    'AtlasManifestNormalization should normalize hash of current file',
    () async {
      await TestAtlasRoot.run((root) {
        _writeCommittedSources(root);
        _writeSnapshot(root, {_ownerPath: _hashRaw(_ownerSource)});

        final result = AtlasManifestNormalization(root.paths).run();

        expect(result.rewrittenSnapshots, 1);
        expect(_readSnapshot(root).manifest, {
          _ownerPath: testSourceHash.hashSource(_ownerSource),
        });
      });
    },
  );
}

void _atlasManifestNormalization_should_normalizeHashOfCommitted() {
  test(
    'AtlasManifestNormalization should normalize hash of committed',
    () async {
      await TestAtlasRoot.run((root) {
        _writeCommittedSources(root);
        root.writeSource(_viewPath, _targetedViewSource);
        _writeSnapshot(root, {_viewPath: _hashRaw(_committedViewSource)});
        AtlasManifestNormalization(root.paths).run();

        final snapshot = _readSnapshot(root);

        expect(snapshot.manifest, {
          _viewPath: testSourceHash.hashSource(_targetedViewSource),
        });
        expect(snapshot.stages.single.sources, snapshot.manifest);
      });
    },
  );
}

void _atlasManifestNormalization_should_dropGonePathOfMovedModule() {
  test(
    'AtlasManifestNormalization should drop gone path of moved module',
    () async {
      await TestAtlasRoot.run((root) {
        _writeCommittedSources(root);
        _writeSnapshot(root, {
          _ownerPath: _hashRaw(_ownerSource),
          _movedModulePath: _goneHash,
        });

        final result = AtlasManifestNormalization(root.paths).run();

        expect(result.unresolvedHashes, isEmpty);
        expect(_readSnapshot(root).manifest.keys, [_ownerPath]);
      });
    },
  );
}

void _atlasManifestNormalization_should_keepAndReportUnresolvedHash() {
  test(
    'AtlasManifestNormalization should keep and report unresolved hash',
    () async {
      await TestAtlasRoot.run((root) {
        _writeCommittedSources(root);
        _writeSnapshot(root, {_ownerPath: _goneHash});

        final result = AtlasManifestNormalization(root.paths).run();

        expect(result.rewrittenSnapshots, 0);
        expect(result.unresolvedHashes, ['$_ownerPath $_goneHash']);
        expect(_readSnapshot(root).manifest, {_ownerPath: _goneHash});
      });
    },
  );
}

void _atlasManifestNormalization_should_rewriteNothingOnSecondRun() {
  test(
    'AtlasManifestNormalization should rewrite nothing on second run',
    () async {
      await TestAtlasRoot.run((root) {
        _writeCommittedSources(root);
        _writeSnapshot(root, {
          _viewPath: _hashRaw(_committedViewSource),
          _ownerPath: _hashRaw(_ownerSource),
        });
        AtlasManifestNormalization(root.paths).run();

        final result = AtlasManifestNormalization(root.paths).run();

        expect(result.rewrittenSnapshots, 0);
        expect(result.unresolvedHashes, isEmpty);
      });
    },
  );
}

void _writeCommittedSources(TestAtlasRoot root) {
  root
    ..writeSource(_viewPath, _committedViewSource)
    ..writeSource(_ownerPath, _ownerSource);

  for (final args in [
    ['init', '--quiet'],
    ['add', '.'],
    [
      '-c',
      'user.name=Test',
      '-c',
      'user.email=test@example.com',
      'commit',
      '--quiet',
      '-m',
      'sources',
    ],
  ]) {
    Process.runSync('git', args, workingDirectory: root.directory.path);
  }
}

void _writeSnapshot(TestAtlasRoot root, Map<String, String> manifest) {
  AtlasSnapshotStore(root.paths).write(
    createAtlasSnapshot(
      flow: _flow,
      variant: _variant,
      manifest: manifest,
      stages: [
        AtlasStage(
          label: 'publish',
          action: 'tap',
          journal: const [],
          ok: true,
          target: null,
          block: null,
          targetRect: null,
          screen: null,
          designScreen: null,
          shot: null,
          error: null,
          sources: manifest,
        ),
      ],
    ),
  );
}

AtlasSnapshot _readSnapshot(TestAtlasRoot root) {
  final snapshot = AtlasSnapshotStore(
    root.paths,
  ).tryRead(flow: _flow, variant: _variant, locale: 'uk');

  return snapshot ?? fail('The snapshot is gone.');
}

String _hashRaw(String source) {
  return AtlasContentHash.hashBytes(utf8.encode(source));
}
