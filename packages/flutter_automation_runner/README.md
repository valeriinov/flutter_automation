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
target enums and the `MockFeature` files. Only the entry point imports
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
      use: [const Use(signIn), const WaitFor(ByTarget(CatalogTarget.screen))],
      scenario: [catalogFeature.profile('empty')],
    ),
  ],
);
```

- A variant is one way through the journey. Its `use` list holds steps and
  `Use(block)` entries, in order.
- `scenario` on a flow applies to every variant; `scenario` on a variant merges
  over it. The runner pushes the result with `mock.apply` before the first
  step, unless the command line says `--no-mock`.
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
  return runFlows(args, [loginFlow], [signIn]);
}
```

```shell
fvm dart run tool/run_flows.dart <flow> [variant] [options]
```

| Option | Effect |
| --- | --- |
| `--uri <ws://...>` | VM service address of the running app. |
| `--dry-run` | Prints the resolved steps as JSON. Needs no device. |
| `--catalogue` | Prints every flow and block as one line of JSON. |
| `--no-mock` | Does not push the scenario into the app. |
| `--locale <code>` | Language of the run, sent with `locale.apply`. Default is `defaultLocale`. |
| `--timeline-out <path>` | Writes the raw timeline of a traced window. |
| `--capture <dir>` | Captures the frames of the variant into the directory. |
| `--system-keyboard` | Turns text entry emulation off for the whole run, so the system keyboard rises over a focused field and shows in a capture. `EnterText` switches the emulation on for its own call. |

Stdout holds one JSON line with the report. The live commentary goes to stderr.
The run stops at the first failed step and exits with code 1. A failure the
runner names also ends stdout with `{"error": "<message>"}`.

The app must run with `--dart-define=ENABLE_FLUTTER_DRIVER=true`, and with the
define of the project that turns the mock on.

## `pubspec.yaml` keys

The runner reads the `flutter_automation:` section of the `pubspec.yaml` of the
directory where it starts, and the package name (`package:<name>/` is the prefix
of the project's own libraries). Each key is optional.

```yaml
flutter_automation:
  defaultLocale: en
  dateFormats:
    en: MM/dd/yyyy
  frameGoalMs: 16
  splashScreen: splash
  launchHint: --dart-define=ENABLE_FLUTTER_DRIVER=true
  finders:
    calendarDay:
      kind: dateValueKey
      template: day.tile.{yyyyMMdd}
```

| Key | Type | Meaning |
| --- | --- | --- |
| `defaultLocale` | string | Locale a run takes when it names none. Default `en`. |
| `dateFormats` | map of locale to pattern | How a `ByDateText` finder writes a date, by locale. |
| `frameGoalMs` | int | Frame time in milliseconds that a traced window is held to. |
| `splashScreen` | string | `screenName` the app shows while it starts. After a relaunch the runner waits until the app shows another screen. |
| `launchHint` | string | How the app must launch, as the end of an error message. |
| `finders` | map | Finders the project declares. `kind: dateValueKey` with a `template` whose `{pattern}` is a date format. Used as `ByDeclaredDate(name, dayOffset: n)`. |

A key of the wrong type stops the run with a message that names the key.
