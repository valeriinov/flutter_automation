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

- reads and removes the language that `locale.save` left for this launch, and
  keeps it in `AutomationInstaller.launchLanguageCode`,
- registers the `screen.read` and `keyboard.read` commands, and `locale.apply`
  and `locale.save` when the call passes a `localeApplier`,
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
- `locale.save` takes `{"locale": <language code>}` and saves the language for
  the next launch. The runner sends it for `--locale` before it restarts the
  app.

### Launch language

A hot restart drops every Dart object. `locale.save` therefore writes the code
to a file in `Directory.systemTemp`: the engine points it at the cache folder
of the app on Android and at the `tmp` folder of the app on iOS. The next
`maybeInstall` reads and removes the file. `AutomationInstaller.launchLanguageCode`
then answers the code for this launch only. The launch after it answers `null`,
so a run without `--locale` starts in the language of the app.

The app keeps no language file of its own. It reads
`AutomationInstaller.launchLanguageCode` once at startup, after `maybeInstall`
and before its first request and its first frame:

```dart
AutomationInstaller.maybeInstall(
  screenReader: () => {AutomationProtocol.screenNameKey: 'login'},
  localeApplier: (languageCode) => setAppLanguage(languageCode),
);

final startLanguageCode =
    AutomationInstaller.launchLanguageCode ?? readSavedLanguageCode();
```

An app that does not read the value launches in its own language. The runner
then switches it with `locale.apply` before the first step.

## `pubspec.yaml` keys

None. The extension reads no `pubspec.yaml` section.
