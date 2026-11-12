# flutter_automation_driver

Two sides of the Flutter Driver channel: the extension that the app installs and
the finders that the host uses to talk to it.

## Libraries

| Import | Host-safe | Holds |
| --- | --- | --- |
| `package:flutter_automation_driver/driver_extension.dart` | No, app only | `AutomationInstaller`, `AutomationDeviceCommands`, `AutomationScreenReader`, `AutomationLocaleApplier`, `AutomationProtocol`. |
| `package:flutter_automation_driver/flutter_automation_driver.dart` | Needs `flutter_driver` | `AutomationProtocol` and the serializable finders `UnmarkedText`, `UnmarkedTooltip`, `LocaleKeyText`, `LocaleKeyTooltip`. |

The app imports `driver_extension.dart`. The runner imports
`flutter_automation_driver.dart`. A project rarely imports the second one.

## API

### Install the extension

Call it as the first statement of `main`. The driver brings its own widgets
binding, and a process holds only one.

```dart
import 'package:flutter_automation_driver/driver_extension.dart';

void main() {
  AutomationInstaller.maybeInstall(
    screenReader: () => {AutomationProtocol.screenNameKey: 'login'},
  );
  runApp(const App());
}
```

`maybeInstall` returns at once unless `AutomationSettings.isEnabled` is true,
that is, unless the app runs with `--dart-define=ENABLE_AUTOMATION=true` in
a non-release build. Otherwise it:

- registers the `screen.read` and `keyboard.read` commands, and `locale.apply`
  when the call passes a `localeApplier`,
- calls `enableFlutterDriverExtension` with the command handler and the finders
  `UnmarkedText`, `UnmarkedTooltip`, `LocaleKeyText`, `LocaleKeyTooltip`,
- raises the semantics tree and, on request, the frame profiling spans.

The `screenReader` parameter describes the screen the app shows. The runner
compares its `screenName` with the `splashScreen` of the project to know when a
launch ends.

### Commands

- `screen.read` answers the screen, the view size, the keyboard inset and the
  platform. The request `{"texts": true, "widgets": true}` adds the texts and
  the widget types of the frame. Without the flags the command does not walk
  the widget tree.
- `locale.apply` takes `{"locale": <language code>}` and calls the
  `localeApplier` of the project. The runner sends it for `--locale`. The
  command needs no mock. Without a `localeApplier` the command is not
  registered, and `--locale` fails with a message that names the parameter.

```dart
AutomationInstaller.maybeInstall(
  screenReader: () => {AutomationProtocol.screenNameKey: 'login'},
  localeApplier: (languageCode) => setAppLanguage(languageCode),
);
```

## `pubspec.yaml` keys

None. The extension reads no `pubspec.yaml` section.
