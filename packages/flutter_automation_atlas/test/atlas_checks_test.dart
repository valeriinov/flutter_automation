import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';
import 'package:flutter_automation_atlas/src/atlas_checks.dart';
import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_page_renderer.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_check.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/test_atlas_root.dart';
import 'test_utils/write_published_journals.dart';

const _listPath = 'tool/uncovered.json';
const _keyHash = 'abcdef012345';

void main() {
  group('AtlasChecks Tests', () {
    _atlasChecks_should_failPageWithoutFile();
    _atlasChecks_should_passPageOfRenderer();
    _atlasChecks_should_passPageRenderedWithSourceLabel();
    _atlasChecks_should_failPageThatDiffersAtALine();
    _atlasChecks_should_passPublishedVariantsInStep();
    _atlasChecks_should_reportSnapshotOfUnpublishedVariant();
    _atlasChecks_should_failPublishedVariantNoFlowHolds();
    _atlasChecks_should_failStrandedSnapshotAndDirectory();
    _atlasChecks_should_failPublishedVariantsWithoutList();
    _atlasSnapshotsCheck_should_passFreshVariants();
    _atlasSnapshotsCheck_should_warnOfStaleVariants();
    _atlasSnapshotsCheck_should_warnWhenStalenessIsUnreadable();
    _atlasChecks_should_skipLocaleKeyCoverageWithoutList();
    _atlasChecks_should_failUndeclaredAndStrandedKeys();
    _atlasChecks_should_reportLocaleKeyCoverageCounts();
    _atlasCheckOutcome_should_describeItself();
  });
}

void _atlasChecks_should_failPageWithoutFile() {
  test('AtlasChecks should fail the page without a file', () async {
    await TestAtlasRoot.run((root) async {
      writePublishedJournals(root, journals: const []);

      final outcome = await _checks(root).page();

      expect(outcome.status, AtlasCheckStatus.failed);
      expect(
        outcome.lines.single,
        allOf(contains('run `render`'), contains(root.paths.pagePath)),
      );
    });
  });
}

void _atlasChecks_should_passPageOfRenderer() {
  test('AtlasChecks should pass the page the renderer wrote', () async {
    await TestAtlasRoot.run((root) async {
      writePublishedJournals(root, journals: const []);

      await AtlasPageRenderer(root.paths).render();

      final outcome = await _checks(root).page();

      expect(outcome.status, AtlasCheckStatus.passed);
    });
  });
}

void _atlasChecks_should_passPageRenderedWithSourceLabel() {
  test('AtlasChecks should pass page rendered with source label', () async {
    await TestAtlasRoot.run((root) async {
      writePublishedJournals(root, journals: const []);

      await AtlasPageRenderer(root.paths, sourceLabel: 'build 7').render();

      final outcome = await AtlasChecks(
        root.project,
        rootPath: root.directory.path,
        sourceLabel: 'build 7',
      ).page();

      expect(outcome.status, AtlasCheckStatus.passed);
    });
  });
}

void _atlasChecks_should_failPageThatDiffersAtALine() {
  test('AtlasChecks should fail a page that differs at a line', () async {
    await TestAtlasRoot.run((root) async {
      writePublishedJournals(root, journals: const []);

      await AtlasPageRenderer(root.paths).render();

      final file = File(root.paths.pagePath);

      file.writeAsStringSync('stray\n${file.readAsStringSync()}');

      final outcome = await _checks(root).page();

      expect(outcome.status, AtlasCheckStatus.failed);
      expect(outcome.lines.first, contains('at line 1; run `render`'));
      expect(outcome.lines[2], 'found:    stray');
    });
  });
}

void _atlasChecks_should_passPublishedVariantsInStep() {
  test('AtlasChecks should pass published variants in step', () async {
    await TestAtlasRoot.run((root) async {
      writePublishedJournals(root, journals: const []);
      File(
        root.paths.resolveSnapshotPath(
          flow: 'item_search',
          variant: 'noItemsFound',
          locale: 'uk',
        ),
      ).deleteSync();
      expect(
        (await _checks(root).publishedVariants()).status,
        AtlasCheckStatus.passed,
      );
    });
  });
}

