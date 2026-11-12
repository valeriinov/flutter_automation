import 'dart:io';

import 'package:yaml/yaml.dart';

import 'package:flutter_automation_runner/src/automation_finder_kind.dart';
import 'package:flutter_automation_runner/src/automation_frame_summary.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

/// {@category Utils}
///
/// What the runner takes from the project: the `flutter_automation:` section
/// of its `pubspec.yaml` and the package name.
///
/// ```yaml
/// flutter_automation:
///   defaultLocale: en
///   dateFormats:
///     en: MM/dd/yyyy
///   frameBudgetMs: 16
///   splashScreen: splash
///   launchHint: --dart-define=MOCK_MODE=full
///   finders:
///     calendarDay:
///       kind: dateValueKey
///       template: day.tile.{yyyyMMdd}
/// ```
final class AutomationRunnerConfig {
  static const _pubspecPath = 'pubspec.yaml';
  static const _sectionKey = 'flutter_automation';
  static const _dateValueKeyKind = 'dateValueKey';
  static const _defaultLocale = 'en';

  /// The `package:` prefix of the project's own libraries.
  final String packagePrefix;

  /// Locale a run takes when it names none.
  final String defaultLocale;

  /// Pattern a `dateText` finder writes a date in, by locale code.
  final Map<String, String> dateFormats;

  /// Frame time in milliseconds that the run holds a traced window to.
  final int frameBudgetMs;

  /// Value key templates by the name of the finder kind they define.
  final Map<String, String> dateValueKeys;

  /// Name of the screen the app shows while it starts, missing when the app has
  /// none.
  final String? splashScreen;

  /// How the app must launch for the commands that a run needs, as a clause
  /// that ends an error message. Missing when there is none to say.
  final String? launchHint;

  const AutomationRunnerConfig({
    required this.packagePrefix,
    this.defaultLocale = _defaultLocale,
    this.dateFormats = const {},
    this.frameBudgetMs = AutomationFrameSummary.defaultGoalMillis,
    this.splashScreen,
    this.launchHint,
    this.dateValueKeys = const {},
  });

  /// Reads the `pubspec.yaml` at [pubspecPath], the one of the directory where
  /// the runner starts when the caller names none.
  factory AutomationRunnerConfig.read([String pubspecPath = _pubspecPath]) {
    final file = File(pubspecPath);

    if (!file.existsSync()) {
      throw AutomationRunnerException(
        'No $pubspecPath here. Start the runner in the project root.',
      );
    }

    return AutomationRunnerConfig.fromPubspec(file.readAsStringSync());
  }

  /// Reads the decoded text of a `pubspec.yaml`.
  factory AutomationRunnerConfig.fromPubspec(String pubspec) {
    final root = loadYaml(pubspec);

    if (root is! YamlMap || root['name'] is! String) {
      throw const AutomationRunnerException(
        'The $_pubspecPath names no package.',
      );
    }

    final section = _readSection(root);

    return AutomationRunnerConfig(
      packagePrefix: 'package:${root['name']}/',
      defaultLocale: _readString(section, 'defaultLocale') ?? _defaultLocale,
      dateFormats: _readStrings(section, 'dateFormats'),
      frameBudgetMs:
          _readInt(section, 'frameBudgetMs') ??
          AutomationFrameSummary.defaultGoalMillis,
      splashScreen: _readString(section, 'splashScreen'),
      launchHint: _readString(section, 'launchHint'),
      dateValueKeys: _readDateValueKeys(section),
    );
  }

  /// The finder kinds of the built-in set and the ones this project declares.
  AutomationFinderRegistry get finderRegistry {
    return AutomationFinderRegistry(
      dateFormats: dateFormats,
      dateValueKeys: dateValueKeys,
    );
  }

  static Object? _readSection(YamlMap root) {
    final section = root[_sectionKey];

    if (section == null || section is YamlMap) {
      return section;
    }

    throw AutomationRunnerException(
      'The $_sectionKey section takes a map, not $section.',
    );
  }

  static Object? _read(Object? section, String key) {
    return section is YamlMap ? section[key] : null;
  }

  static String? _readString(Object? section, String key) {
    return _readTyped<String>(section, key, 'a string');
  }

  static int? _readInt(Object? section, String key) {
    return _readTyped<int>(section, key, 'an integer');
  }

  static T? _readTyped<T>(Object? section, String key, String expected) {
    final value = _read(section, key);

    if (value == null || value is T) {
      return value as T?;
    }

    throw AutomationRunnerException(
      'The "$key" of the $_sectionKey section takes $expected, not $value.',
    );
  }

  static Map<String, String> _readStrings(Object? section, String key) {
    final map = _read(section, key);

    if (map == null) {
      return const {};
    }

    if (map is YamlMap && map.values.every((value) => value is String)) {
      return {
        for (final MapEntry(:key, :value) in map.entries) '$key': '$value',
      };
    }

    throw AutomationRunnerException(
      'The "$key" of the $_sectionKey section takes '
      '{<locale code>: <string>}, not $map.',
    );
  }

  static Map<String, String> _readDateValueKeys(Object? section) {
    final finders = _read(section, 'finders');

    if (finders == null) {
      return const {};
    }

    if (finders is! YamlMap) {
      throw AutomationRunnerException(
        'The "finders" of the $_sectionKey section takes '
        '{<finder name>: {kind, template}}, not $finders.',
      );
    }

    return {
      for (final MapEntry(:key, :value) in finders.entries)
        '$key': _readTemplate('$key', value),
    };
  }

  static String _readTemplate(String name, Object? finder) {
    if (finder case {
      'kind': _dateValueKeyKind,
      'template': final String template,
    }) {
      return template;
    }

    throw AutomationRunnerException(
      'The finder "$name" of the $_sectionKey section takes '
      '{kind: $_dateValueKeyKind, template: <value key template>}.',
    );
  }
}
