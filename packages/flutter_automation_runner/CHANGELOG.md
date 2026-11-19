# Changelog

## 0.11.1

- A capture run fails on a frame that is not ready before a screenshot: a frame
  that still animates after 3 s, an image that still loads or an empty text.
  The report holds `frameDefect` with the `step` and the `kind`, the run exits
  with code 1, and it writes no screenshot of that frame, no end screenshot and
  no recording. The run asks the new `frame.read` command of the driver, so the
  app needs `flutter_automation_driver` 0.11.1.
- `frameDefect.items` holds up to 5 elements of the defect, each with its `rect`
  and `target`. The step `error` names the first one.
- The runner depends on `meta` for `@visibleForTesting`. A test fails when a
  library file imports `package:flutter/`.
- `FlowStep.showsLoading` declares the frame after a step as a loading state.
  A capture takes no frame defect from that frame.

## 0.11.0

- Version bump with `flutter_automation_atlas` 0.11.0.

## 0.10.0

- The QA catalogue has `version: 2`: each distinct answer of the mock stands
  once in `responses`, and each repeated string of 1024 characters or more
  stands once in `blobs`. Migration: regenerate the catalogue with
  `--qa-catalogue`.
- New `AutomationFlowArea` and `AutomationFlowGroup.area`. The catalogue
  carries `areas`.
- New `AutomationRunnerConfig.groupOrder` and `withGroupOrder`: the groups of
  the catalogue in display order. `AutomationCatalogueBuilder` takes
  `groupOrder`.
- A recording holds no screenshot names: `AutomationRecordedStep.screenshot`
  and `AutomationRecording.endScreenshot` are removed, and `--capture` with
  `--record` writes the same recording as a plain run.

## 0.9.4

- Version bump with `flutter_automation_mock` 0.9.4.

## 0.9.3

- Version bump with `flutter_automation_mock` 0.9.3.

## 0.9.2

- Documentation: the option table lists `--record`, `--recordings`,
  `--qa-catalogue`, `--check`, `--shoot` and `--until`; "Write a flow" names
  `FlowVariant.stateOf` and `AutomationFlowDefinition.subtitle`.

## 0.9.1

- Version bump with `flutter_automation_panel` 0.9.1.

## 0.9.0

- Breaking: `AutomationLocalizedText` lives in `flutter_automation_mock`, and
  `automation_flow_definition.dart` exports it, so flow files keep their
  imports. The strict `read(locale)` and the static `tryRead` move to the
  extension `AutomationLocalizedTextJson`; the type itself holds `texts`,
  `locales`, `resolve(languageCode)` and `toJson()`.
- `--check` after `--qa-catalogue <file>` writes nothing and tests that the file
  and the recordings are up to date. It prints one line of JSON with `ok` and
  the `problems`, and exits with code 1 when there is a problem. A problem is a
  catalogue file that differs from the flows and recordings, a variant without a
  recording, a recording of a failed run, step labels that differ from the
  flow, or a recording that no flow or variant holds.
- New `AutomationCatalogueBuilder.isInQaCatalogueKey`: the key of the flow JSON
  that puts a flow in the catalogue.

## 0.8.7

- Version bump with `flutter_automation_panel` 0.8.7.

## 0.8.6

- Version bump with `flutter_automation_mock` and `flutter_automation_panel` 0.8.6.

## 0.8.5

- Version bump with `flutter_automation_mock` and `flutter_automation_panel` 0.8.5.

## 0.8.4

- Version bump with `flutter_automation_panel` 0.8.4.

## 0.8.3

- Version bump with `flutter_automation_panel` 0.8.3.

## 0.8.2

- Version bump with `flutter_automation_panel` 0.8.2.

## 0.8.1

- Version bump with `flutter_automation_panel` 0.8.1.

## 0.8.0

- A recorded step keeps its `step` JSON. `AutomationRecordedStep.step` holds it.
- `AutomationCatalogueBuilder` fills the action, the finder, the text, the
  title, the timeout and the drag of a catalogue step. The fork stands at the
  earlier of the first parting step and the first differing request. A branch
  carries the title of its variant and `isChosenBeforeStart`.