void _atlasChecks_should_reportSnapshotOfUnpublishedVariant() {
  test('AtlasChecks should report an unpublished snapshot', () async {
    await TestAtlasRoot.run((root) async {
      writePublishedJournals(root, journals: const []);

      final outcome = await _checks(root).publishedVariants();

      expect(outcome.status, AtlasCheckStatus.reported);
      expect(
        outcome.summary,
        '1 variant has a snapshot and is not published: '
        'item_search noItemsFound',
      );
    });
  });
}

void _atlasChecks_should_failPublishedVariantNoFlowHolds() {
  test('AtlasChecks should fail a listed variant no flow holds', () async {
    await TestAtlasRoot.run((root) async {
      writePublishedJournals(root, journals: const []);
      root.writePublishedVariants({
        'item_search': ['itemsFound', 'gone'],
        'other_flow': ['x'],
      });

      final outcome = await _checks(root).publishedVariants();

      expect(outcome.status, AtlasCheckStatus.failed);
      expect(outcome.lines, [
        'published_variants.json names flow "other_flow", '
            'which has no flow file.',
        'published_variants.json names "item_search" "gone", '
            'which item_search.json does not hold.',
      ]);
    });
  });
}

void _atlasChecks_should_failStrandedSnapshotAndDirectory() {
  test('AtlasChecks should fail a stranded snapshot and directory', () async {
    await TestAtlasRoot.run((root) async {
      writePublishedJournals(root, journals: const []);

      AtlasSnapshotStore(root.paths)
        ..write(createAtlasSnapshot(flow: 'item_search', variant: 'dropped'))
        ..write(createAtlasSnapshot(flow: 'removed_flow', variant: 'any'));

      final outcome = await _checks(root).publishedVariants();

      expect(outcome.status, AtlasCheckStatus.failed);
      expect(outcome.lines, hasLength(2));
      expect(
        outcome.lines[0],
        contains(
          'dropped.uk.json describes a variant item_search.json no longer '
          'holds',
        ),
      );
      expect(outcome.lines[1], contains('holds snapshots of no flow file'));
    });
  });
}

void _atlasChecks_should_failPublishedVariantsWithoutList() {
  test('AtlasChecks should fail without the published list', () async {
    await TestAtlasRoot.run((root) async {
      writePublishedJournals(root, journals: const []);
      root.deletePublishedVariants();

      final outcome = await _checks(root).publishedVariants();

      expect(outcome.status, AtlasCheckStatus.failed);
      expect(outcome.lines.single, startsWith('No published variants list at'));
    });
  });
}

void _atlasSnapshotsCheck_should_passFreshVariants() {
  test('AtlasSnapshotsCheck should pass fresh variants', () async {
    await TestAtlasRoot.run((root) async {
      writePublishedJournals(root, journals: const []);

      final outcome = await AtlasSnapshotsCheck(
        root.paths,
        readStalenesses: (variants) async => [
          for (final variant in variants)
            _createStaleness(variant, AtlasStaleReason.fresh),
        ],
      ).run();

      expect(outcome.status, AtlasCheckStatus.passed);
    });
  });
}

void _atlasSnapshotsCheck_should_warnOfStaleVariants() {
  test('AtlasSnapshotsCheck should warn of stale variants', () async {
    await TestAtlasRoot.run((root) async {
      writePublishedJournals(root, journals: const []);

      final outcome = await AtlasSnapshotsCheck(
        root.paths,
        readStalenesses: (variants) async => [
          for (final variant in variants)
            _createStaleness(variant, AtlasStaleReason.definition),
        ],
      ).run();

      expect(outcome.status, AtlasCheckStatus.warned);
      expect(
        outcome.summary,
        '1 variant is stale, most in item_search (1); '
        'the precise list: `stale --published`, '
        'the captures: `capture --stale --published`',
      );
      expect(outcome.lines, ['item_search itemsFound definition']);
    });
  });
}

void _atlasSnapshotsCheck_should_warnWhenStalenessIsUnreadable() {
  test(
    'AtlasSnapshotsCheck should warn when staleness is unreadable',
    () async {
      await TestAtlasRoot.run((root) async {
        writePublishedJournals(root, journals: const []);

        final outcome = await AtlasSnapshotsCheck(
          root.paths,
          readStalenesses: (variants) async =>
              throw const FormatException('no device'),
        ).run();

        expect(outcome.status, AtlasCheckStatus.warned);
        expect(outcome.lines.single, contains('no device'));
      });
    },
  );
}

