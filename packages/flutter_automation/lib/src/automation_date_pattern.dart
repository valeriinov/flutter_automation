/// {@category Utils}
///
/// Writes a day by a pattern of the tokens `yyyy`, `MM` and `dd`.
///
/// Any other character of the pattern stays as it stands, so `dd.MM.yyyy`
/// writes `05.03.2026`. The runner and the in-app player both read a date
/// finder through this class, so a date finder names the same text or key on
/// the host and in the app. The library imports no Flutter code.
abstract final class AutomationDatePattern {
  static final RegExp _token = RegExp('yyyy|MM|dd');
  static final RegExp _templatePlaceholder = RegExp(r'\{([^}]+)\}');
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

  /// The day [dayOffset] days after [anchor].
  static DateTime resolveDay(DateTime anchor, int dayOffset) {
    return DateTime(anchor.year, anchor.month, anchor.day + dayOffset);
  }

  /// The text of the day [dayOffset] days after [anchor], written by
  /// [pattern]. The [time] follows it after a space when it is not null.
  static String writeDayText(
    DateTime anchor,
    int dayOffset,
    String pattern, {
    String? time,
  }) {
    final text = format(resolveDay(anchor, dayOffset), pattern);

    return time == null ? text : '$text $time';
  }

  /// The value key of the day [dayOffset] days after [anchor]. Each
  /// `{pattern}` placeholder of [template] holds a date pattern, such as
  /// `day.tile.{yyyyMMdd}`.
  static String writeDayKey(DateTime anchor, int dayOffset, String template) {
    final date = resolveDay(anchor, dayOffset);

    return template.replaceAllMapped(_templatePlaceholder, (match) {
      return format(date, match.group(1) ?? '');
    });
  }

  static String _pad(int number) {
    return number.toString().padLeft(_monthDayDigits, '0');
  }
}
