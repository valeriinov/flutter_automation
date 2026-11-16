import 'package:flutter/foundation.dart';

/// {@category Utils}
///
/// A text button of the status row, such as Presets or Reset.
@immutable
final class AutomationPanelStatusAction {
  /// Text of the button.
  final String label;

  /// Called when the tester taps the button.
  final VoidCallback onPressed;

  const AutomationPanelStatusAction({
    required this.label,
    required this.onPressed,
  });
}

/// {@category Utils}
///
/// What the status row of a panel tab says: the state of the mock, how many
/// changes it holds and the buttons beside it.
@immutable
final class AutomationPanelStatus {
  /// What the mock is set to, such as the name of the chosen outcome.
  final String text;

  /// How many changes the mock holds: the latency, profiles, request
  /// overrides and other settings.
  final int changeCount;

  /// Whether the mock differs from its defaults. The dot of the row is grey
  /// when it does not.
  final bool isChanged;

  /// Buttons at the end of the row.
  final List<AutomationPanelStatusAction> actions;

  /// Called when the tester taps the state of the row, missing when the state
  /// opens nothing.
  final VoidCallback? onPressed;

  const AutomationPanelStatus({
    required this.text,
    this.changeCount = 0,
    this.isChanged = true,
    this.actions = const [],
    this.onPressed,
  });
}
