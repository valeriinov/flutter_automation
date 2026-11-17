# flutter_automation_mock

An in-memory backend for an app that runs under automation: the scenario of a
run, the sections that a project declares, the transport that answers requests
and the journal of what the app did. The package knows no HTTP client. For Dio
see [`flutter_automation_mock_dio`](../flutter_automation_mock_dio).

## Libraries

| Import | Host-safe | Holds |
| --- | --- | --- |
| `package:flutter_automation_mock/mock_section.dart` | Yes, no Flutter import | `MockSection`, `MockProfile`, `MockOverride`, `MockScenario`, `MockLatencyProfile`, `MockCommands`, `AutomationLocalizedText`. |
| `package:flutter_automation_mock/flutter_automation_mock.dart` | No, imports Flutter | Everything above, plus `AutomationMock`, `MockApi`, `MockApiEndpoint`, `MockApiTransport`, `MockBackend`, `MockScenarioBackend`, `MockJournal`, request and response types. |
| `package:flutter_automation_mock/mock_catalogue.dart` | Yes, no Flutter import | `AutomationCatalogue`, its flows and steps: the data of the QA panel. |

Declare each `MockSection` in a file that imports only `mock_section.dart`. A
flow on the host then names a profile by Dart symbol and the host builds without
Flutter.

## API

### Declare a section

The settings class holds the state of the section. Its `fromJson` must accept
`{}` and return the defaults. `jsonEncode` must reach its `toJson`. A
`copyWith` is a convention for the functions of the profiles, not a requirement.
A generator such as `freezed` writes all three.

```dart
import 'package:flutter_automation_mock/mock_section.dart';

final class CatalogSettings {
  final int itemCount;

  const CatalogSettings({this.itemCount = 3});

  factory CatalogSettings.fromJson(Map<String, Object?> json) {
    final itemCount = json['itemCount'];

    return CatalogSettings(itemCount: itemCount is int ? itemCount : 3);
  }

  CatalogSettings copyWith({int? itemCount}) {
    return CatalogSettings(itemCount: itemCount ?? this.itemCount);
  }

  Map<String, Object?> toJson() => {'itemCount': itemCount};
}

final catalogSection = MockSection<CatalogSettings>(
  name: 'catalog',
  title: AutomationLocalizedText.en('Catalog'),
  description: AutomationLocalizedText.en('Items of the catalog.'),
  fromJson: CatalogSettings.fromJson,
  restartKeys: {'itemCount'},
  profiles: {
    'empty': MockProfile(
      (settings) => settings.copyWith(itemCount: 0),
      title: AutomationLocalizedText.en('Empty shelf'),
      description: AutomationLocalizedText.en('The catalog has no items.'),
    ),
  },
);
```

The `description` of a section is optional and tells what part of the app it
feeds. `restartKeys` names a key that the app reads only on launch. It must be a
top-level key of the settings JSON: the panel asserts it in a debug build. The
section derives `settingsKeys` from the defaults and the profiles.

A profile is a `MockProfile`: a function over the settings, run by
`MockProfile.update(settings)`, and the texts that the QA panel shows for it.
The `title` of a section and of a profile is required. The
`description` of a profile is optional. An `AutomationLocalizedText` holds one text per
language code, such as `{'en': '...', 'uk': '...'}`.
`AutomationLocalizedText.en('...')` holds a text written in English only. The panel reads the
`languageCode` of its strings and falls back to `en`, then to the first text. The key of a setting is
written once, in the settings class. `catalogSection.profile('empty')` gives a `MockOverride`.
`catalogSection.override((settings) => ...)` gives one for a function the flow
holds. `MockOverride.latency(MockLatencyProfile.slow)`, `.latencySeed(7)`,
`.failures({...})` and `.latencies({...})` set the latency profile, its seed,
the failed paths and the latency profiles of single paths.

