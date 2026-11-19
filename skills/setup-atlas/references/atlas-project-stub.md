# Stubs of the atlas files

Replace each `<...>` and each stub value with a real one. A stub carries a
comment that names the value to fill in. `<project>` is the name of the project.

## `tool/<project>_atlas_project.dart`

```dart
import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';

final class <Project>AtlasProject implements AtlasProject {
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
  AtlasLaunchSettings get launch => const AtlasLaunchSettings(
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
  List<AtlasTable> tables(String store) => const [];

  @override
  Map<String, Object?> translations(String locale) => const {};

  @override
  Map<String, Map<String, String>> get screenDescriptions => const {};

  @override
  String? designLink(String screen) => null;

  @override
  String get projectName => '<Project name>';

  @override
  AutomationFlowGroup get defaultGroup => <defaultGroup>; // see flow-groups.md

  // The groupOrder constant beside the flows; the runner entry passes the
  // same constant to withGroupOrder.
  @override
  List<AutomationFlowGroup> get groupOrder => <groupOrder constant>;

  @override
  List<String> get sourceDirtyIgnores => const [];

  @override
  void writeReports(String store) {}

  @override
  AtlasShotPublisher? get shotPublisher => null;

  @override
  List<String> get locales => const ['en']; // the first one is the default

  @override
  bool isCataloguedAnalytics(Map<String, Object?> record) => true;
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

The test reads the snapshots from the file that the first define names. It asks
the mock again for every recorded request and writes one outcome for each
snapshot to the file that the second define names. A plain `flutter test` run
sets no define, so the test skips itself. `<mock apis>` and
`<mock sections>` are the apis and the sections the app puts in its mock.

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/<project>_atlas_project.dart';

const _inputPath = String.fromEnvironment(AtlasMockReplayProcess.inputDefine);
const _outputPath = String.fromEnvironment(AtlasMockReplayProcess.outputDefine);

void main() {
  test('Mock replay should write the outcome of each snapshot', () async {
    final inputs = AtlasMockReplayInput.readAll(
      File(_inputPath).readAsStringSync(),
    );
    final outcomes = <String, AtlasMockReplayOutcome>{};

    for (final input in inputs) {
      outcomes[input.id] = await _replay(input);
    }

    File(_outputPath).writeAsStringSync(
      jsonEncode({
        for (final MapEntry(:key, :value) in outcomes.entries)
          key: value.toJson(),
      }),
    );
  }, skip: _inputPath.isEmpty);
}

Future<AtlasMockReplayOutcome> _replay(AtlasMockReplayInput input) async {
  final directory = Directory.systemTemp.createTempSync('atlas_replay');

  try {
    final mock = await AutomationMock.init(
      isEnabled: true,
      scenarioDirectory: directory.path,
      sections: [<mock sections>],
    );

    await mock.updateScenario(MockScenario.fromJson(input.scenario));

    final endpoints = MockApiEndpointResolver([<mock apis>(mock)]);
    final comparison = AtlasMockAnswerComparison(
      const <Project>AtlasProject().journalSchema,
    );
    final responses = [
      for (final answer in input.answers)
        await _respond(endpoints, answer.record),
    ];

    return AtlasMockReplayer(input, (input, timing) {
      return [
        for (final (index, answer) in input.answers.indexed)
          _describeAnswer(answer, responses[index], comparison, timing),
      ];
    }).replay();
  } finally {
    directory.deleteSync(recursive: true);
  }
}

Future<MockApiResponse?> _respond(
  MockApiEndpointResolver endpoints,
  Map<String, Object?> recorded,
) async {
  final path = '${recorded['path']}';

  return endpoints
      .tryResolve(path)
      ?.respond(
        MockApiRequest(
          path: path,
          method: '${recorded['method']}',
          body: _readBody(recorded['body']),
        ),
      );
}

AtlasReplayedAnswer _describeAnswer(
  AtlasRecordedAnswer answer,
  MockApiResponse? response,
  AtlasMockAnswerComparison comparison,
  AtlasReplayTiming timing,
) {
  final recorded = answer.record;
  final replayed = {
    'kind': recorded['kind'],
    'status': response?.statusCode,
    'response': response?.body,
  };

  return AtlasReplayedAnswer(
    stage: answer.stage,
    request: '${recorded['method']} ${recorded['path']}',
    difference: comparison.compare(
      recorded: recorded,
      replayed: replayed,
      hasKnownMoments: timing.launchedAt != null,
    ),
  );
}

Map<String, Object?> _readBody(Object? body) {
  return switch (body) {
    final Map<String, Object?> map => map,
    _ => const {},
  };
}
```
