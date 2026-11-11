---
name: run-flow
description: Walk one variant of an automation flow on a device. Resolve a request in words to a flow and a variant, add the variant and the mock scenario it needs when none covers it, expand it with --dry-run, run it in one command and read the report. Use for "run the flow", "walk the login flow", "add a flow variant", "run the flow where the user rejects the form", "прогони флоу", "запусти флоу", "добавь вариант флоу", "пройди сценарий без бэкенда", "прожени флоу", "запусти флоу", "додай варіант флоу", "пройди сценарій", or any request to walk a journey that is already written down instead of driving the app tap by tap.
argument-hint: "<flow> [variant], or the journey in words"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, mcp__dart__hot_restart, mcp__dart__get_runtime_errors
---

A flow is a journey written in Dart. It walks in one command and answers with
the milliseconds of each step. This skill turns a request in words into a flow,
a variant, a mock scenario and a run.

Read the `## Automation` section of the project `AGENTS.md` first. This skill
names its fields in bold: **Flow run command**, **Launch**, **Flows folder**,
**Targets folder**, **Mock configuration file**, **Default flow**, **After an
edit**, **Post-edit steps**, **Format-change places**, **Learned rules**. A
missing field: ask the user once and write the answer into the section.

Three facts decide most sessions:

- **A variant is Dart in the flows folder.** The runner prints its steps as JSON
  with `--dry-run`, so a malformed variant fails before a device is involved.
- **A variant declares the state it needs.** Its `scenario` is pushed into the
  running app before the first step. A mock key costs no edit of the mock.
- **A step addresses an id.** A finder you assembled by hand (`ByType`, a
  descendant chain, a piece of copy) marks a missing target. Cover the screen
  with the `add-automation-targets` skill, then write the step against the id.

Other skills own their parts. This skill does not restate them. `drive-device`
owns the device, the launch, the connection and the driver budget. `mock-app` owns
what a mock key means. `add-automation-targets` owns declaring and marking ids. In
Claude Code with the plugin, the names are `flutter-automation:drive-device`,
`flutter-automation:mock-app` and `flutter-automation:add-automation-targets`.

## 1. Resolve the request to a flow and a variant

List the flow files in the **Flows folder**. Read the flow that matches. Match
the request against what each variant claims to prove, not against how it walks.

| The request names | It lands in |
| --- | --- |
| a journey that a variant proves | run it (section 4) |
| a way through a journey that no variant covers | add the variant (section 2) |
| a journey with no flow | write the flow: one variant, no blocks yet |
| an element that no enum in the **Targets folder** declares | `add-automation-targets`, then section 2 |

A request with no flow name walks the **Default flow**.

## 2. Add the variant

A flow file declares one `AutomationFlowDefinition` with every way through one
journey. A `FlowVariant` lists its steps in `use`. Names below are neutral
examples.

```dart
final loginFlow = AutomationFlowDefinition(
  name: 'login',
  defaultVariant: 'validCredentialsAccepted',
  title: const AutomationLocalizedText({'en': 'Sign in'}),
  variants: [
    FlowVariant(
      'validCredentialsAccepted',
      title: const AutomationLocalizedText({'en': 'Valid credentials'}),
      proves: const AutomationLocalizedText({
        'en': 'A valid pair opens the home screen',
      }),
      scenario: [authMockFeature.override({'isSignedInOnLaunch': false})],
      use: [
        const WaitFor(ByTarget(LoginTarget.root)),
        Use(enterCredentials, arguments: {'email': 'user@example.com'}),
        const Tap(ByTarget(LoginTarget.submit)),
        const WaitFor(ByTarget(HomeTarget.root), timeout: Duration(seconds: 20)),
      ],
    ),
  ],
);
```

- `use` holds `FlowStep` values (`Tap`, `WaitFor`, `WaitForAbsent`,
  `WaitForTappable`, `ScrollIntoView`, `Scroll`, `EnterText`, `ProbeCenter`,
  `ProbeSeries`, `TraceStart`, `TraceStop`, `DriverCommand`) and `Use(block)`
  items. Import `package:flutter_automation_runner/automation_flow_definition.dart`.
