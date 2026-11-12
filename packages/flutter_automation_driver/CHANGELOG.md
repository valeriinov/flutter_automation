# Changelog

## Unreleased

- New `locale.save` command. It saves a language for the next launch of the
  app in a file in `Directory.systemTemp`. A `localeApplier` turns it on, as
  for `locale.apply`.
- New `AutomationInstaller.launchLanguageCode`. `maybeInstall` reads and
  removes the saved language, and the getter answers it for this launch only.
  The app reads it at startup to launch in the language of a `--locale` run.

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
