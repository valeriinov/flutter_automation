# Changelog

## 0.4.0

- Breaking: flows are Dart. The library `automation_flow_definition.dart`
  declares flows, variants, blocks and typed steps with `AutomationTarget`
  finders; it imports no Flutter code.
- Breaking: the project calls `runFlows(args, flows, blocks)` from its own
  entry file. The `run` executable and the `flows` key of the
  `flutter_automation:` section are removed.
- New options: `--catalogue` prints every flow and block as JSON, `--no-mock`
  walks a variant without `mock.apply`.
