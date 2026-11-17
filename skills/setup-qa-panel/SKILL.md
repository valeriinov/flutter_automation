---
name: setup-qa-panel
description: Add the QA panel to a Flutter app that already has the flutter_automation mock. Add the panel dependency, the mode bootstrap, the panel file, the restart screen, the mock mode tile in the debug menu, the catalogue asset, the QA build and the QA catalogue check. Safe to run twice. Use for "add the QA panel", "set up the QA build", "rebuild the QA catalogue", "подключи QA-панель", "QA-сборка", "каталог QA", "підключи QA-панель", "QA-збірка", "каталог QA".
argument-hint: "[flavor of the QA build]"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

The QA panel is a screen inside a test build. A tester picks a flow and its
outcome, changes one request, and the in-app player walks the flow. This skill
connects the `flutter_automation_panel` package to a project. The project writes
its flows, its section texts, its `restartKeys` and a few fields. The package
holds all other code.

Every step starts with a check of the current state. It changes a file only when
the check fails. A second run changes nothing and says so. Never overwrite a real
value: report it.

## 1. Read the fields

Read the `## Automation` section of the project `AGENTS.md`. This skill uses
the fields **Mock configuration file**, **Flows folder**, **Launch** and
**After an edit**. It also uses the fields **QA build**, **QA catalogue**,
**QA panel file**, **Debug menu** and **Post-edit steps**.

- A **Mock configuration file** of `none` means that the project has no mock. Run
  the `setup-automation` skill with the mock (in Claude Code with the plugin:
  `flutter-automation:setup-automation`). Then come back.
- Tell the user the tag from `skills-lock.json` or from the installed plugin
  (`setup-automation` step 1 describes both). Use it for every `ref`.
- A QA field (**QA build**, **QA catalogue**, **QA panel file**, **Debug menu**)
  of `none` counts as unset. This skill replaces `none` with the real value.
- A field that is empty or missing: find candidates, ask the user one question and
  write the answer into the section. Step 8 lists where to look.

## 2. Add the dependency

Add `flutter_automation_panel` to `dependencies` in `pubspec.yaml` in the form of
the other packages, with the tag as `ref`. Run `fvm flutter pub get`. Drop `fvm`
when the project has no `.fvmrc`.

## 3. Write the panel file

The **QA panel file** holds one function that builds the panel. Take the shape
from `example/lib/panel/example_panel.dart` in the package repository:

1. `AutomationCatalogueAsset.load(rootBundle, '<asset path>')` returns the
   catalogue, or `null` when the file is missing or broken. Pass `catalogue ??
   const AutomationCatalogue()` and keep the panel.
2. `AutomationPanelController(AutomationPanelDefinition.standard(...))` takes the
   `mock`, the `catalogue`, the `isRestartRequired` flag of the bootstrap and one
   `AutomationSectionPanel.fromSection(section, api: <mock api>)` for each
   `MockSection`. The texts come from the declarations of the section, the
   profiles and the endpoints.
3. Add `wrapPage`, `onShare`, `backendErrorCodes` or `playerSettings` only when the
   project needs them. `backendErrorCodes` holds only the codes that every request
   can answer with. A code that one endpoint answers with goes on its
   `MockApiEndpoint`.

Add the file path to **QA panel file**.

## 4. Change `main`

1. Before the dependency injection, call `AutomationModeBootstrap.restore(directory:
   ..., isSwitchable: kReleaseMode)`. The `directory` is a folder in the support
   folder of the app.
2. Pass `bootstrap.store` as `stateStore`,
   `isEnabled: isMockEnabled && bootstrap.isOnMock`, and
   `onScenarioUpdated: (scenario) => backend?.rebuild()` to `AutomationMock.init`.
   The panel changes a failure, a latency or a profile only through
   `onScenarioUpdated`. `backend` is the `MockScenarioBackend` of the app.
3. Build the panel controller only when `isMockEnabled && bootstrap.isOnMock` is
   true. In server mode the app has no panel controller.
4. In the `builder` of the app, put `AutomationRestartOverlay(isRestartRequired:
   bootstrap.isRestartRequired, child: ...)` around the
   `AutomationPanelLauncher`. When the controller is `null`, the overlay wraps the
   app alone. The overlay works in both modes.

## 5. Add the mode tile

Call `bootstrap.createModeController()` when the mock is on (`isMockEnabled`).
It returns `null` when the build cannot switch the mode. Put
`AutomationMockModeTile` in the debug menu with that controller, and hide the
tile when it is `null`. Write the file and the gesture that opens the
menu in **Debug menu**. A project that has no debug menu: ask the user where the
tile goes. The `example/` app shows a button in the app bar.

## 6. Add the asset and the QA build

- List the catalogue asset in `flutter: assets:` of `pubspec.yaml`. When the
  project uses flavors, add `flavors:` with the flavor of the QA build only.
- **QA build** holds the build command. It builds a release app, because only a
  release build switches the mode. It sets `ENABLE_AUTOMATION_MARKING=true`
  and the define that turns the mock on. The panel finds its targets only with
  marking on. Write the command into the field.

## 7. Fill the catalogue and check it

1. Set `isInQaCatalogue: true` on each flow that testers pick.
2. Walk each variant of those flows with `--record` (the `run-flow` skill does it).
3. Run the **QA catalogue** command. It writes the asset.
4. Run it again with `--check`. The result must be `"ok":true`. Each line of
   `problems` has an action: see the list of problems in the `run-flow` skill.
5. Add the **QA catalogue** command with `--check` as a line of **Post-edit
   steps**.

## 8. Find the facts of an empty field

Look in these places only. They belong to every Flutter project.

- `flutter: assets:` with `flavors:` in `pubspec.yaml` for the asset and the flavor.
- `productFlavors` in `android/app/build.gradle*` and the schemes in `ios/` for the
  flavors.
- `lib/**/main*.dart` for the entry points.
- The file that calls `AutomationMock.init` for the mode switch and the mock define.

Give the user the candidates in one question. Write the answer into the field.

## 9. Verify

- Run the **After an edit** commands.
- Run the **QA catalogue** command with `--check`. Name the command and its result
  in the report.
- Launch the app with **Launch** by the `drive-device` skill. That is a debug
  build on the mock. The QA button must open the panel. Say so plainly when you
  did not launch it.
- The mode tile shows only in the **QA build**, a release build. The agent does
  not drive a release build. Ask the user to install the **QA build** and
  switch the mode, or say in the report that nobody checked the switch.
