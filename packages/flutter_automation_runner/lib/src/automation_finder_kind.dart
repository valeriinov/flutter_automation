import 'package:flutter_automation_runner/src/automation_date_pattern.dart';
import 'package:flutter_automation_runner/src/automation_finder_spec.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

/// {@category Utils}
///
/// One `by` value of a flow finder: its [name] and how it reads the finder
/// object into an [AutomationFinderSpec].
final class AutomationFinderKind {
  /// Value of `by` the kind answers to.
  final String name;

  final AutomationFinderSpec Function(
    Map<String, Object?> json,
    AutomationFinderContext context,
  )
  _parse;

  const AutomationFinderKind(this.name, this._parse);

  /// Reads the finder object [json] into what it looks for.
  AutomationFinderSpec parse(
    Map<String, Object?> json,
    AutomationFinderContext context,
  ) {
    return _parse(json, context);
  }

  /// The `value` of finder [json] in the locale of [context]: the value
  /// itself, or the entry of the locale when the value is a per-locale object
  /// such as `{"uk": "12,5", "en": "12.5"}`.
  static Object? readValue(
    Map<String, Object?> json,
    AutomationFinderContext context,
  ) {
    final value = json['value'];

    if (value is! Map<String, Object?>) {
      return value;
    }

    final localized = value[context.locale];

    if (localized is String) {
      return localized;
    }

    throw AutomationRunnerException(
      '${context.subject} has no "${context.locale}" finder value. It holds '
      '${value.keys.toList()}.',
    );
  }

  /// Reads the `value` of finder [json] as a string.
  static String readString(
    Map<String, Object?> json,
    AutomationFinderContext context,
  ) {
    final value = readValue(json, context);

    if (value is String) {
      return value;
    }

    throw const AutomationRunnerException('Step has no string "value".');
  }

  /// Reads the int `dayOffset` of the date finder [json].
  static int readDayOffset(Map<String, Object?> json, String kindName) {
    final dayOffset = json['dayOffset'];

    if (dayOffset is int) {
      return dayOffset;
    }

    throw AutomationRunnerException(
      'A $kindName finder takes an int "dayOffset".',
    );
  }

  /// The day `dayOffset` days after [anchor].
  static DateTime resolveDate(DateTime anchor, int dayOffset) {
    return DateTime(anchor.year, anchor.month, anchor.day + dayOffset);
  }
}

/// {@category Utils}
///
/// What a [AutomationFinderKind] reads one finder object in.
final class AutomationFinderContext {
  /// Locale in which the runner reads a per-locale value.
  final String locale;

  /// Names the step in the error a malformed finder fails with.
  final String subject;

  /// Moment each kind counts days from, supplied by the caller.
  final AutomationAnchorReader anchorOf;

  const AutomationFinderContext({
    required this.locale,
    required this.subject,
    required this.anchorOf,
  });
}

/// {@category Utils}
///
/// The `by` values a flow finder takes: the built-in ones and the date kinds a
/// project declares.
///
/// The built-in kinds are `valueKey`, `text`, `tooltip`, `localeKey`,
/// `localeKeyTooltip`, `type`, `pageBack`, `dateText`, and the nested
/// `descendant` and `ancestor`. A declared kind writes a value key from a
/// template, such as `item.day{yyyyMMdd}`, whose placeholders take the date of
/// the finder's `dayOffset`.
final class AutomationFinderRegistry {
  /// Name of the `dateText` kind. Its day count starts at the moment that
  /// `anchorOf` returns for this name.
  static const dateTextName = 'dateText';

  static const _descendantName = 'descendant';
  static const _ancestorName = 'ancestor';
  static const _templatePlaceholder = r'\{([^}]+)\}';

  final Map<String, AutomationFinderKind> _kinds;

  /// Builds the registry of the built-in kinds and the date kinds.
  ///
  /// The [dateFormats] parameter maps a locale code to the pattern that
  /// `dateText` writes a date in. The [dateValueKeys] parameter maps the name
  /// of a declared kind to its value key template.
  AutomationFinderRegistry({
    Map<String, String> dateFormats = const {},
    Map<String, String> dateValueKeys = const {},
  }) : _kinds = _buildKinds(dateFormats, dateValueKeys);

  /// The moment a finder counts days from when the caller names none.
  static DateTime readCurrentMoment(String _) => DateTime.now();

  /// Reads the finder object [json] into what it looks for.
  ///
  /// The [anchorOf] parameter gives the moment a date kind counts days from.
  AutomationFinderSpec resolve(
    Object? json, {
    required String locale,
    required String subject,
    AutomationAnchorReader anchorOf = readCurrentMoment,
  }) {
    if (json is! Map<String, Object?>) {
      throw const AutomationRunnerException('Finder is not a JSON object.');
    }

    final context = AutomationFinderContext(
      locale: locale,
      subject: subject,
      anchorOf: anchorOf,
    );
    final by = json['by'];

    if (by == _descendantName || by == _ancestorName) {
      return _resolveRelative(json, context, isAncestor: by == _ancestorName);
    }

    final kind = _kinds[by];

    if (kind == null) {
      throw AutomationRunnerException('Unknown finder "$by".');
    }

    return kind.parse(json, context);
  }

