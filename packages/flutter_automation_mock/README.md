# flutter_automation_mock

An in-memory backend for an app that runs under automation: the scenario of a
run, the sections that a project declares, the transport that answers requests
and the journal of what the app did. The package knows no HTTP client. For Dio
see [`flutter_automation_mock_dio`](../flutter_automation_mock_dio).

## Libraries

| Import | Host-safe | Holds |
| --- | --- | --- |
| `package:flutter_automation_mock/mock_section.dart` | Yes, no Flutter import | `MockSection`, `MockOverride`, `MockScenario`, `MockLatencyProfile`, `MockCommands`. |
| `package:flutter_automation_mock/flutter_automation_mock.dart` | No, imports Flutter | Everything above, plus `AutomationMock`, `MockApi`, `MockApiEndpoint`, `MockApiTransport`, `MockBackend`, `MockScenarioBackend`, `MockJournal`, request and response types. |

Declare each `MockSection` in a file that imports only `mock_section.dart`. A
flow on the host then names a profile by Dart symbol and the host builds without
Flutter.

## API

### Declare a section

The settings class holds the state of the section. It needs `fromJson`, `toJson`
and a `copyWith`. A generator such as `freezed` writes all three.

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
  fromJson: CatalogSettings.fromJson,
  profiles: {
    'empty': (settings) => settings.copyWith(itemCount: 0),
  },
);
```

A profile is a function over the settings. The key of a setting is written once,
in the settings class. `catalogSection.profile('empty')` gives a `MockOverride`.
`catalogSection.override((settings) => ...)` gives one for a function the flow
holds. `MockOverride.latency(MockLatencyProfile.slow)`, `.latencySeed(7)` and
`.failures({...})` set the latency profile, its seed and the failed paths.

A flow lists overrides in `scenario:`. The scenario applies them in order. A
typed override receives the settings that the overrides before it built, and it
replaces its section with the keys that differ from the defaults. A key that a
function sets back to its default therefore leaves the scenario. A variant
continues the list of overrides of its flow: the flow overrides come first, then
the ones of the variant.

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
  `AutomationSettings.isEnabled && bool.fromEnvironment('ENABLE_MOCK')`.
- `scenarioDirectory` holds the scenario between launches. `scenario.apply`
  saves it; the next launch reads it once and removes it.
- `sections` lists the sections. The package only keeps the list. Gate it with
  the same constant: `isMockEnabled ? [catalogSection] : const []`.
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
    MockApiEndpoint(path: '/catalog/items', respond: _respondItems),
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

[`example/`](../../example) holds a backend and an api that compile and run.

### When a change applies

| Change | When it takes effect |
| --- | --- |
| Failed paths | At once. The backend reads them on each request. |
| Latency profile, latency seed | After `rebuild()` in `onScenarioApplied`. The backend builds its latency once per `rebuild()`. |
| Settings read with `settingsOf` at the time of use | At once. |
| Endpoints of a `MockScenarioBackend` | At once, after `rebuild()` in `onScenarioApplied`. |
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
