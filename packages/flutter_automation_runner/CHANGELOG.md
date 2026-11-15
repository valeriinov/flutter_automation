# Changelog

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
