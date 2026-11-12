---
name: setup-automation
description: Set up the flutter_automation packages in a Flutter project from scratch. Add the package dependencies at the tag that matches these skills, the flutter_automation section of pubspec.yaml, the Automation section of AGENTS.md, the driver installer in main, the flows entry point with a first flow, and on request the mock. Safe to run twice. Use for "set up flutter_automation", "connect the automation packages", "make the project drivable by an agent", "подключи flutter_automation", "настрой автоматизацию в проекте", "подключи пакеты автоматизации", "налаштуй автоматизацію в проєкті", "підключи пакети автоматизації".
argument-hint: "[with mock]"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

This skill takes a project from `flutter create` to a first flow that walks on a
device. It does the steps that the package README describes, so the user does
nothing by hand.

Every step starts with a check of the current state and changes a file only when
the check fails. A second run changes no file and says so. Never overwrite a file
or a value that already exists: leave it and report it.

Whether the mock is part of the setup comes from the argument you were given. If
it does not say, ask once: "Set up the mock backend too?" Without the mock, skip
step 7.

## 0. Check the project

- `pubspec.yaml` exists in the working directory and has `flutter:` under
  `dependencies:`. If not, stop and tell the user to run this skill at the root of
  a Flutter project.
- Use `fvm` as a command prefix only when the project has an `.fvmrc` or
  `.fvm/`. Examples below write `fvm`; drop it otherwise.
- Read `AGENTS.md` if it exists.

## 1. Find the tag

The tag of the packages equals the version of these skills. Read it from the first
source that answers:

1. `skills-lock.json` of the project: the `ref` of the `flutter_automation` entry
   (the `npx skills` install records it).
2. The `version` in `.claude-plugin/plugin.json` of the installed
   `flutter-automation` plugin (a Claude Code install; look in
   `~/.claude/plugins` for a `flutter-automation` folder).
3. Ask the user for the tag. List the tags of
   `https://github.com/valeriinov/flutter_automation` with `git ls-remote --tags`.

Use that tag for every `ref` below. Skills and packages of different versions can
disagree on the API, so never pick a newer tag silently.

## 2. Add the dependencies

Add each package to `pubspec.yaml` unless it is already there. A package that is
there with another `ref` gets the tag as its `ref`, and you report the change.

```yaml
dependencies:
  flutter_automation:
    git:
      url: https://github.com/valeriinov/flutter_automation.git
      path: packages/flutter_automation
      ref: <tag>
  flutter_automation_driver:
    git:
      url: https://github.com/valeriinov/flutter_automation.git
      path: packages/flutter_automation_driver
      ref: <tag>

dev_dependencies:
  flutter_automation_runner:
    git:
      url: https://github.com/valeriinov/flutter_automation.git
      path: packages/flutter_automation_runner
      ref: <tag>
```

With the mock, add `flutter_automation_mock` to `dependencies` in the same form.
Add `flutter_automation_mock_dio` only when the app uses Dio, and add `dio`
(`^5.11.1`) beside it if the project has none, because `main` imports `dio`
directly. Add `path_provider` (`^2.1.5`) too if the project has none: the mock needs a
writable folder for the scenario file. Then run `fvm flutter pub get`.

## 3. Add the `flutter_automation:` section

If `pubspec.yaml` has no top-level `flutter_automation:` key, append:

```yaml
flutter_automation:
  defaultLocale: en
  launchHint: --dart-define=ENABLE_AUTOMATION=true
```

With the mock, the launch hint also names the define that turns the mock on (step
7). The runner reads the keys `defaultLocale`, `dateFormats`, `frameBudgetMs`,
`splashScreen`, `launchHint` and `finders`. Add a key only when the project needs
it.

## 4. Install the driver in `main`

In `lib/main.dart` (or the entry point that the project runs), add as the first
statement of `main`:

```dart
import 'package:flutter_automation_driver/driver_extension.dart';

AutomationInstaller.maybeInstall(screenReader: () => null);
```

