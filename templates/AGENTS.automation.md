# AGENTS.md

## Automation

The `flutter-automation` skills and workflows read this section for every fact
about this project. Each field is one bullet. A skill that finds a field empty
or missing asks the user once and writes the answer here. Commands run from the
repository root.

- **Flow run command**: the command that walks flows, without the flow name.
  Example: `fvm dart run tool/run_flows.dart`. The skills append
  `<flow> [variant]` and the options `--dry-run`, `--catalogue`, `--no-scenario`,
  `--uri`, `--capture`, `--locale`.
- **Launch**: the arguments of `flutter run` that start the app for a walk, with
  the flavor, the entry point and the defines. Example:
  `--flavor dev -t lib/main_automation.dart --dart-define=ENABLE_AUTOMATION=true`.
  Add the define that turns the mock on when the project has one.
- **Flows folder**: the folder of the flow and block Dart files. Example:
  `tool/flows`.
- **Targets folder**: the folder of the target enums. Example:
  `lib/automation/targets`.
- **Mock configuration file**: the file that declares the `MockSection` values, or
  `none` when the project has no mock.
  Example: `lib/automation/mock/catalog_mock_section.dart`.
- **QA build**: the command that builds the app for testers: the flavor, the
  entry point, `--dart-define=ENABLE_AUTOMATION_MARKING=true` and the define that
  turns the mock on. Write `none` when the project has no QA panel. Example:
  `fvm flutter build apk --flavor qa -t lib/main_qa.dart
  --dart-define=ENABLE_AUTOMATION_MARKING=true --dart-define=ENABLE_MOCK=true`.
- **QA catalogue**: the command that rebuilds the catalogue asset, with the asset
  path and the recordings folder. The skills add `--check` to it. Write `none`
  when the project has no QA panel. Example:
  `fvm dart run tool/run_flows.dart --qa-catalogue assets/qa_catalogue.json
  --recordings tool/recordings`.
- **QA panel file**: the file that builds the panel with
  `AutomationPanelDefinition.standard`, or `none`. Example: `lib/automation/qa_panel.dart`.
- **Debug menu**: the file of the debug menu that holds the mock mode tile, and
  the gesture that opens the menu, or `none`. Example:
  `lib/debug/debug_menu.dart`, long press on the version label.
- **Atlas command**: the one command that calls `runAtlas`, or `none` when the
  project has no atlas. The skills append a subcommand and flags
  (`capture`, `stale`, `headless`, `render`, `bundle`, `--store`, `--locale`).
  Example: `fvm dart run tool/atlas.dart`.
- **Atlas store**: exactly one path, the default of `--store`: the folder of the
  snapshots, the declarations, the screenshots and the page, or `none`. A
  declaration record holds the parts of a source file that a snapshot read. Example:
  `docs/atlas`.
- **Atlas publish**: the project document that holds the publish procedure of
  the atlas, or `none`. A skill that finds a document runs the capture by it
  and not straight into **Atlas store**. Example: `docs/atlas_publish.md`.
- **Default flow**: the flow a skill walks when the user names none. Example:
  `login`.
- **After an edit**: the commands that format and analyze after a Dart edit, in
  order. Example: `fvm dart format . && fvm dart analyze`.
- **Post-edit steps**: what else a flow, a block, a target or a mock key change
  must update, one item per line: a generated catalogue, a
  documentation check. Write `none` when there is nothing.
- **Format-change places**: the places that change in one commit when the flow
  format or the mock sections change: the code, the documents and the
  skills of the project. Write `none` when the project does not change them.
- **Learned rules**: the document where an agent writes a rule it learned from a
  failed run. Example: `docs/agents/automation.md`. The `flutter-automation`
  skills never receive such a rule.
