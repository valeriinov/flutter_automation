# AGENTS.md

## Automation

The `flutter-automation` skills and workflows read this section for every fact
about this project. Commands run from the `example/` folder.

- **Flow run command**: `fvm dart run tool/run_flows.dart`.
- **Launch**: `--dart-define=ENABLE_AUTOMATION=true --dart-define=ENABLE_MOCK=true`.
- **Flows folder**: `tool/flows`.
- **Targets folder**: `lib/automation`.
- **Mock configuration file**: `lib/mock/catalog_mock_section.dart`.
- **QA build**: `fvm flutter build apk
  --dart-define=ENABLE_AUTOMATION_MARKING=true --dart-define=ENABLE_MOCK=true`.
- **QA catalogue**: `fvm dart run tool/run_flows.dart --qa-catalogue
  assets/qa_catalogue.json --recordings tool/recordings`.
- **QA panel file**: `lib/panel/example_panel.dart`.
- **Debug menu**: `lib/example_app.dart` opens the mode sheet. The Mock mode
  button in the app bar of `lib/login_screen.dart` opens it.
- **Default flow**: `catalog`.
- **After an edit**: `fvm dart format . && fvm dart analyze`.
- **Post-edit steps**: `fvm dart run tool/run_flows.dart --qa-catalogue
  assets/qa_catalogue.json --recordings tool/recordings --check`.
- **Format-change places**: none.
- **Learned rules**: `AUTOMATION_NOTES.md`.
