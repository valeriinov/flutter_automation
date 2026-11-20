import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/example_atlas_project.dart';

/// The four checks of `fvm dart run tool/atlas.dart check`. A stale snapshot
/// warns; only a failure breaks the run.
void main() {
  final checks = AtlasChecks(const ExampleAtlasProject());

  test('The committed atlas page matches its sources', () async {
    final outcome = await checks.page();

    expect(outcome.lines, isEmpty);
    expect(outcome.status, AtlasCheckStatus.passed);
  });
  test('The published variants match the flows and the snapshots', () async {
    final outcome = await checks.publishedVariants();

    expect(outcome.lines, isEmpty);
    expect(outcome.isFailure, isFalse);
  });
  test('The snapshots do not fail the check', () async {
    final outcome = await checks.snapshots();

    expect(outcome.isFailure, isFalse);
  });
  test('Every translation key is on a frame or listed with a reason', () async {
    final outcome = await checks.localeKeyCoverage();

    expect(outcome.lines, isEmpty);
    expect(outcome.isFailure, isFalse);
  });
}