  AutomationFinderSpec _resolveRelative(
    Map<String, Object?> json,
    AutomationFinderContext context, {
    required bool isAncestor,
  }) {
    AutomationFinderSpec resolveOf(Object? nested) {
      return resolve(
        nested,
        locale: context.locale,
        subject: context.subject,
        anchorOf: context.anchorOf,
      );
    }

    return AutomationRelativeSpec(
      isAncestor: isAncestor,
      of: resolveOf(json['of']),
      matching: resolveOf(json['matching']),
      matchRoot: json['matchRoot'] == true,
    );
  }

  static Map<String, AutomationFinderKind> _buildKinds(
    Map<String, String> dateFormats,
    Map<String, String> dateValueKeys,
  ) {
    final builtInKinds = _buildBuiltInKinds(dateFormats);
    final reservedNames = {
      _descendantName,
      _ancestorName,
      for (final kind in builtInKinds) kind.name,
    };

    for (final name in dateValueKeys.keys) {
      if (reservedNames.contains(name)) {
        throw AutomationRunnerException(
          'The declared finder "$name" has the name of a built-in finder. '
          'Pick another name.',
        );
      }
    }

    return {
      for (final kind in [
        ...builtInKinds,
        for (final entry in dateValueKeys.entries)
          _buildDateValueKeyKind(entry.key, entry.value),
      ])
        kind.name: kind,
    };
  }

  static List<AutomationFinderKind> _buildBuiltInKinds(
    Map<String, String> dateFormats,
  ) {
    return [
      AutomationFinderKind('valueKey', (json, context) {
        return _readValueKey(AutomationFinderKind.readValue(json, context));
      }),
      AutomationFinderKind('text', (json, context) {
        return AutomationTextSpec(
          AutomationFinderKind.readString(json, context),
        );
      }),
      AutomationFinderKind('tooltip', (json, context) {
        return AutomationTooltipSpec(
          AutomationFinderKind.readString(json, context),
        );
      }),
      AutomationFinderKind('localeKey', (json, context) {
        return AutomationLocaleKeySpec(
          AutomationFinderKind.readString(json, context),
        );
      }),
      AutomationFinderKind('localeKeyTooltip', (json, context) {
        return AutomationLocaleKeyTooltipSpec(
          AutomationFinderKind.readString(json, context),
        );
      }),
      AutomationFinderKind('type', (json, context) {
        return AutomationTypeSpec(
          AutomationFinderKind.readString(json, context),
        );
      }),
      AutomationFinderKind('pageBack', (_, _) {
        return const AutomationPageBackSpec();
      }),
      AutomationFinderKind(dateTextName, (json, context) {
        return AutomationTextSpec(_readDateText(json, context, dateFormats));
      }),
    ];
  }

  static AutomationFinderKind _buildDateValueKeyKind(
    String name,
    String template,
  ) {
    return AutomationFinderKind(name, (json, context) {
      final date = AutomationFinderKind.resolveDate(
        context.anchorOf(name),
        AutomationFinderKind.readDayOffset(json, name),
      );

      return AutomationValueKeySpec(
        template.replaceAllMapped(RegExp(_templatePlaceholder), (match) {
          return AutomationDatePattern.format(date, match.group(1) ?? '');
        }),
      );
    });
  }

  static AutomationFinderSpec _readValueKey(Object? value) {
    return switch (value) {
      final String key => AutomationValueKeySpec(key),
      final int key => AutomationValueKeySpec(key),
      _ => throw const AutomationRunnerException(
        'A valueKey finder takes a string or an int "value".',
      ),
    };
  }

  /// The text of a `dateText` finder [json]: the day `dayOffset` days after the
  /// anchor, written by the pattern of the locale. The `time` of the finder
  /// follows it when the finder names one.
  static String _readDateText(
    Map<String, Object?> json,
    AutomationFinderContext context,
    Map<String, String> dateFormats,
  ) {
    final dayOffset = AutomationFinderKind.readDayOffset(json, dateTextName);
    final time = json['time'];

    if (time is! String?) {
      throw const AutomationRunnerException(
        'A dateText finder takes a string "time".',
      );
    }

    final pattern = dateFormats[context.locale];

    if (pattern == null) {
      throw AutomationRunnerException(
        'A dateText finder needs a "dateFormats" entry for the locale '
        '"${context.locale}". It holds ${dateFormats.keys.toList()}.',
      );
    }

    final date = AutomationFinderKind.resolveDate(
      context.anchorOf(dateTextName),
      dayOffset,
    );
    final dateText = AutomationDatePattern.format(date, pattern);

    return time == null ? dateText : '$dateText $time';
  }
}

/// {@category Utils}
///
/// Returns the moment a finder of the kind named by its argument counts days
/// from.
typedef AutomationAnchorReader = DateTime Function(String kindName);
