# Changelog

## 0.5.1

- No changes. The version follows the other packages.

## 0.5.0

- Breaking: the registry of commands is `AutomationCommandRegistry`. The
  function type that answers one command is `AutomationCommandHandler`.
- Breaking: the build switches are `ENABLE_AUTOMATION` and
  `ENABLE_AUTOMATION_LOCALE_KEYS`.

## 0.4.0

- New library `automation_target.dart` with `AutomationTarget`,
  `AutomationTargetType`, `AutomationIdComposer` and `AutomationTimelineLabel`.
  It imports no Flutter code, so target enums compile in the Dart VM of the
  host. The barrel `flutter_automation.dart` re-exports it.
