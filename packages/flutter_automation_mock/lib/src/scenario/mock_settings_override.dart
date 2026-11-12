import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_automation_mock/src/scenario/mock_override.dart';
import 'package:flutter_automation_mock/src/scenario/mock_section.dart';

/// {@category Utils}
///
/// Typed override of one section: a function over the settings that the
/// earlier overrides of the scenario built.
///
/// The override replaces the section with the keys of the new settings that
/// differ from the defaults. A key the function sets back to its default
/// therefore leaves the section. A value the settings omit from their JSON
/// does not survive from an earlier override.
final class MockSettingsOverride<S> extends MockOverride {
  static const _equality = DeepCollectionEquality();

  final MockSection<S> _section;
  final S Function(S settings) _update;

  /// Creates the override of [section] that [update] describes.
  ///
  /// The [section] parameter is the section the override changes.
  /// The [update] parameter returns the new settings out of the current ones.
  MockSettingsOverride(MockSection<S> section, S Function(S settings) update)
    : _section = section,
      _update = update,
      super(section.name, null);

  @override
  Map<String, Object?> applyTo(Map<String, Object?> scenario) {
    final updated = _update(_section.read(scenario));
    final defaults = _encode(_section.defaults);

    return {
      ...scenario,
      key: {
        for (final MapEntry(:key, :value) in _encode(updated).entries)
          if (!_equality.equals(defaults[key], value)) key: value,
      },
    };
  }

  Map<String, Object?> _encode(S settings) =>
      jsonDecode(jsonEncode(settings)) as Map<String, Object?>;
}