`maybeInstall` does nothing unless the app runs with
`--dart-define=ENABLE_AUTOMATION=true`, and a release build never enables it.
That define is the flag. Keep the import with the other imports of the file. `main`
may stay synchronous in this step: step 7 turns it into `Future<void> main() async`.
Skip the step when `AutomationInstaller` is already in the file. The
`screenReader` can answer `{AutomationProtocol.screenNameKey: <name>}` when the
project tracks the current screen name; `null` is valid.

The optional `localeApplier` parameter lets the `--locale` option of the runner
set the language of the app. It needs no mock. Pass a function that takes a
language code and changes the language of the project, for example
`localeApplier: (languageCode) => setAppLanguage(languageCode)`. Add it only when
the project has such a function. Where the project picks its start language,
make `AutomationInstaller.launchLanguageCode` win when it is not `null`. The
app then launches in the language of a `--locale` run.

## 5. Declare the first target and mark the first screen

1. Create the target enum in `lib/automation/targets/` (one file per enum, the
   file name is the enum name in snake case: `home_target.dart`). Name the scope
   after the first screen. For the screen that `flutter create` writes:

   ```dart
   import 'package:flutter_automation/automation_target.dart';

   /// Elements of the home screen.
   enum HomeTarget with AutomationIdComposer {
     /// Root of the screen.
     root(AutomationTargetType.screen),

     /// Increases the counter.
     increment(AutomationTargetType.button);

     @override
     final AutomationTargetType type;

     const HomeTarget(this.type);

     @override
     String get scope => 'home';
   }
   ```

2. Mark the widgets. Append `.automationTarget(HomeTarget.root)` to the screen
   root and `.automationTarget(HomeTarget.increment)` to the button, with
   `import 'package:flutter_automation/flutter_automation.dart';`. For the screen
   that `flutter create` writes, the root is the `Scaffold` that `build` returns
   and the button is its `floatingActionButton`. Skip a marker that is already
   there. The `add-automation-targets` skill (in Claude Code with
   the plugin: `flutter-automation:add-automation-targets`) owns the rules for
   every later screen.

If the project has no screen to mark yet, ask the user for the first screen to
cover.

## 6. Write the entry point and the first flow

Create the `tool/flows/` folder. `tool/flows/home_flow.dart`:

```dart
import 'package:flutter_automation_runner/automation_flow_definition.dart';

import 'package:<app package>/automation/targets/home_target.dart';

/// Opens the home screen and increases the counter once.
final homeFlow = AutomationFlowDefinition(
  name: 'home',
  defaultVariant: 'counterIncreases',
  variants: [
    FlowVariant(
      'counterIncreases',
      items: [
        const WaitFor(ByTarget(HomeTarget.root)),
        const Tap(ByTarget(HomeTarget.increment)),
        const WaitFor(ByText('1')),
      ],
    ),
  ],
);
```

`tool/run_flows.dart`:

```dart
import 'package:flutter_automation_runner/flutter_automation_runner.dart';

import 'flows/home_flow.dart';

Future<void> main(List<String> args) => runFlows(args, [homeFlow]);
```

Take the package name from `name:` in `pubspec.yaml`. Skip a file that exists; if
`tool/run_flows.dart` exists and lacks `homeFlow`, tell the user to add it.

Prove the setup without a device:

```shell
fvm dart run tool/run_flows.dart home counterIncreases --dry-run 2>/dev/null
```

The output is one line of JSON with the resolved steps. An error line means a
mistake in the files above: fix it before you go on. Run `fvm dart format .` and
`fvm dart analyze` and fix what they report in the files you wrote.

## 7. Add the mock (only when asked)

The parts go in `lib/automation/mock/`. Files that a flow reads import no Flutter
code. Skip a part that exists: a second run adds nothing to `main`.

