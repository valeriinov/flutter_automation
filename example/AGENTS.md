# AGENTS.md

## Automation

The `flutter-automation` skills and workflows read this section for every fact
about this project. Commands run from the `example/` folder.

- **Flow run command**: `fvm dart run tool/run_flows.dart`.
- **Launch**: `--dart-define=ENABLE_FLUTTER_DRIVER=true --dart-define=ENABLE_MOCK=true`.
- **Flows folder**: `tool/flows`.
- **Targets folder**: `lib/automation`.
- **Mock configuration file**: `lib/mock/catalog_mock_feature.dart`.
- **Default flow**: `catalog`.
- **After an edit**: `fvm dart format . && fvm dart analyze`.
- **Post-edit steps**: none.
- **Format-change places**: none.
- **Learned rules**: `AUTOMATION_NOTES.md`.
