# Changelog

## 0.8.1

- Version bump with `flutter_automation_panel` 0.8.1.

## 0.8.0

- New `AutomationSettings.isMarkingEnabled` and the define
  `ENABLE_AUTOMATION_MARKING`. It has no `kReleaseMode` condition.
  `WidgetAutomationTarget.automationTarget` reads it, and `isEnabled` implies
  it. `isLocaleKeyMarkingEnabled` is also true under it. The driver and the
  other switches stay out of a release build.
- New library `automation_date_pattern.dart` with `AutomationDatePattern`,
  moved from the runner. It writes a day by a pattern (`format`, `resolveDay`,
  `writeDayText`, `writeDayKey`). The runner and the panel player read a date
  finder through it. It imports no Flutter code.

## 0.7.0

- No change; released together with the other packages.

## 0.6.1

- No change; released together with the other packages.

## 0.6.0

- New `AutomationTarget.withKey(key)` in the extension
  `AutomationTargetWithKey`. It returns the same target with the key of a
  record as the last id segment, `<scope>.<type>.<name>.<key>`, so an element
  that a screen shows more than once gets a target of its own. The key is a
  string or an int.

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
