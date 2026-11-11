# Changelog

## 0.4.0

- New library `automation_target.dart` with `AutomationTarget`,
  `AutomationTargetType`, `AutomationIdComposer` and `AutomationTimelineLabel`.
  It imports no Flutter code, so target enums compile in the Dart VM of the
  host. The barrel `flutter_automation.dart` re-exports it.