- `AutomationCatalogueBuilder`, `AutomationRunner` and `runFlows` take
  `sections`.
- `AutomationCatalogueBuilder` takes `dateFormats` and `dateValueKeys`, and
  `--qa-catalogue` passes the ones of the `flutter_automation:` section. The
  catalogue carries them for the panel player.
- `AutomationDatePattern` comes from `flutter_automation`; the runner library
  still exports it. `AutomationFinderKind.resolveDate` is removed. Use
  `AutomationDatePattern.resolveDay`.
- The report holds `step` only in the run that `--record` writes.
- `AutomationStep.toPlayJson` writes `durationMs` and `frequency` for every
  scroll. A scroll without a drag is a finger hold.

## 0.7.0

- Depends on `flutter_automation` 0.7.0.
- New option `--record <dir>`: writes `<dir>/<flow>/<variant>.json` with the
  steps, the timings and the requests of each step. It needs a full run and
  writes the recording of a run that passed only.
- New options `--qa-catalogue <file>` and `--recordings <dir>`: write the
  catalogue of the QA panel. They need no device.
- New `AutomationFlowGroup`, `AutomationFlowDefinition.group` and
  `AutomationFlowDefinition.isInQaCatalogue`: the QA catalogue lists the flows
  that set it.
- `AutomationCatalogueBuilder` takes no `blocks` parameter.
- New library `automation_recording.dart`.

## 0.6.1

- Depends on `flutter_automation` 0.6.1.

## 0.6.0

- Depends on `flutter_automation` 0.6.0. A flow names one of the elements that a
  screen shows more than once with `ByTarget(<target>.withKey(key))`.

## 0.5.1

- `--locale <code>` launches the app in that language. The runner sends
  `locale.save` before the restart, restarts the app also under
  `--no-scenario`, and sends `locale.apply` after the restart. The app starts
  in the language when it reads `AutomationInstaller.launchLanguageCode` at
  startup.
- A run with `--locale` needs an app under `flutter run`, as a scenario does.
- The dry-run report names `relaunches`: whether the run restarts the app.
- Depends on `flutter_automation_driver` 0.5.1, which answers `locale.save`.

## 0.5.0

- Breaking: `runFlows(args, flows)` takes no list of blocks. The runner collects
  the blocks from the `Use` items of the variants. Two different blocks with
  one name stop the run.
- Breaking: `FlowVariant.use` is `items`, and the flow JSON key `use` is
  `items`. `AutomationEntry`, `AutomationBlockEntry`, `AutomationStepEntry` and
  `AutomationFlow.entries` are `AutomationItem`, `AutomationBlockItem`,
  `AutomationStepItem` and `items`.
- Breaking: the scenario has one name. `AutomationFlow.mockConfig` is
  `scenarioJson`. The key `mock` of the flow JSON and the report is `scenario`.
  The option `--no-mock` is `--no-scenario`. The report names `appliesScenario`.
- A variant writes its scenario as one list of overrides: the ones of the flow,
  then its own. The runner no longer merges two JSON objects. A flow or a
  variant that names a scenario applies it, also when the result is empty.
- A capture reads `journal.read`, then `screen.read` with the `texts` and
  `widgets` flags. The `--locale` error names the `localeApplier` parameter.
- Breaking: the pubspec key `frameGoalMs` is `frameBudgetMs`.
- `--catalogue` lists the blocks in the order of first use.

## 0.4.0

- Breaking: flows are Dart. The library `automation_flow_definition.dart`
  declares flows, variants, blocks and typed steps with `AutomationTarget`
  finders; it imports no Flutter code.
- Breaking: the project calls `runFlows(args, flows, blocks)` from its own
  entry file. The `run` executable and the `flows` key of the
  `flutter_automation:` section are removed.
- New options: `--catalogue` prints every flow and block as JSON, `--no-mock`
  walks a variant without `mock.apply`.
