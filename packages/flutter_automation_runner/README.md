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
| `--uri <ws://...>` | VM service address of the running app. |
| `--dry-run` | Prints the resolved steps as JSON. Needs no device. |
| `--catalogue` | Prints every flow and block as one line of JSON. |
| `--no-scenario` | Does not push the scenario into the app. |
| `--locale <code>` | Language of the run, sent with `locale.apply` to the `localeApplier` of the driver. The app restarts in it. Works on an app without a mock. Default is `defaultLocale`. |
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
2. The runner sends `locale.apply` to the running app.
3. The runner restarts the app with the `hotRestart` of `flutter run`.
4. The runner sends `locale.apply` again, then walks the steps.

The first frame and the launch requests are in the language of the run only
when the `localeApplier` of the app keeps the language for the next launch, for
example in a file that the app reads before its first request. A restart drops
every Dart object, so a language kept only in memory is lost. An app that keeps
the language only in memory launches in its own language, then switches at
step 4.

A run with `--locale` always restarts the app, so the app must run under
`flutter run`. Under `--no-scenario`, the restart drops the state that the app
held in memory. A mock then launches on an empty scenario, because the launch
before already read and removed the saved one. A run
without `--locale` sends no language and restarts the app only for a scenario.

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