1. **Settings and section**, in `catalog_mock_section.dart`. The file imports only
   `mock_section.dart`, so a flow on the host compiles it. A `MockSection` is one
   section of the scenario. A profile is a function over the settings, so the settings class writes the key
   `itemCount` once:
   ```dart
   import 'package:flutter_automation_mock/mock_section.dart';

   /// Settings of the catalog section of the mock.
   final class CatalogMockSettings {
     static const _defaultItemCount = 3;

     /// Number of items the catalog answers with.
     final int itemCount;

     const CatalogMockSettings({this.itemCount = _defaultItemCount});

     /// Reads the settings out of the section JSON.
     factory CatalogMockSettings.fromJson(Map<String, Object?> json) {
       final itemCount = json['itemCount'];

       return CatalogMockSettings(
         itemCount: itemCount is int ? itemCount : _defaultItemCount,
       );
     }

     /// Settings with the given values replaced.
     CatalogMockSettings copyWith({int? itemCount}) {
       return CatalogMockSettings(itemCount: itemCount ?? this.itemCount);
     }

     /// Section JSON of the settings.
     Map<String, Object?> toJson() => {'itemCount': itemCount};
   }

   /// The catalog section of the mock.
   final catalogMockSection = MockSection<CatalogMockSettings>(
     name: 'catalog',
     fromJson: CatalogMockSettings.fromJson,
     profiles: {
       'emptyShelf': (settings) => settings.copyWith(itemCount: 0),
     },
   );
   ```

   Name the section after a real backend area of the project, not `catalog`. A
   project without a backend call yet names it after the first area it will call.
   A settings class that a generator such as `freezed` writes already holds
   `fromJson`, `toJson` and `copyWith`.

2. **The switch**, in `<project>_mock_settings.dart`, a separate file: it imports
   Flutter code, so no flow imports it. One compile-time constant decides whether
   the app runs on the mock. A release build folds it to false:

   ```dart
   import 'package:flutter_automation/flutter_automation.dart';

   const bool isMockEnabled =
       AutomationSettings.isEnabled && bool.fromEnvironment('ENABLE_MOCK');
   ```

3. **Init before dependency injection**, in `main` after
   `WidgetsFlutterBinding.ensureInitialized()` (`maybeInstall` from step 4 stays
   first). `main` becomes `Future<void> main() async`. Imports:
   `package:flutter_automation_mock/flutter_automation_mock.dart`,
   `package:path_provider/path_provider.dart`, the switch file
   `<project>_mock_settings.dart` (`isMockEnabled`) and the section file
   `catalog_mock_section.dart` (`catalogMockSection`):

   ```dart
   MockScenarioBackend? backend;

   final mock = await AutomationMock.init(
     isEnabled: isMockEnabled,
     scenarioDirectory: (await getTemporaryDirectory()).path,
     sections: isMockEnabled ? [catalogMockSection] : const [],
     onScenarioApplied: (scenario) => backend?.rebuild(),
   );
   ```

   Pass `mock` to the code that builds the HTTP client.

4. **The HTTP adapter**, when the app uses Dio. Put the mock under the client where
   the app creates it. A project with no client yet creates one in `main` after the
   init (`Dio(BaseOptions(baseUrl: ...))`) and passes it to the code that needs it.
   Import `package:dio/dio.dart` and
   `package:flutter_automation_mock_dio/flutter_automation_mock_dio.dart`:

   ```dart
   final networkAdapter = dio.httpClientAdapter;

   dio.httpClientAdapter = mock.substitute(
     real: networkAdapter,
     fake: (mock) {
       final scenarioBackend = MockScenarioBackend(
         readScenario: () => mock.scenario,
         buildApis: () => [MockCatalogApi(mock)],
         buildFailureBody: (failure) => {
           'code': failure.errorCode,
           'message': failure.message,
         },
       );

       backend = scenarioBackend;

       return MockDioHttpClientAdapter(
         transport: MockApiTransport(
           backend: scenarioBackend,
           journal: mock.journal,
         ),
         networkAdapter: networkAdapter,
       );
     },
   );
   ```

   `MockScenarioBackend` is the ready `MockBackend`. It reads the failures from
   the scenario on each request. It builds the endpoints from `buildApis` and one
   latency object from the scenario, and it builds them again when
   `onScenarioApplied` calls `rebuild()`. Write one file, `mock_catalog_api.dart`,
   from this shape. The imports are
   `package:flutter_automation_mock/flutter_automation_mock.dart` and the section
   file `catalog_mock_section.dart`. `main` imports `mock_catalog_api.dart`:

   ```dart
   /// Answers the catalog endpoint from the settings of the scenario.
   final class MockCatalogApi implements MockApi {
     final AutomationMock _mock;

     const MockCatalogApi(this._mock);

     @override
     List<MockApiEndpoint> get endpoints => [
       MockApiEndpoint(path: '/catalog/items', respond: _respondItems),
     ];

     MockApiResponse _respondItems(MockApiRequest request) {
       final settings = _mock.settingsOf(catalogMockSection);

       return MockApiResponse(body: {'itemCount': settings.itemCount});
     }
   }
   ```

   A project can also put its substitutes in place with one installer that runs
   after the dependency injection. Use `mock.substitute` where the app creates the
   object when the project has no such installer.

   Read the Dartdoc of `AutomationMock`, `MockApi` and `MockBackend` for more, or
   the `example/` app of the package repository. If the app uses another HTTP
   client, tell the user that only the Dio adapter ships and stop after
   `AutomationMock.init`.

