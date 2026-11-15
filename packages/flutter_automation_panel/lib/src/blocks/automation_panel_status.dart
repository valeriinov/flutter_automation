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
/// overrides it holds and the buttons beside it.
@immutable
final class AutomationPanelStatus {
  /// What the mock is set to, such as the name of the chosen outcome.
  final String text;

  /// How many requests answer with an override.
  final int overrideCount;

  /// Whether the mock differs from its defaults. The dot of the row is grey
  /// when it does not.
  final bool isChanged;

  /// Buttons at the end of the row.
  final List<AutomationPanelStatusAction> actions;

  const AutomationPanelStatus({
    required this.text,
    this.overrideCount = 0,
    this.isChanged = true,
    this.actions = const [],
  });
}
