# Recipes

Every recipe replaces one object of the app. Two ways put a substitute in
place: `AutomationMock.substitute` at the place where the app creates the
object, and one installer that runs after the dependency injection built the
graph and replaces the registered objects. The recipes below use `substitute`.
The mock decides once, at start, whether the app runs on fakes.

## The release rule

A release build must hold no fake class, no `MockSection` and no profile name.
Two things keep it so.

1. `isEnabled` is a compile-time constant of the project. It folds to false in
   a release build.

   ```dart
   // lib/mock/mock_settings.dart
   import 'package:flutter_automation/flutter_automation.dart';

   const bool isMockEnabled =
       AutomationSettings.isEnabled && bool.fromEnvironment('ENABLE_MOCK');
   ```

   `AutomationSettings.isEnabled` is false when `kReleaseMode` is true, so no
   define turns the mock on in a release build. Read the flag from nowhere else:
   a value that a function or a file reads at run time is not a constant.

2. `AutomationMock.init` and `substitute` keep the shape below. `init` takes the
   constant and builds the mock; the fake is built only inside the `fake`
   closure of `substitute`.

   ```dart
   final mock = await AutomationMock.init(
     isEnabled: isMockEnabled,
     scenarioDirectory: directory,
     sections: isMockEnabled ? [catalogSection] : const [],
   );

   final object = mock.substitute<Thing>(
     real: Thing(),
     fake: (mock) => FakeThing(mock),
   );
   ```

   Do not keep a fake in a field, a top-level variable or a `static` that the
   app reads outside a `fake` closure. Do not build the fake before the call
   and pass it as `fake: (_) => alreadyBuilt`.

   Gate `sections:` with the same constant:
   `sections: isMockEnabled ? [catalogSection] : const []`. A section is a
   top-level value that holds closures. A release build keeps it, with its
   profile names, unless the constant gates the list.

   Pass the constant straight into the `isEnabled:` argument of
   `AutomationMock.init`. `init` hands it to the constructor outside an async
   body. A wrapper that takes the constant as a parameter, or builds the mock
   inside its own `async` body, hides it from the AOT compiler.

A check on a release build of an Android app:

```shell
fvm flutter build apk --release
unzip -p build/app/outputs/flutter-apk/app-release.apk lib/arm64-v8a/libapp.so > libapp.so
strings libapp.so | grep -cE 'FakeThing|<profile name>|<section name>'
```

The count is 0. `example/` of this repository passes this check.

## Dio

```dart
MockScenarioBackend? backend;

final mock = await AutomationMock.init(
  isEnabled: isMockEnabled,
  scenarioDirectory: directory,
  sections: isMockEnabled ? [catalogSection] : const [],
  onScenarioApplied: (scenario) => backend?.rebuild(),
);

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
final networkAdapter = dio.httpClientAdapter;

dio.httpClientAdapter = mock.substitute(
  real: networkAdapter,
  fake: (mock) {
    final scenarioBackend = MockScenarioBackend(
      readScenario: () => mock.scenario,
      buildApis: () => [CatalogMockApi(mock)],
      buildFailureBody: (failure) => {'message': failure.message},
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

The `MockScenarioBackend` takes the latency and the failures from the scenario.
A flow sets them with `MockOverride.latency(MockLatencyProfile.slow)` and
`MockOverride.failures({...})`. Paths that no `MockApi` owns go to
`networkAdapter`.

## shared_preferences

`SharedPreferences.setMockInitialValues` seeds the store before the first
`getInstance`. Substitute a factory so the seed runs only in the mock.

```dart
final Future<SharedPreferences> Function() openPreferences = mock.substitute(
  real: SharedPreferences.getInstance,
  fake: (mock) => () {
    final settings = mock.settingsOf(sessionSection);

    SharedPreferences.setMockInitialValues({
      'onboardingDone': settings.isOnboardingDone,
    });

    return SharedPreferences.getInstance();
  },
);
```

The analyzer reports `invalid_use_of_visible_for_testing_member` on
`setMockInitialValues`. Keep the call in one small file and silence the report
for that file only.

## flutter_secure_storage

```dart
final secureStorage = mock.substitute<FlutterSecureStorage>(
  real: const FlutterSecureStorage(),
  fake: (mock) {
    final settings = mock.settingsOf(sessionSection);

    FlutterSecureStorage.setMockInitialValues({
      if (settings.hasToken) 'accessToken': 'test-token',
    });

    return const FlutterSecureStorage();
  },
);
```

The same analyzer note applies to `setMockInitialValues`.

## Drift

The fake is the same database class over an in-memory executor. The seed comes
from the scenario and runs when the database is created.

```dart
@DriftDatabase(tables: [Notes])
class AppDatabase extends _$AppDatabase {
  final Future<void> Function(AppDatabase database)? _seed;

  AppDatabase(super.executor, {Future<void> Function(AppDatabase)? seed})
    : _seed = seed;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      if (details.wasCreated) {
        await _seed?.call(this);
      }
    },
  );
}

final database = mock.substitute<AppDatabase>(
  real: AppDatabase(driftDatabase(name: 'app')),
  fake: (mock) => AppDatabase(
    NativeDatabase.memory(),
    seed: (database) async {
      final count = mock.settingsOf(notesSection).noteCount;

      for (int id = 1; id <= count; id++) {
        await database.into(database.notes).insert(
          NotesCompanion.insert(title: 'Note $id'),
        );
      }
    },
  ),
);
```

`NativeDatabase.memory()` is an `import 'package:drift/native.dart'`. The seed
callback reads the scenario when the database opens, so `scenario.apply` followed by
a relaunch shows the new rows. Constructing a drift database opens nothing: the
file opens on the first query.
