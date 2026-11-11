---
name: mock-app
description: Run the Flutter app on a device against an in-memory mock backend. Choose the mock scenario, tune a section through its MockFeature settings or profile, or add a mock api for an endpoint. Use for "run the app without a backend", "configure the mock", "show state X on the device", "mock the endpoint", "запусти без бэкенда", "настрой мок", "покажи состояние X на устройстве", "замокай эндпоинт", "запусти без бекенду", "налаштуй мок", "замокай ендпоінт", or any request to reproduce an app state without a remote environment.
argument-hint: "<the state you want to see>"
---

This skill turns a spoken request into the scenario, the settings or the code that
produce the state. The mock is built with `AutomationMock`, `MockFeature` and the
Dio adapter of the `flutter_automation_mock` and `flutter_automation_mock_dio`
packages.

Read the `## Automation` section of the project `AGENTS.md` first. This skill uses
the fields **Launch**, **Mock configuration file**, **After an edit**,
**Post-edit steps**, **Format-change places** and **Learned rules** (bold names). A
missing field: ask the user once and write the answer into the section. A
**Mock configuration file** of `none` means that the project has no mock: offer the
`setup-automation` skill (in Claude Code with the plugin:
`flutter-automation:setup-automation`) and stop.

Read the project documents that **Format-change places** lists for the mock before
you change anything: they describe which sections exist and what each key means.

**The mock behaves as the live backend does, never as a shortcut.** Every state it
serves and every event it pushes is one that the real backend produces. A feed
counts as read when the app calls the read endpoint, not because a query ran. One
fact has one writer. A payload has the wire shape that the response DTO reads
back. A divergence that looks right on screen is the bug reported next session.
When the mock and the live backend differ, the mock is the defect. Fix it at once.

## Running it

Run the app with the **Launch** arguments. They carry the define that turns the
mock on. `AutomationMock.init(isEnabled: ...)` receives the project decision, so
read the project code for the expression. A release build must ignore the define.
Reach a remote environment only when a backend bug is suspected, and never a
production one.

An enabled mock registers three commands in `AutomationCommandHandler`:
`mock.apply` takes a scenario as JSON, saves it for the next launch and runs the
`onApply` hook of the project. `journal.read` answers the requests the mock
served, the launch record, and on request the texts and the widget types of the
frame. `locale.apply` takes a language code and runs the `onLocale` hook.

## What a change costs

Answer this before you touch anything. It decides whether a file needs an edit.

| Changed | Costs |
| --- | --- |
| a value that a flow declares in its `scenario` | nothing: no restart, no rebuild; the next run pushes it |
| a default of a settings class, or the code that reads it | a hot **restart**, which re-seeds the state; a hot reload does not |
| the define that turns the mock on | a fresh `flutter run`, because it is a compile-time constant |

A request that needs only a different state is answered by the `scenario` of a
flow variant, with no rebuild and no Dart edit. `run-flow` owns writing it (in
Claude Code with the plugin: `flutter-automation:run-flow`). This skill owns what
the values mean. Edit the default in Dart when the mock should answer that way for
everyone.

## Request to setting

A `MockFeature<S>` is one section of the mock. Its `name` is the section key in the
scenario JSON. `fromJson` builds the settings class `S`. `profiles` are named
partial settings. `fields` describe the settings for a generic editor. Find the
list in the **Mock configuration file**.

- A request for a ready-made state: look for a `profile` of the feature
  (`feature.profile('name')`). A profile holds only the keys it changes, so it
  merges over the scenario.
- A request for one value: `feature.override({'field': value})`, or a
  `MockOverride(key, value)`.
- **Read the settings class before you name a field.** A key that the class does
  not read is dropped in silence. The run then proves something other than what
  was asked. A `Duration` field is a number in JSON. Read its unit out of the
  `fromJson` of the class instead of guessing it.
- Three keys sit above the sections:
  - `latency` is a latency profile name. The fast profile adds no delay.
  - `latencySeed` makes two runs spend the same wall clock.
  - `failures` is keyed by endpoint path. `{"statusCode": 500}` answers an error.
    `{"isConnectionError": true}` answers a request that never reaches the backend.
- The scenario merges in order, deep, and the later leaf wins.
- A state that the app reads while it starts (the session, a launch link) answers
  from the launch after `mock.apply`. `mock.apply` saves the scenario into a file
  in the scenario folder that `AutomationMock.init` got. The next launch, a hot
  restart included, reads it once and removes it. The runner restarts the app after
  every scenario. A hand-driven session pushes the scenario and restarts the app.
- A mocked run leaves nothing on the device but that file, when the project
  substitutes its storages through `automationMock.substitute<T>(real:, fake:)`.
  `substitute` answers `real` when the mock is disabled, so a release build never
  builds the fake.

## Recipes

**Reproduce one state end to end.** Pick the profile, then check whether the
request also implies a value. A request for a state with a detail is a profile
plus one override, not one of them.

**Reproduce a loader, a race or a timeout.** Raise the latency profile to the slow
one. Spinners, disabled buttons and double-tap races last long enough to see. Use
the fast profile when the run measures the app and not the network.

**Reproduce an error state.** Add the endpoint path to `failures` with the status
that the backend answers. It reaches the error mapping of the app without a line of
code in the api that owns the path.

**Add a mock api for a section that has none.** Write a class that implements
`MockApi` with one `MockApiEndpoint` per endpoint it owns (`path`, `respond`,
`hasPathId` for a path that ends in an id). Add it to the list that the project
passes to the transport, and add the state it reads to the mock state. The
`MockApiEndpointResolver` sends a path that no api owns to the network, and
`MockApiTransport` answers the rest. The Dio adapter of
`flutter_automation_mock_dio` puts the transport under a `Dio` instance, so
interceptors, token refresh and DTO parsing run for real.

**Build a payload.** A data DTO serializes itself with `toJson()`. Build the
wrapper of a response from the project response shape, never from a response DTO
`toJson`, which can write a shape that its own `fromJson` cannot read. A file is
answered with `MockApiResponse.fromBytes` and its content type. The bytes that a
request sends arrive in `MockApiRequest.bytes`.

**Add a knob that does not exist yet.** Add the field, with its default and its
Dartdoc, to the settings class of the feature. Regenerate code if the class is
generated. Read the field where the state is built. Add the key to the `fields` of
the `MockFeature`. A field that the settings class does not hold cannot be reached
from a flow.

## Verifying

1. Run the **After an edit** commands.
2. Run **Post-edit steps**.
3. Report what the user sees after a hot restart. A settings change is verified by
   reading and tests, not by a run. Say so plainly unless you launched the app.

## Keeping documents in sync

A value changed inside its documented range needs no document change. A new
setting, a new profile, a new feature or a changed meaning needs more. It lands in
every place that **Format-change places** lists for the mock, in one commit. It
also lands in the Dartdoc of the new member. Run **Post-edit steps**. A rule you learned from a run goes into
the document that **Learned rules** names. Never write it into this skill: the skill
is installed from the package, and a local edit is lost on the next update.
