# flutter_automation

Packages that let an agent drive a Flutter app on a device.

## Packages

- `flutter_automation` - target markup (`automationTarget()`), the on/off switches and the registry of commands the app answers.
- `flutter_automation_driver` - the Flutter Driver extension for the app (`driver_extension.dart`) and the finders for the host that drives it (`flutter_automation_driver.dart`).
- `flutter_automation_mock` - the Dio transport that answers requests from an in-memory mock, the request contract (`MockApi`, `MockApiEndpoint`) and the journal of requests. The project implements `MockTransportRuntime`.
- `flutter_automation_runner` - the `run` executable that walks flows of a running app (`fvm dart run flutter_automation_runner:run <flow> [variant]`), and `widget_tester_finders.dart`, the same flow finders as widget test `Finder`s. The project values come from a `flutter_automation:` section in its `pubspec.yaml` (`flows`, `defaultLocale`, `dateFormats`, `frameGoalMs`, `splashScreen`, `launchHint`, `finders`).

## Usage

Add the packages as git dependencies:

```yaml
dependencies:
  flutter_automation:
    git:
      url: https://github.com/valeriinov/flutter_automation.git
      path: packages/flutter_automation
      ref: 0.3.1
  flutter_automation_driver:
    git:
      url: https://github.com/valeriinov/flutter_automation.git
      path: packages/flutter_automation_driver
      ref: 0.3.1

  flutter_automation_mock:
    git:
      url: https://github.com/valeriinov/flutter_automation.git
      path: packages/flutter_automation_mock
      ref: 0.3.1

dev_dependencies:
  flutter_automation_runner:
    git:
      url: https://github.com/valeriinov/flutter_automation.git
      path: packages/flutter_automation_runner
      ref: 0.3.1
```

Install the driver extension before the widgets binding starts:

```dart
import 'package:flutter_automation_driver/driver_extension.dart';

void main() {
  AutomationInstaller.maybeInstall(screenReader: readScreen);
  // ...
}
```

Run the app with `--dart-define=ENABLE_FLUTTER_DRIVER=true`. A release build never enables the switch.

## Development

```shell
fvm flutter pub get
fvm dart run melos run analyze
fvm dart run melos run test
```

## License

MIT
