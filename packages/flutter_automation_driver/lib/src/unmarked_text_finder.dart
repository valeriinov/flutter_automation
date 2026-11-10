import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_driver/flutter_driver.dart' show SerializableFinder;
import 'package:flutter_test/flutter_test.dart' show Finder, find;
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_driver/src/automation_protocol.dart';

/// {@category Utils}
///
/// Flutter Driver finder that matches a widget's text after
/// [LocaleKeyMarker.strip], so a flow finds a marked string by its value.
///
/// The text variant matches what `find.text` matches, a [Text] or an
/// [EditableText] that is onstage; the tooltip variant matches a [Tooltip]
/// message. A host addresses them by [finderType] with a `text` parameter.
final class UnmarkedTextFinder extends FinderExtension {
  static const _textParameter = AutomationProtocol.textParameter;

  @override
  final String finderType;

  final String? Function(Widget widget) _readText;

  /// Matches a [Text] or an [EditableText] and answers the `UnmarkedText`
  /// finder type.
  UnmarkedTextFinder.text()
    : finderType = AutomationProtocol.unmarkedTextFinderType,
      _readText = _tryReadWidgetText;

  /// Matches a [Tooltip] message and answers the `UnmarkedTooltip` finder type.
  UnmarkedTextFinder.tooltip()
    : finderType = AutomationProtocol.unmarkedTooltipFinderType,
      _readText = _tryReadTooltipMessage;

  @override
  SerializableFinder deserialize(
    Map<String, String> params,
    DeserializeFinderFactory finderFactory,
  ) {
    final text = params[_textParameter];

    if (text == null) {
      throw ArgumentError.notNull(_textParameter);
    }

    return _UnmarkedTextQuery(finderType: finderType, text: text);
  }

  @override
  Finder createFinder(
    SerializableFinder finder,
    CreateFinderFactory finderFactory,
  ) {
    final text = (finder as _UnmarkedTextQuery).text;

    return find.byElementPredicate(
      (element) => _matches(element.widget, text),
      description: '$finderType "$text"',
    );
  }

  bool _matches(Widget widget, String text) {
    final widgetText = _readText(widget);

    if (widgetText == null) {
      return false;
    }

    return LocaleKeyMarker.strip(widgetText) == text;
  }
}

/// {@category Utils}
///
/// Flutter Driver finder that matches a widget whose text carries the mark of a
/// locale key ([LocaleKeyMarker.readKeys]). With it, a flow finds a translation
/// by its key in each locale.
///
/// The mark is in the text of a build launched with `MARK_LOCALE_KEYS`. The
/// text variant matches an onstage [Text] or [EditableText]; the tooltip
/// variant matches a [Tooltip] message. A host addresses them by [finderType]
/// with a `key` parameter.
final class LocaleKeyFinder extends FinderExtension {
  static const _keyParameter = AutomationProtocol.keyParameter;

  @override
  final String finderType;

  final String? Function(Widget widget) _readText;

  /// Matches a [Text] or an [EditableText] and answers the `LocaleKeyText`
  /// finder type.
  LocaleKeyFinder.text()
    : finderType = AutomationProtocol.localeKeyTextFinderType,
      _readText = _tryReadWidgetText;

  /// Matches a [Tooltip] message and answers the `LocaleKeyTooltip` finder
  /// type.
  LocaleKeyFinder.tooltip()
    : finderType = AutomationProtocol.localeKeyTooltipFinderType,
      _readText = _tryReadTooltipMessage;

  @override
  SerializableFinder deserialize(
    Map<String, String> params,
    DeserializeFinderFactory finderFactory,
  ) {
    final key = params[_keyParameter];

    if (key == null) {
      throw ArgumentError.notNull(_keyParameter);
    }

    return _LocaleKeyQuery(finderType: finderType, key: key);
  }

  @override
  Finder createFinder(
    SerializableFinder finder,
    CreateFinderFactory finderFactory,
  ) {
    final key = (finder as _LocaleKeyQuery).key;

    return find.byElementPredicate(
      (element) => _matches(element.widget, key),
      description: '$finderType "$key"',
    );
  }

  bool _matches(Widget widget, String key) {
    final widgetText = _readText(widget);

    if (widgetText == null) {
      return false;
    }

    return LocaleKeyMarker.readKeys(widgetText).contains(key);
  }
}

class _UnmarkedTextQuery extends SerializableFinder {
  @override
  final String finderType;

  final String text;

  const _UnmarkedTextQuery({required this.finderType, required this.text});
}

class _LocaleKeyQuery extends SerializableFinder {
  @override
  final String finderType;

  final String key;

  const _LocaleKeyQuery({required this.finderType, required this.key});
}

String? _tryReadWidgetText(Widget widget) {
  return switch (widget) {
    Text(:final data?) => data,
    Text(:final textSpan?) => textSpan.toPlainText(),
    EditableText(:final controller) => controller.text,
    _ => null,
  };
}

String? _tryReadTooltipMessage(Widget widget) {
  return switch (widget) {
    Tooltip(:final message?) => message,
    _ => null,
  };
}
