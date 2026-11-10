import 'package:flutter_automation_runner/src/automation_android_device.dart';
import 'package:flutter_automation_runner/src/automation_ios_simulator.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

/// {@category Utils}
///
/// The one device in use that a run takes screenshots of and prepares the
/// system keyboard on.
///
/// The driver renders the Flutter layer alone, so a screenshot of the whole
/// device shows a system keyboard over it.
abstract interface class AutomationDevice {
  /// Finds the single live device of [platform], the name a `screen.read`
  /// answer gives.
  static Future<AutomationDevice> find(String platform) {
    return switch (platform) {
      'iOS' => AutomationIosSimulator.find(),
      'android' => AutomationAndroidDevice.find(),
      _ => throw AutomationRunnerException(
        'A system keyboard is read from a device screenshot, and the platform '
        '"$platform" has no way to take one. It takes iOS and android.',
      ),
    };
  }

  /// Keeps the software keyboard up over a focused field.
  Future<void> prepareKeyboard();

  /// Returns the PNG bytes of the whole device screen, the system keyboard
  /// included.
  Future<List<int>> takeScreenshot();
}