A flow lists overrides in `scenario:`. The scenario applies them in order. A
typed override receives the settings that the overrides before it built, and it
replaces its section with the keys that differ from the defaults. A key that a
function sets back to its default therefore leaves the scenario. A variant
continues the list of overrides of its flow: the flow overrides come first, then
the ones of the variant.

### Keep the state of a tester

`AutomationStateStore(directory)` writes `state.json` (mode, scenario,
walk, outcome failures), `presets/<name>.json` and `runs/<id>/report.json` (the last
20) atomically. Pass it to `AutomationMock.init` as `stateStore`. The mock then
starts from the scenario in `state.json`. A scenario file that `scenario.apply`
saved wins over it, also when the file holds an empty scenario. Then the mock
also starts without the walk and without the outcome failures of `state.json`.
`scenario.apply` ends the walk. The mock never writes `mode`. The walk holds
the flow, the variant, the step index (in the steps of the variant, service
steps included), its `AutomationWalkMode` (`manual` or `autorun`) and the two
autorun options.

`mock.saveOutcomeFailures(failures)` keeps the `failures` JSON of the outcome a
tester chose, and `mock.outcomeFailures` reads it back after a restart. The
panel uses it to tell the failures of the outcome from the overrides of the
tester.

`mock.updateScenario(next)`, `mock.setFailure(path, failure)` and
`mock.setLatency(path, profile)` replace the scenario at once, save it and call `onScenarioUpdated`. They neither reseed the
state nor clear the journal. `mock.requiresRestart(next)` is true when `next`
differs from the launch scenario in a key that `MockSection.restartKeys` lists.

### Start the mock

Call `AutomationMock.init` before the dependency injection of the app and keep
its result for the objects that read the scenario.

```dart
final mock = await AutomationMock.init(
  isEnabled: isMockEnabled,
  scenarioDirectory: (await getTemporaryDirectory()).path,
  sections: isMockEnabled ? [catalogSection] : const [],
);
```

- `isEnabled` must be a compile-time constant of the project, for example
  `bool.fromEnvironment('ENABLE_MOCK')`. Do not add
  `AutomationSettings.isEnabled`: it is false in a release build, and a QA
  release build runs the mock. A host with the QA panel passes
  `isMockEnabled && bootstrap.isOnMock`. The left operand is the compile-time
  constant. `bootstrap.isOnMock` is the part that the app reads at run time. The
  constant still lets the compiler drop the mock from a build without the
  define.
- `scenarioDirectory` holds the scenario between launches. `scenario.apply`
  saves it; the next launch reads it once and removes it.
- `sections` lists the sections. `requiresRestart` and the restart check of the
  QA panel read the list. Pass the full list under the same compile-time gate:
  `isMockEnabled ? [catalogSection] : const []`.
- A disabled mock registers no command and `substitute` answers the real
  object.
- An enabled mock registers `scenario.apply` and `journal.read` in
  `AutomationCommandRegistry`. The optional `onScenarioApplied` callback runs
  after the mock took the scenario.

The `screen.read` and `locale.apply` commands belong to
[`flutter_automation_driver`](../flutter_automation_driver). They need no mock.

### Substitute objects

Use one of two ways. Both answer the real object when the mock is disabled.

`substitute` replaces one object at the place where the app creates it:

```dart
final client = mock.substitute<ApiClient>(
  real: ApiClient(),
  fake: (mock) => ApiClient.over(MockApiTransport(...)),
);
```

`substitute` answers `fake(mock)` when the mock is enabled and `real`
otherwise.

One installer replaces the registered objects after the dependency injection
built the graph. The installer reads `mock.isEnabled` and does nothing when it
is false. Keep the installer behind the same compile-time constant, so a release
build drops it.

Read the scenario with `mock.settingsOf(catalogSection)` at the time of use, so
a later `scenario.apply` shows up without a restart.

### Answer requests

A `MockApi` owns endpoints. A `MockBackend` hands the transport the endpoint
resolver, the latency, the failures and the body of a failure.
`MockScenarioBackend` is the ready one: it reads the failures from the scenario
on each request, and it holds the endpoints and one latency object until
`rebuild()` runs.

