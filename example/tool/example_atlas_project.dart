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
    copiedDirectories: ['tool'],
    entryImports: [],
    entryMain: 'void main() {}',
    mainPath: 'lib/main.dart',
    mainPatch: [],
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
}
