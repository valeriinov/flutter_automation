import 'package:flutter_automation_driver/src/automation_protocol.dart';
import 'package:flutter_driver/flutter_driver.dart';

/// {@category Utils}
///
/// Finds a `Text` or an `EditableText` by its [text], as `find.text` does.
///
/// The match ignores the locale key marks that a
/// `ENABLE_AUTOMATION_LOCALE_KEYS` launch appends to translations.
///
/// The app answers it through the driver finder registered under the same
/// [finderType].
final class UnmarkedText extends SerializableFinder {
  /// The text the widget shows, without marks.
  final String text;

  const UnmarkedText(this.text);

  @override
  String get finderType => AutomationProtocol.unmarkedTextFinderType;

  @override
  Map<String, String> serialize() =>
      super.serialize()..addAll({AutomationProtocol.textParameter: text});
}

/// {@category Utils}
///
/// Finds a `Tooltip` by its message [text].
///
/// The match ignores the locale key marks that a
/// `ENABLE_AUTOMATION_LOCALE_KEYS` launch appends to translations.
///
/// The app answers it through the driver finder registered under the same
/// [finderType].
final class UnmarkedTooltip extends SerializableFinder {
  /// The tooltip message, without marks.
  final String text;

  const UnmarkedTooltip(this.text);

  @override
  String get finderType => AutomationProtocol.unmarkedTooltipFinderType;

  @override
  Map<String, String> serialize() =>
      super.serialize()..addAll({AutomationProtocol.textParameter: text});
}

/// {@category Utils}
///
/// Finds a `Text` or an `EditableText` whose text carries the mark of the
/// locale key [key], so a flow finds a translation in every locale.
///
/// The mark is in the text of a build launched with
/// `ENABLE_AUTOMATION_LOCALE_KEYS`. The app answers it through the driver
/// finder registered under the same [finderType].
final class LocaleKeyText extends SerializableFinder {
  /// The locale key of the translation the widget shows.
  final String key;

  const LocaleKeyText(this.key);

  @override
  String get finderType => AutomationProtocol.localeKeyTextFinderType;

  @override
  Map<String, String> serialize() =>
      super.serialize()..addAll({AutomationProtocol.keyParameter: key});
}

/// {@category Utils}
///
/// Finds a `Tooltip` whose message carries the mark of the locale key [key].
///
/// The mark is in the text of a build launched with
/// `ENABLE_AUTOMATION_LOCALE_KEYS`. The app answers it through the driver
/// finder registered under the same [finderType].
final class LocaleKeyTooltip extends SerializableFinder {
  /// The locale key of the tooltip message.
  final String key;

  const LocaleKeyTooltip(this.key);

  @override
  String get finderType => AutomationProtocol.localeKeyTooltipFinderType;

  @override
  Map<String, String> serialize() =>
      super.serialize()..addAll({AutomationProtocol.keyParameter: key});
}
