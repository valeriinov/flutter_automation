import 'package:flutter_automation/src/automation_target_type.dart';

/// {@category Utils}
///
/// Element an agent can address while it drives the app on a simulator.
///
/// One enum per flow implements it. The code writes a target once and reaches
/// it by its member instead of a string. The agent reads the target enums to
/// learn what it can address. This replaces a widget tree dump.
///
/// The `automationTarget()` call attaches a target to a widget. The target
/// reaches the agent through two channels at once: the Flutter Driver
/// `ByValueKey` finder and the accessibility identifier that the native
/// automation layer reads.
abstract interface class AutomationTarget {
  /// Kind of control this target addresses.
  AutomationTargetType get type;

  /// Flow the target belongs to, and the first segment of [id].
  String get scope;

  /// Identifier the agent addresses the element by.
  ///
  /// Composed as `<scope>.<type>.<name>`, unique across the app as long as the
  /// scope names one flow.
  String get id;
}

/// {@category Utils}
///
/// Composes [AutomationTarget.id] out of the parts a target enum declares.
///
/// Every target enum mixes it in, so the id keeps one shape across the app. An
/// agent matches an element by the `<scope>.<type>.` prefix. This holds only
/// while no flow spells its id by hand. The trailing segment is the enum member
/// name, so a target costs one line and cannot collide within a scope.
mixin AutomationIdComposer on Enum implements AutomationTarget {
  @override
  String get id => '$scope.${type.name}.$name';
}
