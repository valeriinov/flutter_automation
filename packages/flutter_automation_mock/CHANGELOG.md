# Changelog

## 0.13.2

- Version bump with `flutter_automation_runner` 0.13.2.

## 0.13.1

- Version bump with `flutter_automation` 0.13.1.

## 0.13.0

- New `MockApiFailure.resolveMessage`: the text of a failure, in this order:
  `message`, the text of `messageKey` in the language of the request, the text
  of `messageKey` in the default language, `errorCode`, `messageKey` itself.
- New `MockApiRequest.languageCode`: the primary subtag of the first range of
  `acceptLanguage`, in lower case.
- New `CatalogueBlobs` in `mock_catalogue.dart`: stores every long string a
  JSON object repeats once, for the QA catalogue and the atlas page.
  `AutomationCatalogueTables` has no `minBlobLength`, `blobReferenceKey` or
  `blobsKey`; `CatalogueBlobs` holds them.

## 0.12.0

- Breaking: `MockBackend.buildFailureBody` and the `buildFailureBody` callback
  of `MockScenarioBackend` take the `MockApiRequest` the failure answers, so
  the body can follow the request, such as a message in its language.
  Migration: add the request parameter to the callback.
- New `MockApiFailure.messageKey`: the key of a message the project keeps in
  each app language. The package only stores the key. A body builder of the
  project reads it.

## 0.11.0

- Version bump with `flutter_automation_atlas` 0.11.0.

## 0.10.0

- `AutomationCatalogue.toJson` writes `version: 2` and stores each distinct
  response once in `responses` and each repeated string of 1024 characters or
  more once in `blobs`. `fromJson` reads that format and throws an
  `AutomationCatalogueVersionException` for a missing or unknown `version`.
  Migration: regenerate the catalogue.
- New `AutomationCatalogueArea`, `AutomationCatalogue.areas` and
  `AutomationCatalogueGroup.area`.

## 0.9.4

- New `MockApiEndpoint.backendErrorStatusCodes`: the status codes that a
  backend error code of the endpoint comes with.

## 0.9.3

- New `AutomationLocalizedText.en(text)`: a text written in English only.
  `texts` is a getter that answers `{'en': text}` for it.

## 0.9.2

- Documentation: the README describes the endpoints (`title`, `hasPathId`,
  `backendErrorCodes`, the resolver match), `restartKeys`, the content of
  `state.json`, what `sections` feeds and when a latency of a single path
  applies.

## 0.9.1

- New `MockApiEndpoint.backendErrorCodes`: the backend error codes that only
  this endpoint answers with. The QA panel offers them for its requests.

## 0.9.0

- Breaking: `MockSection` takes a required `title` and an optional
  `description` (`AutomationLocalizedText`), and `profiles` is
  `Map<String, MockProfile<S>>`. `MockProfile(update, title:, description:)`
  carries the function over the settings and the texts of the profile.
  `MockProfile.update(settings)` runs it. A `profile('name')` gives the same
  override as before.
- New `MockSection.settingsKeys`: the top-level keys that the defaults and the
  profiles write.
- New `MockApiEndpoint.title`: the title of the request in the QA panel.
- `AutomationLocalizedText` moves here from `flutter_automation_runner`, with
  `texts` and `resolve(languageCode)`: the `languageCode` text, else `en`,
  else the first text. `mock_section.dart` exports it and stays free of Flutter.

## 0.8.7

- Version bump with `flutter_automation_panel` 0.8.7.

## 0.8.6

- The journal marks an answer that an override of the tester gave: the record
  carries `override`, such as `{"failure": true, "latency": "slow"}`. A record
  of an answer with no override stays as it was, so recordings and the QA
  catalogue do not change. `MockJournal.attachResponse` takes `override`.

## 0.8.5

- New scenario key `latencies`: path to the name of a latency profile. That
  path answers after the delay of its own profile; every other path keeps
  `latency`. The delay still comes from the seeded generator, so two runs
  spend the same wall clock. A value that names no profile is skipped.
- New `MockOverride.latencies`, `MockScenarioReader.readLatencies`,
  `AutomationMock.latencies` and `AutomationMock.setLatency(path, profile)`.
- `AutomationStateStore` writes `state.json`, the presets and `report.json`
  as indented JSON, so a shared report reads line by line.
- `MockBackend` takes `latencies`, and `MockLatency.waitOut` takes the profile
  of a single path. A project with its own `MockBackend` adds the getter.

## 0.8.4

- Version bump with `flutter_automation_panel` 0.8.4.

## 0.8.3

- Version bump with `flutter_automation_panel` 0.8.3.

## 0.8.2

- Version bump with `flutter_automation_panel` 0.8.2.

## 0.8.1

- Version bump with `flutter_automation_panel` 0.8.1.

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
