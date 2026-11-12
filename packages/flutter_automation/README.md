# flutter_automation

The base of the set: target markup, the registry of commands the app answers,
and the build switches. Every other package builds on it.

## Libraries

| Import | Host-safe | Holds |
| --- | --- | --- |
| `package:flutter_automation/automation_target.dart` | Yes, no Flutter import | `AutomationTarget`, `AutomationTargetType`, `AutomationIdComposer`, `AutomationTimelineLabel`. |
| `package:flutter_automation/flutter_automation.dart` | No, imports Flutter | Everything above, plus `automationTarget()`, `AutomationSettings`, `AutomationCommandRegistry`, `AutomationCommandHandler`, `AutomationTimeline`, `LocaleKeyMarker`. |

"Host-safe" means a program in the plain Dart VM can import the library. A flow
and the target enums it reads import only `automation_target.dart`.
`tool/host_probe.dart` runs that import in the Dart VM.

## API

### Targets

One enum per flow. The id is `<scope>.<type>.<name>`.

```dart
import 'package:flutter_automation/automation_target.dart';

enum CatalogTarget with AutomationIdComposer {
  screen(AutomationTargetType.screen),
  list(AutomationTargetType.panel);

  @override
  final AutomationTargetType type;

  const CatalogTarget(this.type);

  @override
  String get scope => 'catalog';
}
```

`CatalogTarget.list.id` is `catalog.panel.list`.

### Marking a widget

```dart
import 'package:flutter_automation/flutter_automation.dart';

ListView(children: tiles).automationTarget(CatalogTarget.list)
```

The id reaches the agent as a `ValueKey` for the driver finder and as a
`Semantics.identifier` for the native accessibility tree. When
`AutomationSettings.isEnabled` is false the call returns the widget untouched.

### Switches

`AutomationSettings` holds compile-time constants. Each one is false in a
release build.

| Constant | Define | Effect |
| --- | --- | --- |
| `isEnabled` | `ENABLE_AUTOMATION` | Master switch. |
| `isSemanticsEnabled` | `ENABLE_AUTOMATION_SEMANTICS` (default true) | Raises the semantics tree. |
| `isFrameProfilingEnabled` | `ENABLE_AUTOMATION_FRAME_PROFILING` | Names widgets and render objects in traced frames. |
| `isLocaleKeyMarkingEnabled` | `ENABLE_AUTOMATION_LOCALE_KEYS` | A translation string carries the mark of its key. |

### Commands

A subsystem registers what the app answers. `flutter_automation_mock` and
`flutter_automation_driver` use it.

```dart
AutomationCommandRegistry.register(
  'echo',
  (payload) async => '"${payload['text']}"',
);
```

An `AutomationCommandHandler` takes the decoded JSON payload and returns a JSON string.
A command that nothing registered throws, so a run fails before its first step.

### Timeline spans

`AutomationTimeline.span(label, body)` names the work of the app inside a
traced frame. A build without the switch calls `body` and nothing else.

## `pubspec.yaml` keys

None. This package reads no `pubspec.yaml` section. The runner reads the
`flutter_automation:` section; see
[`flutter_automation_runner`](../flutter_automation_runner).
