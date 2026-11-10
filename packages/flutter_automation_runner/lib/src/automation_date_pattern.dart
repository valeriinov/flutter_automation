/// {@category Utils}
///
/// Writes a date by a pattern of the tokens `yyyy`, `MM` and `dd`.
///
/// Any other character of the pattern stays as it stands, so `dd.MM.yyyy`
/// writes `05.03.2026`.
abstract final class AutomationDatePattern {
  static final RegExp _token = RegExp('yyyy|MM|dd');
  static const _monthDayDigits = 2;

  /// Returns [date] written by [pattern].
  static String format(DateTime date, String pattern) {
    return pattern.replaceAllMapped(_token, (match) {
      return switch (match.group(0)) {
        'yyyy' => date.year.toString(),
        'MM' => _pad(date.month),
        _ => _pad(date.day),
      };
    });
  }

  static String _pad(int number) {
    return number.toString().padLeft(_monthDayDigits, '0');
  }
}
