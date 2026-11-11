# AGENTS.md

## Automation

The `flutter-automation` skills and workflows read this section for every fact
about this project. Each field is one bullet. A skill that finds a field empty
or missing asks the user once and writes the answer here. Commands run from the
repository root.

- **Flow run command**: the command that walks flows, without the flow name.
  Example: `fvm dart run tool/run_flows.dart`. The skills append
  `<flow> [variant]` and the options `--dry-run`, `--catalogue`, `--no-mock`,
  `--uri`, `--capture`, `--locale`.
- **Launch**: the arguments of `flutter run` that start the app for a walk, with
  the flavor, the entry point and the defines. Example:
  `--flavor dev -t lib/main_dev.dart --dart-define=ENABLE_FLUTTER_DRIVER=true`.
  Add the define that turns the mock on when the project has one.
- **Flows folder**: the folder of the flow and block Dart files. Example:
  `tool/flows`.
- **Targets folder**: the folder of the target enums. Example:
  `lib/automation/targets`.
- **Mock configuration file**: the file that declares the `MockFeature` list, or
  `none` when the project has no mock.
  Example: `lib/automation/mock/catalog_mock_feature.dart`.
- **Default flow**: the flow a skill walks when the user names none. Example:
  `login`.
- **After an edit**: the commands that format and analyze after a Dart edit, in
  order. Example: `fvm dart format . && fvm dart analyze`.
- **Post-edit steps**: what else a flow, a block, a target or a mock key change
  must update, one item per line: a generated catalogue, an atlas, a
  documentation check. Write `none` when there is nothing.
- **Format-change places**: the places that change in one commit when the flow
  format or the mock configuration changes: the code, the documents and the
  skills of the project. Write `none` when the project does not change them.
- **Learned rules**: the document where an agent writes a rule it learned from a
  failed run. Example: `docs/agents/automation.md`. The `flutter-automation`
  skills never receive such a rule.
