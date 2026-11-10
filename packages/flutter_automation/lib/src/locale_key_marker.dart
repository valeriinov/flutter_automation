/// {@category Utils}
///
/// Invisible mark of the locale key a translation string came from.
///
/// The mark is the key spelled in Unicode Tag characters (U+E0020–U+E007E, one
/// per ASCII character) and closed by U+E007F. Tag characters are
/// default-ignorable: the text engine draws nothing for them. A marked string
/// renders as its value, while the rendered text still names its key. The mark
/// follows the value and holds no `{`, `}` or `@:`. Argument, named-argument
/// and plural substitution therefore keep it intact.
abstract final class LocaleKeyMarker {
  static const _tagOffset = 0xE0000;
  static const _terminator = 0xE007F;

  static final _marks = RegExp(
    r'[\u{E0020}-\u{E007E}]+\u{E007F}',
    unicode: true,
  );

  /// Appends the mark of [key] to [value].
  ///
  /// The [key] parameter is an ASCII locale key.
  static String mark(String key, String value) {
    final tags = key.runes.map((rune) => _tagOffset + rune);

    return value + String.fromCharCodes([...tags, _terminator]);
  }

  /// The keys of every mark in [text], in the order they appear.
  static List<String> readKeys(String text) {
    return _marks.allMatches(text).map(_decode).toList();
  }

  /// [text] without its marks.
  static String strip(String text) => text.replaceAll(_marks, '');

  static String _decode(Match match) {
    final tags = match.input.substring(match.start, match.end).runes;
    final characters = tags
        .where((rune) => rune != _terminator)
        .map((rune) => rune - _tagOffset);

    return String.fromCharCodes(characters);
  }
}
