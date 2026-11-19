# Stubs of the atlas files

Replace each `<...>` and each stub value with a real one. A stub carries a
comment that names the value to fill in. `<project>` is the name of the project.

## `tool/<project>_atlas_project.dart`

```dart
import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';

final class <Project>AtlasProject extends AtlasProject {
  const <Project>AtlasProject();

  @override
  AtlasPaths get paths => const AtlasPaths(
    runnerEntry: 'tool/run_flows.dart', // the file that calls runFlows
    output: '<Atlas store>', // equals the Atlas store field
    build: 'build/atlas',
    recordings: '<recordings folder of the QA catalogue>',
    publishedVariants: 'tool/atlas_published_variants.json',
  );

  @override
  AtlasLaunchSettings get launchSettings => const AtlasLaunchSettings(
    entry: 'lib/main.dart', // the entry of the Launch field
    defines: ['ENABLE_AUTOMATION=true'], // the defines of the Launch field
    commandPrefix: ['fvm'], // empty when the project has no .fvmrc
  );

  // The record kinds the app writes to its journal; fill them in from a
  // journal of one run.
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
      pattern: r'install-[0-9a-f]+', // a value drawn once per install
      placeholder: '<install>',
    ),
    generatedValue: AtlasJournalPlaceholder(
      pattern: r'generated-[0-9a-f]+', // a value drawn for each thing
      placeholder: '<generated>',
    ),
  );

  // The folders of the mock, the targets and the automation module. Add
  // `routes: AtlasRouteSettings(...)` only when the app has a generated routes
  // file; see the routes note of the setup-atlas skill.
  @override
  AtlasStaleSettings get staleSettings => const AtlasStaleSettings(
    mockDirectory: 'lib/mock/',
    targetsDirectory: 'lib/automation/',
    automationDirectory: 'lib/automation/',
    stopPaths: ['lib/main.dart'],
  );

  // A stub until the project has a headless harness; see the headless note
  // of the setup-atlas skill.
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
  String get projectName => '<Project name>';

  @override
  AutomationFlowGroup get defaultGroup => <defaultGroup>; // see flow-groups.md

  // The groupOrder constant beside the flows; the runner entry passes the
  // same constant to withGroupOrder.
  @override
  List<AutomationFlowGroup> get groupOrder => <groupOrder constant>;

  @override
  List<String> get locales => const ['en']; // the first one is the default
}
```

## `tool/atlas.dart`

```dart
import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';

import '<project>_atlas_project.dart';

Future<void> main(List<String> args) {
  return runAtlas(args, const <Project>AtlasProject());
}
```

## `tool/atlas_published_variants.json`

```json
{
  "<flow>": ["<variant>"]
}
```

## `test/mock_replay_test.dart`

`runAtlasMockReplay` reads the snapshots from the file that the input define
names. It asks the mock again for every recorded request and writes one outcome
for each snapshot to the file that the output define names. A plain
`flutter test` run sets no define, so the test skips itself. `<mock sections>`
are the sections the app puts in its mock, and `<mock apis>` builds the apis the
app puts in its mock.

```dart
import 'package:flutter_automation_atlas/mock_replay.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/<project>_atlas_project.dart';

void main() {
  test('Mock replay should write the outcome of each snapshot', () {
    return runAtlasMockReplay(
      sections: [<mock sections>],
      apis: (mock) => [<mock apis>(mock)],
      schema: const <Project>AtlasProject().journalSchema,
    );
  }, skip: !isAtlasMockReplayRun);
}
```
