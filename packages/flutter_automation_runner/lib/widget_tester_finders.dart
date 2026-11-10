import 'package:flutter/cupertino.dart' show CupertinoNavigationBarBackButton;
import 'package:flutter/material.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_finder_spec.dart';

export 'src/automation_date_pattern.dart';
export 'src/automation_finder_kind.dart';
export 'src/automation_finder_spec.dart';

/// {@category Utils}
///
/// Builds the `Finder` that a widget test uses from what a flow finder looks
/// for, the way the app answers the same finder on a device.
abstract final class AutomationWidgetTesterFinders {
  static const _backTooltip = 'Back';

  /// Returns the widget test finder of [spec].
  static Finder build(AutomationFinderSpec spec) {
    return switch (spec) {
      AutomationValueKeySpec(:final key) => find.byKey(_toKey(key)),
      AutomationTextSpec(:final text) => _findUnmarkedText(text, _readText),
      AutomationTooltipSpec(:final text) => _findUnmarkedText(
        text,
        _readTooltipMessage,
      ),
      AutomationLocaleKeySpec(:final key) => _findLocaleKey(key, _readText),
      AutomationLocaleKeyTooltipSpec(:final key) => _findLocaleKey(
        key,
        _readTooltipMessage,
      ),
      AutomationTypeSpec(:final typeName) => find.byElementPredicate(
        (element) => element.widget.runtimeType.toString() == typeName,
      ),
      AutomationPageBackSpec() => _findPageBack(),
      AutomationRelativeSpec() => _findRelative(spec),
    };
  }

  static Key _toKey(Object key) {
    return switch (key) {
      final String id => ValueKey(id),
      final int id => ValueKey(id),
      _ => throw StateError('A valueKey finder takes a string or an int.'),
    };
  }

  static Finder _findPageBack() {
    return find.byElementPredicate((element) {
      final widget = element.widget;

      return widget is CupertinoNavigationBarBackButton ||
          (widget is Tooltip && widget.message == _backTooltip);
    }, description: 'page back button');
  }

  static Finder _findRelative(AutomationRelativeSpec spec) {
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

  static Finder _findUnmarkedText(
    String text,
    String? Function(Widget) readText,
  ) {
    return find.byElementPredicate((element) {
      final shown = readText(element.widget);

      return shown != null && LocaleKeyMarker.strip(shown) == text;
    }, description: 'unmarked text "$text"');
  }

  static Finder _findLocaleKey(String key, String? Function(Widget) readText) {
    return find.byElementPredicate((element) {
      final shown = readText(element.widget);

      return shown != null && LocaleKeyMarker.readKeys(shown).contains(key);
    }, description: 'locale key "$key"');
  }

  static String? _readText(Widget widget) {
    return switch (widget) {
      Text(:final data?) => data,
      Text(:final textSpan?) => textSpan.toPlainText(),
      EditableText(:final controller) => controller.text,
      _ => null,
    };
  }

  static String? _readTooltipMessage(Widget widget) {
    return switch (widget) {
      Tooltip(:final message?) => message,
      _ => null,
    };
  }
}
