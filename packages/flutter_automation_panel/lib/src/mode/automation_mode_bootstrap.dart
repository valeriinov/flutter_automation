import 'package:flutter/foundation.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/mode/automation_mode_controller.dart';

/// {@category StateManagement}
///
/// The project reads the mode, the state store and the restart flag before the
/// app builds its objects.
///
/// A project calls [restore] first in `main`, before its dependency
/// injection, and builds the mock from [isOnMock] and [store].
final class AutomationModeBootstrap {
  /// The store whose `state.json` holds the mode.
  final AutomationStateStore store;

  /// The mode that `state.json` holds.
  final AutomationMode mode;

  /// Whether the build lets the tester switch the mode.
  final bool isSwitchable;

  /// Whether the app runs on the mock. A build that cannot switch always runs
  /// on the mock. Any other build runs on the saved [mode].
  final bool isOnMock;

  /// Whether the app must restart.
  /// `AutomationModeController.switchTo` and the panel set it to true.
  /// An `AutomationRestartOverlay` listens to it.
  final ValueNotifier<bool> isRestartRequired = ValueNotifier(false);

  AutomationModeBootstrap._({
    required this.store,
    required this.mode,
    required this.isSwitchable,
    required this.isOnMock,
  });

  /// Reads the saved mode out of the folder [directory].
  ///
  /// The [directory] parameter is the folder of the state store, which the app
  /// can write and the system does not clean.
  /// The [isSwitchable] parameter says whether the build lets the tester
  /// switch the mode. A build that cannot switch stays on the mock.
  static Future<AutomationModeBootstrap> restore({
    required String directory,
    required bool isSwitchable,
  }) async {
    final store = AutomationStateStore(directory);

    final state = await store.read();

    return AutomationModeBootstrap._(
      store: store,
      mode: state.mode,
      isSwitchable: isSwitchable,
      isOnMock: !isSwitchable || state.mode == AutomationMode.mock,
    );
  }

  /// Creates the controller that switches the mode and sets
  /// [isRestartRequired].
  ///
  /// Returns `null` when the build cannot switch the mode.
  AutomationModeController? createModeController() {
    if (!isSwitchable) {
      return null;
    }

    return AutomationModeController(
      store: store,
      mode: isOnMock ? AutomationMode.mock : AutomationMode.server,
      isRestartRequired: isRestartRequired,
    );
  }
}
