import 'package:flutter_automation_mock/mock_section.dart';

/// Reads the text of a catalogue entry in the language of the panel.
abstract final class AutomationCatalogueText {
  /// The text of [text] in [languageCode], [fallback] when it has none.
  ///
  /// A language the text lacks falls back by the rule of
  /// [AutomationLocalizedText.resolve].
  static String read(
    Map<String, String>? text,
    String fallback,
    String languageCode,
  ) {
    if (text == null || text.isEmpty) {
      return fallback;
    }

    return AutomationLocalizedText(text).resolve(languageCode);
  }
}