void _atlasChecks_should_skipLocaleKeyCoverageWithoutList() {
  test('AtlasChecks should skip key coverage without a list', () async {
    await TestAtlasRoot.run((root) async {
      writePublishedJournals(root, journals: const []);
      expect(
        (await _checks(root).localeKeyCoverage()).status,
        AtlasCheckStatus.skipped,
      );
    });
  });
}

void _atlasChecks_should_failUndeclaredAndStrandedKeys() {
  test('AtlasChecks should fail undeclared and stranded keys', () async {
    await TestAtlasRoot.runWith(project: _createProject(), (root) async {
      _writeKeyStore(
        root,
        list: {
          'gone': 'codeOnly',
          'hint': 'pending',
          'bad': 'maybe',
          'title': 'unused',
        },
      );
      root.writeTranslations('uk', {
        'title': 'T',
        'hint': 'H',
        'other': 'O',
        'bad': 'B',
      });

      final outcome = await _checks(root).localeKeyCoverage();

      expect(outcome.status, AtlasCheckStatus.failed);
      expect(outcome.lines, [
        contains('other is shown by no published variant and not listed in'),
        'hint is listed as pending but a published variant shows it. '
            'Drop the line.',
        'title is listed as unused but a published variant shows it. '
            'Drop the line.',
        contains('gone is listed in uncovered.json and is not a key'),
        'bad is listed with reason "maybe". '
            'A reason is one of codeOnly, unused, pending.',
        contains('title is listed as unused without the place'),
      ]);
    });
  });
}

void _atlasChecks_should_reportLocaleKeyCoverageCounts() {
  test('AtlasChecks should report key coverage counts', () async {
    await TestAtlasRoot.runWith(project: _createProject(), (root) async {
      _writeKeyStore(root, list: {'later': 'pending'});

      final outcome = await _checks(root).localeKeyCoverage();

      expect(outcome.status, AtlasCheckStatus.reported);
      expect(
        outcome.summary,
        '2 of 3 keys on frames, 1 declared (codeOnly 0, unused 0, pending 1)',
      );
    });
  });
}

void _atlasCheckOutcome_should_describeItself() {
  test('AtlasCheckOutcome should describe itself', () {
    expect(const AtlasCheckOutcome.passed().describe('page'), ['ok    page']);
    expect(const AtlasCheckOutcome.failed(['a', 'b']).describe('page'), [
      'FAIL  page — 2 problems',
      '      a',
      '      b',
    ]);
    expect(const AtlasCheckOutcome.reported('3 keys').describe('keys'), [
      'note  keys — 3 keys',
    ]);
    expect(const AtlasCheckOutcome.failed(['a']).isFailure, isTrue);
    expect(const AtlasCheckOutcome.warned('w').isFailure, isFalse);
  });
}

AtlasChecks _checks(TestAtlasRoot root) {
  return AtlasChecks(root.project, rootPath: root.directory.path);
}

AtlasStaleness _createStaleness(
  AtlasVariantDefinition variant,
  AtlasStaleReason reason,
) {
  return AtlasStaleness(
    variant: variant,
    reason: reason,
    changedPaths: const [],
    changedTranslationKeys: const [],
    stages: const [],
    attributedPaths: const {},
  );
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
  );
}

void _writeKeyStore(TestAtlasRoot root, {required Map<String, Object?> list}) {
  writePublishedJournals(root, journals: const []);

  root
    ..writeTranslations('uk', {'title': 'T', 'hint': 'H', 'later': 'L'})
    ..writeText(p.join(root.paths.storePath, _listPath), jsonEncode(list));

  AtlasSnapshotStore(root.paths).write(
    createAtlasSnapshot(
      flow: 'item_search',
      variant: 'itemsFound',
      stages: [
        AtlasStage(
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
          localeKeys: const {'title': _keyHash, 'hint': _keyHash},
        ),
      ],
    ),
  );
}
