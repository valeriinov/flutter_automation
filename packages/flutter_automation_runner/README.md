# flutter_automation_runner

`runFlows`: the command line that walks a flow of a running app through Flutter
Driver, and the Dart library in which a project writes its flows.

## Libraries

| Import | Host-safe | Holds |
| --- | --- | --- |
| `package:flutter_automation_runner/automation_flow_definition.dart` | Yes, Dart VM only, no Flutter or driver import | `AutomationFlowDefinition`, `FlowVariant`, `FlowBlock`, `Use`, the steps (`Tap`, `WaitFor`, ...), the finders (`ByTarget`, `ByText`, ...). |
| `package:flutter_automation_runner/flutter_automation_runner.dart` | Needs `flutter_driver`, runs in the Dart VM | The library above, plus `runFlows`, `AutomationRunner`, `AutomationRunnerConfig` and the device helpers. |
| `package:flutter_automation_runner/widget_tester_finders.dart` | No, imports `flutter_test` | The same flow finders as widget test `Finder`s. |

Flows live in files that import only `automation_flow_definition.dart`, the
target enums and the `MockSection` files. Only the entry point imports
`flutter_automation_runner.dart`.

## API

### Write a flow

```dart
import 'package:flutter_automation_runner/automation_flow_definition.dart';

const signIn = FlowBlock(name: 'signIn', build: _buildSignIn);

List<FlowStep> _buildSignIn(FlowParams params) => const [
  WaitFor(ByTarget(LoginTarget.screen)),
  Tap(ByTarget(LoginTarget.submit)),
];

final loginFlow = AutomationFlowDefinition(
  name: 'login',
  defaultVariant: 'default',
  variants: [
    FlowVariant(
      'default',
      items: [const Use(signIn), const WaitFor(ByTarget(CatalogTarget.screen))],
      scenario: [catalogSection.profile('empty')],
    ),
  ],
);
```

- A variant is one way through the journey. Its `items` list holds steps and
  `Use(block)` items, in order.
- `scenario` on a flow applies to every variant. `scenario` on a variant
  continues the list of overrides of its flow, so the overrides of the variant
  apply after the ones of the flow. The runner pushes the result with
  `scenario.apply` before the first step, unless the command line says
  `--no-scenario`. A variant that names a scenario makes the runner restart the
  app after the push. `--locale` makes the runner restart the app too.
- `FlowVariant.stateOf` names the variant of the same flow whose frame this
  variant shows in another state. A variant without it is a way of its own.
- `AutomationFlowDefinition.subtitle` holds one sentence about what the journey
  is about. It is optional.
- A block takes parameters. `FlowBlock.params` names them with defaults, the
  build function reads `params['name']`, and `Use(block, arguments: {...})`
  fills them in.
- Finders: `ByTarget`, `ByValueKey`, `ByText`, `ByTooltip`, `ByLocaleKey`,
  `ByLocaleKeyTooltip`, `ByType`, `ByPageBack`, `ByDateText`, `ByDeclaredDate`,
  `ByDescendant`, `ByAncestor`.
- Steps: `Tap`, `WaitFor`, `WaitForAbsent`, `WaitForTappable`, `ScrollIntoView`,
  `Scroll`, `EnterText`, `ProbeCenter`, `ProbeSeries`, `TraceStart`,
  `TraceStop`, `DriverCommand`.

A script that imports both `package:flutter_driver/flutter_driver.dart` and the
flow-definition library sees the same names twice: `Tap`, `WaitFor`,
`WaitForAbsent`, `WaitForTappable`, `ScrollIntoView`, `Scroll`, `EnterText`,
`ByValueKey`, `ByText` and `ByType`. Import one of the two with `hide` or with a
prefix (`import '...flutter_driver.dart' as driver;`).

### Run flows

```dart
import 'package:flutter_automation_runner/flutter_automation_runner.dart';

Future<void> main(List<String> args) {
  return runFlows(args, [loginFlow]);
}
```

The runner collects the blocks from the `Use` items of the variants. Two
different blocks with one name stop the run.

```shell
fvm dart run tool/run_flows.dart <flow> [variant] [options]
```

| Option | Effect |
| --- | --- |
| `--uri <ws://...>` | VM service address of the running app. The runner caches it in `.dart_tool/automation_runner_uri` and reuses it until the app relaunches. |
| `--dry-run` | Prints the resolved steps as JSON. Needs no device. |
| `--catalogue` | Prints every flow and block as one line of JSON. |
| `--no-scenario` | Does not push the scenario into the app. |
| `--locale <code>` | Language of the run, sent with `locale.apply` to the `localeApplier` of the driver. The app restarts in it. Works on an app without a mock. Default is `defaultLocale`. |
| `--record <dir>` | Writes `<dir>/<flow>/<variant>.json` with the steps, timings and requests of the run. Needs a full run. |
| `--qa-catalogue <file>` | Writes the QA catalogue of the flows. Needs no device. |
| `--recordings <dir>` | With `--qa-catalogue`: adds the recorded answers of the runs that passed. |
| `--check` | With `--qa-catalogue`: writes nothing and tests that the file is the catalogue the flows and recordings give. |
| `--shoot <i,j>` | With `--capture`: names the stages that get a screenshot, a target rect and their journal. |
| `--until <k>` | With `--capture`: ends the walk before the action of stage `k + 1`. |
| `--timeline-out <path>` | Writes the raw timeline of a traced window. |
| `--capture <dir>` | Captures the frames of the variant into the directory. |
| `--system-keyboard` | Turns text entry emulation off for the whole run, so the system keyboard rises over a focused field and shows in a capture. `EnterText` switches the emulation on for its own call. |

