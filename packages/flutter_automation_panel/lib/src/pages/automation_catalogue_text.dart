/// Reads the English text of a catalogue entry. The panel shows English only.
abstract final class AutomationCatalogueText {
  static const _locale = 'en';

  /// The English text of [text], [fallback] when it has none.
  static String english(Map<String, String>? text, String fallback) {
    return text?[_locale] ?? fallback;
  }
}