- A finder is `ByTarget(<target>)` first. The other finders are `ByValueKey`,
  `ByText`, `ByTooltip`, `ByLocaleKey`, `ByLocaleKeyTooltip`, `ByType`,
  `ByPageBack`, `ByDateText`, `ByDeclaredDate`, `ByDescendant` and `ByAncestor`.
  A text finder is right only when the copy is what the walk checks.
- A variant name is lowerCamelCase and names what the variant **proves**
  (`rejectedFormKeepsInput`), never how it walks (`tapTwice`).
- Open the variant with a `WaitFor` on the screen it starts from. Close it with
  a `WaitFor` on the screen it returns to. `drive-device` owns why.
- A variant with a `scenario` starts from a launch on that scenario. The runner
  pushes the scenario, hot-restarts the app and walks the restarted app. A state
  that the app reads on start is a key of the scenario. Examples are a signed-out
  launch and a launch by a link. Never use a sign-out or a tap before the first
  screen.
- `defaultVariant` is required when the flow holds more than one variant. A run
  with no variant fails and lists the ones the flow holds.
- A variant that proves a movement uses one `ProbeSeries` step, never a row of
  `ProbeCenter` steps. One step cycles its probes for its `duration`. Frame sync
  must be off for the window (see `drive-device`).
- A variant that measures frames wraps the tap that starts the movement in
  `TraceStart` and `TraceStop`. It carries no probe: a probe is a driver round
  trip that takes time from the isolate the trace reads. Name it
  `<what it measures>FrameStats`. Give `TraceStart` a `duration` when the step
  before it resolves on a screen that is still opening.
- A step never taps an element that the system keyboard covers. The driver taps
  through the keyboard, so the walk would prove a path no user can take. Close
  the keyboard first with a `Tap` on the target of the keyboard close button.
- Pick a date with `ByDeclaredDate` or `ByDateText` and a `dayOffset`, never
  with a date written out: a mock seeds its data from the day the run starts.
- `title`, `proves` and `entry` of the flow, the variants and the steps hold the
  texts that a generated catalogue shows. The project documents which locale
  codes it needs.

A stretch of steps becomes a block when two variants share it. Extract it in the
change that adds the second variant. A block file is snake_case and starts with
the feature area it serves.

```dart
final enterCredentials = FlowBlock(
  name: 'login_enter_credentials',
  params: {'email': 'user@example.com'},
  build: (params) => [
    const WaitFor(ByTarget(LoginTarget.email)),
    const Tap(ByTarget(LoginTarget.email)),
    EnterText('${params['email']}', label: 'type ${params['email']}'),
  ],
);
```

`params['x']` prints as `{{x}}`, and the runner substitutes it inside any
string of a step, the label and the title included. A parameter that the block
does not declare throws when the flow builds. A block that no variant uses is
dead weight: delete it or fold it back. The entry point passes every flow and
every block to `runFlows`; a new flow or block joins that list.

## 3. Declare the mock scenario the variant needs

A `scenario` is a list of `MockOverride(key, value)`. Build one with the
`MockFeature` of the section:

- `feature.profile('name')` applies a named partial setting the feature declares.
- `feature.override({'field': value})` sets the fields it names.
- `MockScenario.latency(<profile enum>)`, `MockScenario.latencySeed(<int>)` and
  `MockScenario.failures({'<path>': {...}})` set the keys above the sections.

**Read the `MockFeature` and its settings class before you name a field.** The
file is named in **Mock configuration file**. A key or a field that the settings
class does not read is dropped in silence, and the run then proves something
other than what was asked.

- `latency` decides the wall clock of every mocked answer. A fast profile is for
  a run that measures the app rather than the network. A seed makes two runs
  comparable.