Stdout holds one JSON line with the report. The live commentary goes to stderr.
The run stops at the first failed step and exits with code 1. A failure the
runner names also ends stdout with `{"error": "<message>"}`.

The app must run with `--dart-define=ENABLE_AUTOMATION=true`, and with the define
of the project that turns the mock on. A capture sends `journal.read`, so it
needs the mock. A run with `--no-scenario --locale <code>` needs no mock.

### Launch language

A run with `--locale <code>` launches the app in that language, with a
scenario and with `--no-scenario`:

1. The runner pushes the scenario, when the variant applies one.
2. The runner sends `locale.save`. The driver saves the language in a file
   that outlives the restart.
3. The runner restarts the app with the `hotRestart` of `flutter run`. The
   driver reads and removes the file and answers the language in
   `AutomationInstaller.launchLanguageCode`.
4. The runner sends `locale.apply`, then walks the steps.

The first frame and the launch requests are in the language of the run when
the app starts in `AutomationInstaller.launchLanguageCode`. An app that does
not read it launches in its own language, then switches at step 4. The driver
answers the language for one launch only, so the next run without `--locale`
starts in the language of the app.

A run with `--locale` always restarts the app, so the app must run under
`flutter run`. Under `--no-scenario`, the restart drops the state that the app
held in memory. A mock then launches on an empty scenario, because the launch
before already read and removed the saved one. A run
without `--locale` sends no language and restarts the app only for a scenario.

## QA catalogue and recordings

`--record <dir>` writes `<dir>/<flow>/<variant>.json` with the steps, the
timings and the requests of each step. A request that the mock answers after
the read of a step belongs to that step, as in a capture run. The option needs
a full run: it rejects `--shoot` and `--until`. A run that fails writes no
recording.

`--qa-catalogue <file>` writes the catalogue of `flutter_automation_panel` out
of the flows. With `--recordings <dir>` it adds the recorded answers of the runs
that passed. It needs no device. A flow stays in the catalogue only when its
`AutomationFlowDefinition` sets `isInQaCatalogue: true`. The `entry` title of a
variant becomes the entry of its catalogue variant. A recorded step keeps its
`step` JSON: the action, the finder with each block parameter substituted, the
text, the title, the timeout and the distance of a scroll. The catalogue step
carries them, so the player of `flutter_automation_panel` can do it.

`--check` after `--qa-catalogue <file>` writes nothing. It tests that the file
is the catalogue the flows and the recordings give, and that each variant of a
flow in the catalogue has a recording of a passed run with the step labels of
the variant. A recording of a flow outside the catalogue is not a problem; a
recording that no flow or variant holds is. The command prints one line of
JSON, `{"qaCatalogue", "ok", "problems": [...]}`, and exits with code 1 when
`problems` is not empty.

The fork of a flow stands at the earlier of two places: the first step at which
the steps of two variants differ in their action, finder or text, and the first
request, matched by method, path and its n-th call in the variant, whose code or
body differs between variants. A branch carries the title of its variant. A
branch is chosen before the start when its scenario differs from another
branch in a `restartKeys` key of a section. `runFlows` and
`AutomationRunner.fromDefinitions` take the `sections` that name those keys.

## `pubspec.yaml` keys

The runner reads the `flutter_automation:` section of the `pubspec.yaml` of the
directory where it starts, and the package name (`package:<name>/` is the prefix
of the project's own libraries). Each key is optional.

```yaml
flutter_automation:
  defaultLocale: en
  dateFormats:
    en: MM/dd/yyyy
  frameBudgetMs: 16
  splashScreen: splash
  launchHint: --dart-define=ENABLE_AUTOMATION=true
  finders:
    calendarDay:
      kind: dateValueKey
      template: day.tile.{yyyyMMdd}
```

| Key | Type | Meaning |
| --- | --- | --- |
| `defaultLocale` | string | Locale a run takes when it names none. Default `en`. |
| `dateFormats` | map of locale to pattern | How a `ByDateText` finder writes a date, by locale. |
| `frameBudgetMs` | int | Frame time in milliseconds that a traced window is held to. |
| `splashScreen` | string | `screenName` the app shows while it starts. After a relaunch the runner waits until the app shows another screen. |
| `launchHint` | string | How the app must launch, as the end of an error message. |
| `finders` | map | Finders the project declares. `kind: dateValueKey` with a `template` whose `{pattern}` is a date format. Used as `ByDeclaredDate(name, dayOffset: n)`. |

A key of the wrong type stops the run with a message that names the key.
