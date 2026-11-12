import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_driver/src/automation_device_commands.dart';
import 'package:flutter_automation_driver/src/automation_locale_applier.dart';
import 'package:flutter_automation_driver/src/automation_screen_reader.dart';
import 'package:flutter_automation_driver/src/unmarked_text_finder.dart';

/// Opens the app to an agent that drives it on a device.
///
/// Turns on the runtime seams the agent talks through. Flutter Driver serves
/// the widget tree. The data channel carries the commands, which is how a run
/// puts the app into the state it will walk. Under
/// [AutomationSettings.isSemanticsEnabled], the semantics tree gives the native
/// automation layer the identifiers. Under
/// [AutomationSettings.isFrameProfilingEnabled], the per-widget build spans and
/// per-render-object paint spans give a frame summary its attribution.
abstract final class AutomationInstaller {
  /// Installs the seams when [AutomationSettings.isEnabled] is true.
  ///
  /// Must run before anything touches a widgets binding. The driver brings its
  /// own, and a process gets only one. Call it as the first statement of the
  /// app's startup, right above the binding it would collide with.
  ///
  /// The [screenReader] parameter describes the screen the app shows when the
  /// `screen.read` command arrives.
  /// The [localeApplier] parameter applies the language of the `locale.apply`
  /// command. The command stays unregistered without it.
  static void maybeInstall({
    required AutomationScreenReader screenReader,
    AutomationLocaleApplier? localeApplier,
  }) {
    if (!AutomationSettings.isEnabled) {
      return;
    }

    AutomationDeviceCommands.register(
      screenReader: screenReader,
      localeApplier: localeApplier,
    );
    enableFlutterDriverExtension(
      handler: AutomationCommandRegistry.handle,
      finders: [
        UnmarkedTextFinder.text(),
        UnmarkedTextFinder.tooltip(),
        LocaleKeyFinder.text(),
        LocaleKeyFinder.tooltip(),
      ],
    );

    if (AutomationSettings.isFrameProfilingEnabled) {
      debugProfileBuildsEnabled = true;
      debugProfilePaintsEnabled = true;
    }

    if (!AutomationSettings.isSemanticsEnabled) {
      return;
    }

    SemanticsBinding.instance.ensureSemantics();
  }
}
