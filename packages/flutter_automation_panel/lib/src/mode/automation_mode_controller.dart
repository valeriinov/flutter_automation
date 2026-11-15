import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';

/// {@category StateManagement}
///
/// The mode of the app, server or mock, without a screen.
///
/// A switch of the mode needs a restart: the app builds its objects once.
/// [switchTo] writes the mode to the state file and calls [onRestartRequired].
/// The project shows its own restart screen there.
class AutomationModeController extends ChangeNotifier {
  /// The store whose `state.json` holds the mode.
  final AutomationStateStore store;

  /// Called after the mode is saved and the app must restart.
  final FutureOr<void> Function() onRestartRequired;

  /// The mode the app runs in now. A switch changes it after a restart, so
  /// this value stays until then.
  final AutomationMode mode;

  AutomationMode? _nextMode;

  /// Creates a controller.
  ///
  /// The [store] parameter is the state store of the project.
  /// The [mode] parameter is the mode the app runs in now.
  /// The [onRestartRequired] parameter asks the project to restart the app.
  AutomationModeController({
    required this.store,
    required this.mode,
    required this.onRestartRequired,
  });

  /// The mode the next launch starts in.
  AutomationMode get nextMode => _nextMode ?? mode;

  /// Saves [mode] for the next launch and asks for a restart.
  ///
  /// The scenario and the walk in `state.json` stay.
  Future<void> switchTo(AutomationMode mode) async {
    await store.update((state) => state.copyWith(mode: mode));

    _nextMode = mode;

    notifyListeners();

    await onRestartRequired();
  }
}
