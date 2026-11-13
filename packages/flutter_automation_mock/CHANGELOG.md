# Changelog

## 0.6.1

- Depends on `flutter_automation` 0.6.1.
- New getter `AutomationMock.journalResponseTimeout`. It returns the time
  `journal.read` waits for the requests the mock still has to answer.

## 0.6.0

- Depends on `flutter_automation` 0.6.0.

## 0.5.1

- Depends on `flutter_automation` 0.5.1.

## 0.5.0

- Breaking: `MockFeature` is `MockSection`, in the library `mock_section.dart`.
  A profile is a function over the settings. `MockSection.override` takes such a
  function. `MockField`, `MockFieldType` and the `fields` parameter are removed.
  `AutomationMock.features` is `sections`.
- Breaking: the latency and failure overrides are the constructors
  `MockOverride.latency`, `MockOverride.latencySeed` and
  `MockOverride.failures`. The statics of `MockScenario` are removed.
- A typed override replaces its section with the keys that differ from the
  defaults. A variant continues the list of overrides of its flow.
- Breaking: `MockTransportRuntime` is `MockBackend`.
  `MockApiTransport(backend:)` replaces `runtime:`. `MockApi.feature` is
  removed. `MockConnectionFailure` is `MockConnectionException`.
- New `MockScenarioBackend`: the ready `MockBackend` over the scenario. Its
  `rebuild()` builds the endpoints and the latency again.
- Breaking: the command `mock.apply` is `scenario.apply`
  (`MockCommands.scenarioApply`) and its payload key `config` is `scenario`.
  `onApply` is `onScenarioApplied` and `MockApplyCallback` is
  `MockScenarioAppliedCallback`.
- Breaking: `journal.read` carries no texts and no widgets. `onLocale`,
  `MockLocaleCallback` and `languageCode` are removed. `locale.apply` moves to
  `flutter_automation_driver`; the replacement of `onLocale` is the
  `localeApplier` of `AutomationInstaller.maybeInstall`.

## 0.4.0

- Breaking: the core has no Dio dependency. `MockApiRequest` and
  `MockApiResponse` carry no Dio types; `MockApiHttpClientAdapter` moves to the
  new package `flutter_automation_mock_dio` as `MockDioHttpClientAdapter`.
- New library `mock_feature.dart`, free of Flutter imports: `MockFeature` with
  profiles and a field schema, `MockScenario`, `MockOverride`,
  `MockLatencyProfile` and the names of the mock commands.
- New `AutomationMock`: `init` before the project's dependency injection,
  `substitute` for any dependency, the `mock.apply`, `journal.read` and
  `locale.apply` commands with the project callbacks `onApply` and `onLocale`,
  and the scenario saved to a file and read at the next launch.
