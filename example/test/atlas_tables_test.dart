import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/example_atlas_project.dart';

void main() {
  const project = ExampleAtlasProject();

  test('The store reader gives the request records of the atlas', () {
    final store = AtlasStoreReader.open(project);

    expect(store.recordsOf('request'), isNotEmpty);
    expect(store.walkersByScreen().keys, containsAll(['login', 'catalog']));
  });
  test('The statuses table has one row for the one status logged', () {
    final tables = project.tables(AtlasStoreReader.open(project));
    final statuses = tables.singleWhere((table) => table.id == 'statuses');

    expect(statuses.rows, hasLength(1));
    expect(statuses.rows.single['code'], '200');
    expect(statuses.rows.single, contains('stages'));
  });
  test('The runner catalogue resolves each variant of each flow', () {
    final flows = AutomationFlowCatalogue.read(
      '.',
      project.paths.runnerEntry,
      commandPrefix: project.launchSettings.commandPrefix,
    ).resolveFlows();

    expect(
      [for (final flow in flows) '${flow.name} ${flow.variant}'],
      ['catalog items', 'catalog empty'],
    );
  });
}
