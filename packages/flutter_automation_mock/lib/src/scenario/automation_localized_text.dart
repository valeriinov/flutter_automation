import 'package:collection/collection.dart';

/// {@category Utils}
///
/// Text people read, written once per language code.
///
/// A flow file, a mock section and its profiles carry their texts in this type.
final class AutomationLocalizedText {
  static const _fallbackLanguageCode = 'en';

  /// The texts by language code.
  final Map<String, String> texts;

  const AutomationLocalizedText(this.texts);

  /// The language codes that hold a version of the text.
  Iterable<String> get locales => texts.keys;

  /// The text for [languageCode].
  ///
  /// Falls back to the `en` text, then to the first text written, then to an
  /// empty string.
  String resolve(String languageCode) {
    return texts[languageCode] ??
        texts[_fallbackLanguageCode] ??
        texts.values.firstOrNull ??
        '';
  }

  /// The text as a flow file writes it.
  Map<String, String> toJson() {
    final entries = texts.entries.sortedBy((entry) => entry.key);

    return {for (final MapEntry(:key, :value) in entries) key: value};
  }
}
