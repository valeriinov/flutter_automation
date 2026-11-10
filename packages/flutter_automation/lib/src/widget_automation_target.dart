import 'package:flutter/widgets.dart';
import 'package:flutter_automation/src/automation_settings.dart';
import 'package:flutter_automation/src/automation_target.dart';

/// {@category Extensions}
///
/// Extension on [Widget] that makes an element addressable by an agent that
/// drives the app on a simulator.
///
/// Keeps the automation layer out of the widgets themselves. A call site marks
/// an element with one trailing call. It does not add a parameter, wrap the
/// subtree or reach for `Semantics` by hand.
extension WidgetAutomationTarget on Widget {
  /// Attaches [target] to this widget for the duration of an automation run.
  ///
  /// The id reaches the agent through two channels: the Flutter Driver
  /// `ByValueKey` finder and the `accessibilityIdentifier` of the native
  /// accessibility tree. Outside an automation run, and when [target] is null,
  /// the method returns the widget untouched, so the tree of a regular build
  /// stays as it was.
  ///
  /// Example:
  /// ```dart
  /// Checkbox(value: isAccepted, onChanged: onChanged)
  ///     .automationTarget(FormAutomationTarget.agreement)
  /// ```
  Widget automationTarget(AutomationTarget? target) {
    if (!AutomationSettings.isEnabled || target == null) {
      return this;
    }

    final id = target.id;

    return Semantics(
      identifier: id,
      child: KeyedSubtree(
        key: ValueKey(id),
        // The driver taps the centre of what the key resolves to and refuses a
        // widget the hit test does not return, which a plain wrapper is not.
        // A translucent listener puts the marked box into the hit test result
        // while still passing the pointer down to the child that handles it.
        child: Listener(behavior: HitTestBehavior.translucent, child: this),
      ),
    );
  }
}