- `failures` is keyed by endpoint path. An entry with an error status, or with
  `isConnectionError: true`, reaches the error handling of the app with no line
  of Dart.
- A variant `scenario` deep-merges over the flow `scenario`. The leaf key of the
  variant wins, so a variant states what it differs by and inherits the rest.
- A scenario needs an app launched with the mock on. **Launch** names the define.
  `--no-mock` walks a variant without pushing its scenario.

## 4. Expand, then run

Expand first. It needs no device and it separates a malformed variant from a
step that the app failed.

```shell
<Flow run command> <flow> <variant> --dry-run 2>/dev/null
```

The answer holds the merged scenario and the resolved steps. An unknown block, a
parameter that a block does not declare, a variant that the flow does not hold
and a repeated variant name all fail here. Never spend a device run on a variant
that has not expanded. `--catalogue` prints every flow and block before a `Use`
expands, as one line of JSON.

Then walk it. `drive-device` step 1 picks the device. The app runs with the
**Launch** arguments, which include `--dart-define=ENABLE_FLUTTER_DRIVER=true`.

```shell
<Flow run command> <flow> <variant> 2>/dev/null
```

Options:

- `--capture <dir>` records what the app does at each step: requests, journal
  records, the screen before each action. The app must run with the mock on.
- `--locale <code>` walks the app in another locale. The runner sends
  `locale.apply` after the scenario. Without it, the app keeps its launch locale.
  A number that the app formats per locale needs a finder `value` that matches
  that locale.
- `--system-keyboard` turns text entry emulation off for the whole run, so the
  system keyboard rises over a focused field. `EnterText` turns it on for its
  own call.
- `--uri <ws uri>` is needed once after a relaunch. The runner caches the uri in
  `.dart_tool/automation_runner_uri`. The cache holds one uri, so with two
  devices a run goes to the device cached last. Pass `--uri` for every device
  and read the cache back before you trust a report.
- `--timeline-out <path>` keeps the raw timeline of a traced run.
- `--shoot` and `--until` limit a `--capture` run to some stages.

A capture and a run of several variants start from the main session, in the
background, with the report written to a file. A subagent gets the finished
report.

**Restart the app before every run**, not only after a failure. A variant that
succeeds parks the app on the screen it proved. A pushed route hides the screen
below it from the driver, so the next opening `WaitFor` times out on a screen
that is mounted but not visible. `mock.apply` re-seeds the backend but does not
pop a route. Use `mcp__dart__hot_restart`. A sweep of many variants cannot afford
one MCP call each. The `flutter run` process registers a service method
`s<N>.hotRestart`; call it over the Dart VM Service websocket with
`{"pause": false}`. Read `<N>` from the `ServiceRegistered` event of the
`Service` stream. The same method over the HTTP endpoint fails. A script can also
start `flutter run` with `stdin=PIPE` and write `R`. Wait for `Restarted
application` in the log, then give the driver extension a few seconds.

A profile build has no hot restart. The runner answers a `scenario` with a hot
restart, so a profile run stops with `No flutter run answers hotRestart`. The
scenario it applied is saved and seeds the next launch. Run the variant once to
save the scenario, relaunch the installed app, then walk the same variant with
`--no-mock` (it does not push the scenario again). Relaunch by `adb shell am force-stop <package>` and
`adb shell monkey -p <package> -c android.intent.category.LAUNCHER 1` on
Android, or a fresh `flutter run` on iOS. Read the new service uri off the
device and pass it as `--uri`. A skipped relaunch does not fail the run, so the
relaunch is unconditional.

Start a profile build for a measurement from `flutter clean` and `flutter pub
get`. Without them the build can package the native library of the earlier
build.

## 5. Read the report

The report is one line of JSON on stdout. A run without `--capture` also appends
a compact copy to `.dart_tool/automation_runner_runs.jsonl`. `dart run` can
print `Running build hooks...` to stdout without a newline, so parse from the
first `{`. A sweep reads its results from the ledger instead of walking again.

