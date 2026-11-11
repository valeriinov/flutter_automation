# flutter_automation_mock

An in-memory backend for an app that runs under automation: the scenario of a
run, the sections that a project declares, the transport that answers requests
and the journal of what the app did. The package knows no HTTP client. For Dio
see [`flutter_automation_mock_dio`](../flutter_automation_mock_dio).

## Libraries

| Import | Host-safe | Holds |
| --- | --- | --- |
| `package:flutter_automation_mock/mock_feature.dart` | Yes, no Flutter import | `MockFeature`, `MockField`, `MockFieldType`, `MockOverride`, `MockScenario`, `MockLatencyProfile`, `MockCommands`. |
| `package:flutter_automation_mock/flutter_automation_mock.dart` | No, imports Flutter | Everything above, plus `AutomationMock`, `MockApi`, `MockApiEndpoint`, `MockApiTransport`, `MockTransportRuntime`, `MockJournal`, request and response types. |

Declare each `MockFeature` in a file that imports only `mock_feature.dart`. A
flow on the host then names a profile by Dart symbol and the host builds without
Flutter.

## API

### Declare a section

```dart
import 'package:flutter_automation_mock/mock_feature.dart';

final class CatalogSettings {
  final int itemCount;

  const CatalogSettings({this.itemCount = 3});

  factory CatalogSettings.fromJson(Map<String, Object?> json) {
    final itemCount = json['itemCount'];

    return CatalogSettings(itemCount: itemCount is int ? itemCount : 3);
  }
}

const catalogFeature = MockFeature<CatalogSettings>(
  name: 'catalog',
  fromJson: CatalogSettings.fromJson,
  profiles: {
    'empty': {'itemCount': 0},
  },
  fields: [MockField(name: 'itemCount', type: MockFieldType.integer)],
);
```

A profile is a partial JSON map. `catalogFeature.profile('empty')` gives a
`MockOverride`; a flow lists overrides in `scenario:` and the runner merges them
in order (`MockScenario.toJson`). `MockScenario.latency(MockLatencyProfile.slow)`
sets the latency profile.

### Start the mock

Call `AutomationMock.init` before the dependency injection of the app and keep
its result for the objects that read the scenario.

```dart
final mock = await AutomationMock.init(
  isEnabled: isMockEnabled,
  scenarioDirectory: (await getTemporaryDirectory()).path,
  features: [catalogFeature],
);
```

- `isEnabled` must be a compile-time constant of the project, for example
  `AutomationSettings.isEnabled && bool.fromEnvironment('ENABLE_MOCK')`.
- `scenarioDirectory` holds the scenario between launches. `mock.apply` saves
  it; the next launch reads it once and removes it.
- A disabled mock registers no command and `substitute` answers the real
  object.
- An enabled mock registers `mock.apply`, `journal.read` and `locale.apply` in
  `AutomationCommandHandler`. The optional `onApply` and `onLocale` callbacks
  run after the mock took the scenario or the language.

### Substitute an object

```dart
final client = mock.substitute<ApiClient>(
  real: ApiClient(),
  fake: (mock) => ApiClient.over(MockApiTransport(...)),
);
```

`substitute` answers `fake(mock)` when the mock is enabled and `real`
otherwise. Read the scenario with `mock.settingsOf(catalogFeature)` at the time
of use, so a later `mock.apply` shows up without a restart.

### Answer requests

A `MockApi` owns endpoints. A `MockTransportRuntime` hands the transport the
endpoint resolver; the latency and the failures come from `mock.latency` and
`mock.failures`.

```dart
final class CatalogMockApi implements MockApi {
  final AutomationMock _mock;

  const CatalogMockApi(this._mock);

  @override
  Enum get feature => MockSection.catalog;

  @override
  List<MockApiEndpoint> get endpoints => [
    MockApiEndpoint(path: '/catalog/items', respond: _respondItems),
  ];

  MockApiResponse _respondItems(MockApiRequest request) {
    final count = _mock.settingsOf(catalogFeature).itemCount;

    return MockApiResponse(body: {'count': count});
  }
}
```

`MockApiTransport(runtime:, journal:)` answers a request after the delay of the
latency profile, records it in the journal and applies a failure that the
scenario names for the path. A path that no endpoint owns reaches the network.

[`example/`](../../example) holds a runtime and an api that compile and run.

## Recipes

[`doc/recipes.md`](doc/recipes.md): Dio, `shared_preferences`,
`flutter_secure_storage`, Drift, and the rule that keeps the mock out of a
release build.

## `pubspec.yaml` keys

None. The runner reads the `flutter_automation:` section; see
[`flutter_automation_runner`](../flutter_automation_runner).