5. Add the define of the switch to `launchHint` in `pubspec.yaml`
   (`--dart-define=ENABLE_MOCK=true`).

6. Add a variant to `tool/flows/home_flow.dart` that sets the profile of part 1, so
   the flow compiles with the section file. Import
   `package:<app package>/automation/mock/catalog_mock_section.dart`:

   ```dart
   FlowVariant(
     'emptyShelf',
     items: [const WaitFor(ByTarget(HomeTarget.root))],
     scenario: [catalogMockSection.profile('emptyShelf')],
   ),
   ```

Run `fvm dart format .` and `fvm dart analyze`.

## 8. Write the `## Automation` section of `AGENTS.md`

If `AGENTS.md` has no `## Automation` heading, add the section from the template
`templates/AGENTS.automation.md` of the package repository. If `AGENTS.md` does not
exist, create it from the template. Fill the fields from what steps 1 to 7 made: replace the description and the
example after the colon of each bullet with the value, and keep the intro
paragraph and the bold labels. Leave a field alone when it already holds a value.

- **Flow run command**: `fvm dart run tool/run_flows.dart`
- **Launch**: the `flutter run` arguments with the entry point (`-t lib/main.dart`
  when the project has no other), the flavor if any and
  `--dart-define=ENABLE_AUTOMATION=true`, plus the mock define when step 7 ran
- **Flows folder**: `tool/flows`
- **Targets folder**: `lib/automation/targets`
- **Mock configuration file**: the file of step 7 that declares the `MockSection`
  (`lib/automation/mock/catalog_mock_section.dart`), or `none`
- **Default flow**: `home`
- **After an edit**: `fvm dart format . && fvm dart analyze`
- **Post-edit steps**: `none`
- **Format-change places**: `none`
- **Learned rules**: ask the user which document takes them; propose
  `docs/agents/automation.md`

## 9. Run the first flow

Boot a device and launch the app by the `drive-device` skill (in Claude Code with
the plugin: `flutter-automation:drive-device`), then walk the flow by `run-flow`
(`flutter-automation:run-flow`):

```shell
fvm dart run tool/run_flows.dart home counterIncreases 2>/dev/null
```

With the mock, walk the `emptyShelf` variant too. It builds the flow with the
section file and applies the profile:

```shell
fvm dart run tool/run_flows.dart home emptyShelf 2>/dev/null
```

The report must hold `"ok":true`. Offer this walk to the user when no device is
available, and finish with the dry run of step 6.

## 10. Tell the user

Report in a short list: the files that changed, the files that you left alone, the
dry-run result, and the walk result or the reason it did not run. A second run of
this skill must report that nothing changed.

Then name how the skills reach the other agents. This skill never installs them.

- Claude Code: `/plugin marketplace add valeriinov/flutter_automation`, then
  `/plugin install flutter-automation@flutter-automation`. The skills and the
  workflows appear as `flutter-automation:<name>`.
- Codex and other agents:
  `npx skills add https://github.com/valeriinov/flutter_automation/tree/<tag>`.
  The form with a tag records `ref` in `skills-lock.json`. It installs the skills
  and no workflow. The `run-flow` skill works without the `measure-flow` workflow.