| Field | What it answers |
| --- | --- |
| `ok` | whether every step that ran succeeded |
| `steps[]` | `label`, `action`, `target`, `block`, `ms`, `ok`, plus `value` for a `ProbeCenter` and `error` for the step that stopped the run |
| `setupMs` | what pushing the scenario cost; zero means the variant declared none |
| `totalMs` | the steps alone |
| `commandMs` | the whole command, connection included: the number a target is measured against |
| `frames` | present when the variant traced: build and raster milliseconds, late frames, the slowest frames |

A `ProbeSeries` answers under `steps[]` with one entry per read, labelled
`<step label> <probe name> <cycle>`. The runner checks each probe `dy` series
alone: a sign change outside the dead-band fails the phase with a `monotonicity`
step.

The run stops at the first failed step. Every later step is **absent, not
passed**. How long the failed step took names the failure. A step that spent its
whole timeout resolved nothing: the id is absent, or the hit test refused a tap.
A step that failed in under three seconds resolved too much: a text finder
matched several widgets. That is a seed problem, fixed by seeding one of what the
step names, not by a cleverer finder.

One run is not a measurement. Take three runs and the median of `commandMs`.

## 6. Fix one thing per round

Rank a fix by where it belongs:

| Kind | Where it lands |
| --- | --- |
| `product` | the app misbehaves the same way for a user who does the step by hand: the fix is in the app, never a step, a timeout or a mock bent around it; propose it to the user |
| `flowVariant` | the step, its timeout or its order in the flow file |
| `mockScenario` | the state the failing step needed, in the variant `scenario` |
| `automationTarget` | a hand-assembled finder becomes an id (`add-automation-targets`) |
| `block` | a stretch that a second variant now shares |
| `runner` | a step kind or an option the runner package lacks |

One fix per round. Expand and run again. Two fixes in one round and the next
median cannot say which one moved it.

- A target below the fold needs two tools. `ScrollIntoView` calls
  `Scrollable.ensureVisible` and needs the element built. Past the cache extent
  nothing is built, and only a `Scroll` step with `dx` or `dy` reaches it.
  Overshoot instead of aiming, because a scroll clamps at the extent.
- A variant that proves an action is gated asserts that the id is **absent** with
  `WaitForAbsent`. It never asserts that a tap did nothing. A control that cannot
  act carries no id.
- A loading state is invisible while frame sync is on. A driver command waits for
  `transientCallbackCount` to reach zero before and after it runs, and an
  indeterminate progress indicator holds a ticker while it is mounted. A variant
  that proves a loader sends `DriverCommand('set_frame_sync', arguments:
  {'enabled': false})` before the tap and turns it on after the assertion.

In Claude Code with the plugin, the `flutter-automation:measure-flow` workflow
scripts the loop. It expands the variant, runs it three times and takes the
median. It diagnoses only when the run failed or missed the target, and it applies
exactly one fix. An agent that runs no workflow does the same loop by hand.

## 7. Post-edit steps

After a flow, a block, a target or a mock key changes, run the **After an edit**
commands and every item of **Post-edit steps**. A step that the field does not
list is not part of the project.

## 8. Verify

- The dry run expands clean and the run reports `ok: true`.
- A fix that touched Dart (a target, a block, the runner) passes the **After an
  edit** commands. Name the command and its result when you report it.
- Report the variant, its median `commandMs` and the step that dominates it.

## 9. Where a finding goes

A run teaches things by costing a timeout. A rule you learned goes into the
document that **Learned rules** names, as one sentence about what is true now.
Never write it into this skill: the skill is installed from the package and a
local edit is lost on the next update. If the field is missing, ask the user which
document takes it.

Some changes touch the flow format or the mock configuration: a new step or
finder, a new runner option, a key that a flow can declare. Such a change lands in
every place that **Format-change places** lists, in one commit, or nowhere.

A route through a flow spelled out as a list of ids is not a finding. It is a
variant, and it goes into the flow file.
