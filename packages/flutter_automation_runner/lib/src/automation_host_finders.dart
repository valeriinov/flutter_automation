import 'package:flutter_automation_driver/flutter_automation_driver.dart';
import 'package:flutter_driver/flutter_driver.dart';

import 'package:flutter_automation_runner/src/automation_finder_spec.dart';

/// {@category Utils}
///
/// Builds the `SerializableFinder` the driver sends to the app from what a
/// flow finder looks for.
abstract final class AutomationHostFinders {
  /// Returns the driver finder of [spec].
  static SerializableFinder build(AutomationFinderSpec spec) {
    return switch (spec) {
      AutomationValueKeySpec(:final key) => find.byValueKey(key),
      AutomationTextSpec(:final text) => UnmarkedText(text),
      AutomationTooltipSpec(:final text) => UnmarkedTooltip(text),
      AutomationLocaleKeySpec(:final key) => LocaleKeyText(key),
      AutomationLocaleKeyTooltipSpec(:final key) => LocaleKeyTooltip(key),
      AutomationTypeSpec(:final typeName) => find.byType(typeName),
      AutomationPageBackSpec() => find.pageBack(),
      AutomationRelativeSpec() => _buildRelative(spec),
    };
  }

  static SerializableFinder _buildRelative(AutomationRelativeSpec spec) {
    final of = build(spec.of);
    final matching = build(spec.matching);

    if (spec.isAncestor) {
      return find.ancestor(
        of: of,
        matching: matching,
        matchRoot: spec.matchRoot,
      );
    }

    return find.descendant(
      of: of,
      matching: matching,
      matchRoot: spec.matchRoot,
    );
  }
}