```dart
final class CatalogMockApi implements MockApi {
  final AutomationMock _mock;

  const CatalogMockApi(this._mock);

  @override
  List<MockApiEndpoint> get endpoints => [
    MockApiEndpoint(
      path: '/catalog/items',
      title: AutomationLocalizedText.en('Catalog items'),
      respond: _respondItems,
    ),
  ];

  MockApiResponse _respondItems(MockApiRequest request) {
    final count = _mock.settingsOf(catalogSection).itemCount;

    return MockApiResponse(body: {'count': count});
  }
}

MockScenarioBackend? backend;

final mock = await AutomationMock.init(
  isEnabled: isMockEnabled,
  scenarioDirectory: directory,
  sections: isMockEnabled ? [catalogSection] : const [],
  onScenarioApplied: (scenario) => backend?.rebuild(),
);
```

Build the backend inside the `fake` closure of `substitute`:

```dart
backend = MockScenarioBackend(
  readScenario: () => mock.scenario,
  buildApis: () => [CatalogMockApi(mock)],
  buildFailureBody: (failure) => {'message': failure.message},
);
```

`MockApiTransport(backend: backend, journal: mock.journal)` answers a request
after the delay of the latency profile, records it in the journal and applies a
failure that the scenario names for the path. A path that no endpoint owns
reaches the network.

#### Endpoints

A `MockApiEndpoint` takes these parameters:

- `path` is the path of the endpoint, relative to the base url.
- `respond` builds the answer to a request for the path.
- `title` is the name of the request in the QA panel. Without it, the panel shows
  the path.
- `hasPathId` is true when the app appends a trailing segment to `path`. The
  responder reads the segment through `MockApiRequest.pathSegment`, or through
  `MockApiRequest.pathId` when it parses as an id.
- `backendErrorCodes` lists the codes that only this endpoint answers with. The
  QA panel offers the codes of every request first, from
  `AutomationPanelDefinition.backendErrorCodes`, then these. The panel needs
  `readEndpointResolver` in its definition to read them.
- `backendErrorStatusCodes` maps a code of this endpoint to the status codes it
  comes with, for example `{'token-expired': {401}}`. The QA panel then offers
  the code with these statuses alone. An entry here replaces the entry of the
  same code in `AutomationPanelDefinition.backendErrorStatusCodes`. A code
  without an entry comes with any status.

`MockApiEndpointResolver` matches a request path to an endpoint. It tries the
exact path first. Then it tries the endpoints with `hasPathId`, whose
`path + '/'` is a prefix of the request path, the longest path first. A failure
or a latency that the scenario keys by the request path or by the endpoint path
applies to the request.

[`example/`](../../example) holds a backend and an api that compile and run.

### When a change applies

| Change | When it takes effect |
| --- | --- |
| Failed paths | At once. The backend reads them on each request. |
| Failures and latencies of single paths | At once. `MockScenarioBackend` reads them from the scenario on each request. |
| Latency profile, latency seed | After `rebuild()` in `onScenarioApplied` or `onScenarioUpdated`. The backend builds its latency once per `rebuild()`. |
| Settings read with `settingsOf` at the time of use | At once. |
| Endpoints of a `MockScenarioBackend` | At once, after `rebuild()` in `onScenarioApplied` or `onScenarioUpdated`. |
| An object that a substitute seeds from the scenario when it creates it (storage, database) | After a restart of the app. |
| What the app reads once at launch (session, the link or push that opened it) | After a restart. The runner restarts the app after `scenario.apply`. |
| Whether the app runs on the mock, and which objects have a substitute | At build time: `isEnabled` is a compile-time constant. |

## Recipes

[`doc/recipes.md`](doc/recipes.md): Dio, `shared_preferences`,
`flutter_secure_storage`, Drift, and the rule that keeps the mock out of a
release build.

## `pubspec.yaml` keys

None. The runner reads the `flutter_automation:` section; see
[`flutter_automation_runner`](../flutter_automation_runner).
