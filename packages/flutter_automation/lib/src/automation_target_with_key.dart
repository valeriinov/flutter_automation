import 'package:flutter_automation/src/automation_target.dart';
import 'package:flutter_automation/src/automation_target_type.dart';

/// {@category Extensions}
///
/// Extension on [AutomationTarget] that addresses one of the elements a screen
/// shows more than once, such as the delete button of every card of a list.
extension AutomationTargetWithKey on AutomationTarget {
  /// The same target with [key] as its last id segment:
  /// `<scope>.<type>.<name>.<key>`.
  ///
  /// The [key] parameter is the key of the record the element shows, a string
  /// or an int: the id of a notification, the id of a message, the code of a
  /// country. It is not a Flutter widget `Key`. The method returns a target,
  /// which `automationTarget()` turns into the widget key.
  ///
  /// A record key stays with its element when the list sorts or drops a row,
  /// so a flow addresses the same element on every run. The key goes after the
  /// name, so a dot or a space in it keeps the `<scope>.<type>.` prefix of the
  /// id.
  ///
  /// Example:
  /// ```dart
  /// IconButton(icon: deleteIcon, onPressed: onDeletePressed)
  ///     .automationTarget(InboxTarget.deleteButton.withKey(notification.id))
  /// ```
  AutomationTarget withKey(Object key) => _AutomationTargetKeyed(this, key);
}

final class _AutomationTargetKeyed implements AutomationTarget {
  final AutomationTarget _target;
  final Object _key;

  const _AutomationTargetKeyed(this._target, this._key);

  @override
  AutomationTargetType get type => _target.type;

  @override
  String get scope => _target.scope;

  @override
  String get id => '${_target.id}.$_key';
}
