import 'dart:io';

import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';

import 'flows/catalog_flow.dart';

/// The atlas of the example app.
final class ExampleAtlasProject extends AtlasProject {
  static const _locales = ['en', 'uk'];

  const ExampleAtlasProject();

  @override
  AtlasPaths get paths => const AtlasPaths(
    runnerEntry: 'tool/run_flows.dart',
    output: 'atlas',
    build: 'build/atlas',
    recordings: 'tool/recordings',
    publishedVariants: 'tool/atlas_published_variants.json',
    translations: 'tool/translations/{locale}.json',
    screenDescriptions: 'tool/screen_descriptions.json',
    uncoveredLocaleKeys: 'tool/uncovered_locale_keys.json',
  );

  @override
  AtlasLaunchSettings get launchSettings => const AtlasLaunchSettings(
    entry: 'lib/main.dart',
    defines: ['ENABLE_AUTOMATION=true', 'ENABLE_MOCK=true'],
    commandPrefix: ['fvm'],
  );

  @override
  AtlasJournalSchema get journalSchema => const AtlasJournalSchema(
    analyticsKind: 'analytics',
    stateKind: 'state',
    requestKinds: {'request'},
    launchKind: 'launch',
    answerKinds: {'request'},
    stateKey: 'owner',
    createdKey: 'created',
    parametersKey: 'parameters',
    screenNameParameter: 'screen_name',
    screenViewName: 'screen_opened',
    installValue: AtlasJournalPlaceholder(
      pattern: r'install-[0-9a-f]+',
      placeholder: '<install>',
    ),
    generatedValue: AtlasJournalPlaceholder(
      pattern: r'generated-[0-9a-f]+',
      placeholder: '<generated>',
    ),
  );

  // The app has no generated routes file, so no stage names source files of
  // its own.
  @override
  AtlasStaleSettings get staleSettings => const AtlasStaleSettings(
    mockDirectory: 'lib/mock/',
    targetsDirectory: 'lib/automation/',
    automationDirectory: 'lib/automation/',
    stopPaths: ['lib/example_app.dart', 'lib/main.dart'],
  );

  @override
  AtlasHeadlessSettings get headlessSettings => const AtlasHeadlessSettings(
    defines: ['ENABLE_AUTOMATION=true', 'ENABLE_MOCK=true'],
    copiedDirectories: ['tool'],
    entryImports: ['tool/example_headless_app.dart'],
    entryMain: 'void main() => ExampleHeadless.runSuite(_runAppMain);',
    mainPath: 'lib/main.dart',
    mainPatch: [
      ('Future<void> main() async {', 'Future<void> _runAppMain() async {'),
      ('AutomationInstaller.maybeInstall(', 'ExampleHeadless.install('),
      (
        '  final dio = Dio(',
        '  ExampleHeadless.captureMock(mock);\n  final dio = Dio(',
      ),
      ('  runApp(', '  AtlasHeadlessLaunch.runApp('),
    ],
  );

  @override
  String get mockReplayEntry => 'test/mock_replay_test.dart';

  @override
  String get designScreenKey => 'designScreenName';

  @override
  String get projectName => 'Example';

  @override
  AutomationFlowGroup get defaultGroup => catalogGroup;

  @override
  List<AutomationFlowGroup> get groupOrder => catalogGroupOrder;

  @override
  List<String> get locales => _locales;

  @override
  RegExp get localeKeyUsagePattern => RegExp(r"\btr\(context, '(\w+)'\)");

  @override
  List<AtlasTable> tables(AtlasStoreReader store) {
    return [
      AtlasRequestsTable.build(
        id: 'requests',
        title: const {'en': 'Requests', 'uk': 'Запити'},
        journalKind: 'request',
        store: store,
        declared: const [
          AtlasDeclaredRequest(
            method: 'GET',
            path: '/catalog/items',
            names: ['getItems'],
            usages: ['lib/catalog/catalog_api.dart:13'],
          ),
        ],
      ),
      _buildStatusesTable(store),
    ];
  }

  AtlasTable _buildStatusesTable(AtlasStoreReader store) {
    final records = store.recordsOf('request');
    final statuses = {for (final entry in records) _readStatus(entry.record)};

    return AtlasTable(
      id: 'statuses',
      title: const {'en': 'Answer statuses', 'uk': 'Статуси відповідей'},
      columns: const [
        AtlasTableColumn(key: 'code', title: {'en': 'Code', 'uk': 'Код'}),
      ],
      rows: [
        for (final status in statuses)
          {
            'code': status,
            ...AtlasTable.stagesData([
              for (final entry in records)
                if (_readStatus(entry.record) == status) entry.stage,
            ]),
          },
      ],
      journalKind: 'request',
    );
  }

  String _readStatus(Map<String, Object?> record) => '${record['status']}';

  @override
  void writeReports(AtlasStoreReader store) {
    if (!store.isDefaultStore) {
      return;
    }

    final lines = [
      for (final MapEntry(:key, :value) in store.walkersByScreen().entries)
        '$key: ${value.join(', ')}',
    ];

    File('${store.rootPath}/${paths.build}/screen_walkers.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('${lines.join('\n')}\n');
  }
}
