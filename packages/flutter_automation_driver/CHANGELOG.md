# Changelog

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
