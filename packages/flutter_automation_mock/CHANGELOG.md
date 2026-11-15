# Changelog

## 0.8.0

- `AutomationCatalogueStep` carries `action`, `finder`, `text`, `title`,
  `timeoutMs`, `dx`, `dy`, `durationMs` and `frequency`, so a player can do the
  step.
- `AutomationCatalogueFork.method` and `path` are nullable: a fork that stands
  at a step where the steps of the variants differ names no request.
- New `AutomationCatalogueBranch.isChosenBeforeStart`.
- `AutomationCatalogue` carries `dateFormats` and `dateValueKeys`, so a player
  reads a date finder as the runner does. The key names of
  `AutomationCatalogueStep` are public constants (`actionKey`, `finderKey`
  and the others).
- New `AutomationWalkMode` and the fields `mode`, `shouldShowTouches` and
  `shouldSignalEnd` of `AutomationWalkProgress`, with `onVariant`. `state.json`
  keeps them. A walk saved without a mode is a manual walk.

## 0.7.0

- Depends on `flutter_automation` 0.7.0.
- New `AutomationStateStore`: the files of a tester in one folder
  (`state.json`, `presets/<name>.json`, `runs/<id>/report.json`, the last 20).
- New `AutomationMock.init` parameters `stateStore` and `onScenarioUpdated`.
  The mock starts from the scenario in `state.json`. A scenario that
  `scenario.apply` saved wins over it, also when its scenario is empty, and
  the mock then starts without the walk and the outcome failures.
  `scenario.apply` ends the walk.
- `AutomationStateStore.update` reads, changes and writes `state.json` in one
  step. The writes of one folder run one after another.
- New methods `updateScenario`, `setFailure`, `requiresRestart`, `saveWalk`,
  `saveOutcomeFailures` and getters `launchScenario`, `stateStore`, `walk`,
  `outcomeFailures`. `updateScenario` neither
  reseeds nor clears the journal.
- New optional `MockSection.restartKeys`: the settings the app reads once at
  launch. The default is an empty set.
- `MockScenarioFile.save` creates its folder.
- `MockJournal` is a `ChangeNotifier` and has a `records` getter that does
  not clear the journal.
- New library `mock_catalogue.dart`: `AutomationCatalogue` and its flows and
  steps. It has no `dart:io` and no runner type.

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
