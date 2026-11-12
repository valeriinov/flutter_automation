import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_driver/src/automation_device_commands.dart';
import 'package:flutter_automation_driver/src/automation_launch_locale_file.dart';
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
  static String? _launchLanguageCode;

  /// The language code that a run with `--locale` saved for this launch.
  ///
  /// The app starts in it, before its first request and its first frame, when
  /// the value is not `null`. It is `null` before [maybeInstall], without
  /// [AutomationSettings.isEnabled], and on a launch that no run saved a
  /// language for.
  static String? get launchLanguageCode => _launchLanguageCode;

  /// Installs the seams when [AutomationSettings.isEnabled] is true.
  ///
  /// Must run before anything touches a widgets binding. The driver brings its
  /// own, and a process gets only one. Call it as the first statement of the
  /// app's startup, right above the binding it would collide with.
  ///
  /// The [screenReader] parameter describes the screen the app shows when the
  /// `screen.read` command arrives.
  /// The [localeApplier] parameter applies the language of the `locale.apply`
  /// command. The command and `locale.save` stay unregistered without it.
  ///
  /// The method also reads and removes the language that `locale.save` left
  /// for this launch, and keeps it in [launchLanguageCode]. The next launch
  /// therefore starts in the language of the app again, unless a run saves a
  /// language once more.
  static void maybeInstall({
    required AutomationScreenReader screenReader,
    AutomationLocaleApplier? localeApplier,
  }) {
    if (!AutomationSettings.isEnabled) {
      return;
    }

    _launchLanguageCode = AutomationLaunchLocaleFile.consume();

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
