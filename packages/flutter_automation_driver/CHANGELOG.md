# Changelog

## 0.11.1

- New `frame.read` command (`AutomationProtocol.frameReadCommand`). It answers
  `loadingImages`, the count of shown images with no decoded frame, and
  `emptyTexts`, the count of shown texts with no visible character. It also answers `loadingImageItems` and
  `emptyTextItems`: up to 5 items of each kind, `{rect: [l, t, w, h], target}`,
  with the global rect in rounded logical pixels and the id of the nearest
  ancestor that the marking keys, or null.

## 0.11.0

- Version bump with `flutter_automation_atlas` 0.11.0.

## 0.10.0

- Version bump with `flutter_automation_mock` 0.10.0.

## 0.9.4

- Version bump with `flutter_automation_mock` 0.9.4.

## 0.9.3

- Version bump with `flutter_automation_mock` 0.9.3.

## 0.9.2

- Documentation: the commands list `keyboard.read`.

## 0.9.1

- Version bump with `flutter_automation_panel` 0.9.1.

## 0.9.0

- Version bump with `flutter_automation_panel` 0.9.0.

## 0.8.7

- Version bump with `flutter_automation_panel` 0.8.7.

## 0.8.6

- Version bump with `flutter_automation_mock` and `flutter_automation_panel` 0.8.6.

## 0.8.5

- Version bump with `flutter_automation_mock` and `flutter_automation_panel` 0.8.5.

## 0.8.4

- Version bump with `flutter_automation_panel` 0.8.4.

## 0.8.3

- Version bump with `flutter_automation_panel` 0.8.3.

## 0.8.2

- Version bump with `flutter_automation_panel` 0.8.2.

## 0.8.1

- Version bump with `flutter_automation_panel` 0.8.1.

## 0.8.0

- Depends on `flutter_automation` 0.8.0.

## 0.7.0

- Depends on `flutter_automation` 0.7.0.

## 0.6.1

- Depends on `flutter_automation` 0.6.1.

## 0.6.0

- Depends on `flutter_automation` 0.6.0.

## 0.5.1

- New `locale.save` command. It saves a language for the next launch of the
  app in a file in `Directory.systemTemp`. A `localeApplier` turns it on, as
  for `locale.apply`.
- New `AutomationInstaller.launchLanguageCode`. `maybeInstall` reads and
  removes the saved language, and the getter answers it for this launch only.
  The app reads it at startup to launch in the language of a `--locale` run.
- Depends on `flutter_automation` 0.5.1.

## 0.5.0

- Breaking: `screen.read` takes `{"texts": bool, "widgets": bool}` and reads the
  texts and the widget types of the frame on request. The mock no longer reads
  them in `journal.read`.
- New `locale.apply` command and `AutomationLocaleApplier`. The optional
  `localeApplier` parameter of `AutomationInstaller.maybeInstall` and
  `AutomationDeviceCommands.register` turns the command on. It needs no mock.
- Depends on `flutter_automation` 0.5.0.

## 0.4.0

- Depends on `flutter_automation` 0.4.0. No API change.
