import 'package:flutter_automation/automation_target.dart';

import 'package:flutter_automation_runner/src/definition/flow_json_value.dart';

/// {@category Utils}
///
/// What a flow step looks for, written the way the flow JSON writes the
/// `finder` object.
///
/// Each subclass answers to one `by` value of the JSON form.
sealed class FlowFinder {
  const FlowFinder();

  /// The finder as the flow JSON holds it.
  Map<String, Object?> toJson();
}

/// {@category Utils}
///
/// The widget that carries the value key of an [AutomationTarget]: `by`
/// `valueKey` with the target id.
final class ByTarget extends FlowFinder {
  /// Target whose id is the value key.
  final AutomationTarget target;

  const ByTarget(this.target);

  @override
  Map<String, Object?> toJson() => {'by': 'valueKey', 'value': target.id};
}

/// {@category Utils}
///
/// A finder whose JSON holds a `by` name and one `value`.
///
/// The value is a string, an int (a value key only), a [FlowParam] or a map of
/// locale code to string for a value that differs by locale.
sealed class FlowValueFinder extends FlowFinder {
  /// What the finder reads: a string, an int, a `FlowParam` or a
  /// per-locale map.
  final Object value;

  const FlowValueFinder(this.value);

  /// The `by` value of the JSON form.
  String get by;

  @override
  Map<String, Object?> toJson() => {
    'by': by,
    'value': writeFlowJsonValue(value),
  };
}

/// {@category Utils}
///
/// A widget with the value key [value], a string or an int: `by` `valueKey`.
final class ByValueKey extends FlowValueFinder {
  const ByValueKey(super.value);

  @override
  String get by => 'valueKey';
}

/// {@category Utils}
///
/// A text with the value [value]: `by` `text`.
final class ByText extends FlowValueFinder {
  const ByText(super.value);

  @override
  String get by => 'text';
}

/// {@category Utils}
///
/// A tooltip with the message [value]: `by` `tooltip`.
final class ByTooltip extends FlowValueFinder {
  const ByTooltip(super.value);

  @override
  String get by => 'tooltip';
}

/// {@category Utils}
///
/// A text that carries the mark of the locale key [value]: `by` `localeKey`.
final class ByLocaleKey extends FlowValueFinder {
  const ByLocaleKey(super.value);

  @override
  String get by => 'localeKey';
}

/// {@category Utils}
///
/// A tooltip that carries the mark of the locale key [value]: `by`
/// `localeKeyTooltip`.
final class ByLocaleKeyTooltip extends FlowValueFinder {
  const ByLocaleKeyTooltip(super.value);

  @override
  String get by => 'localeKeyTooltip';
}

/// {@category Utils}
///
/// A widget of the runtime type named [value]: `by` `type`.
final class ByType extends FlowValueFinder {
  const ByType(super.value);

  @override
  String get by => 'type';
}

/// {@category Utils}
///
/// The back button of a page: `by` `pageBack`.
final class ByPageBack extends FlowFinder {
  const ByPageBack();

  @override
  Map<String, Object?> toJson() => const {'by': 'pageBack'};
}

/// {@category Utils}
///
/// The text of a day: `by` `dateText`. The project's `dateFormats` write the
/// date by the locale of the run.
final class ByDateText extends FlowFinder {
  /// Days after the anchor day.
  final int dayOffset;

  /// Time of day that follows the date text, missing when the text holds none.
  final String? time;

  const ByDateText({required this.dayOffset, this.time});

  @override
  Map<String, Object?> toJson() => {
    'by': 'dateText',
    'dayOffset': dayOffset,
    'time': ?time,
  };
}

/// {@category Utils}
///
/// A finder of a date kind that the project declares under `finders` in its
/// `flutter_automation:` section: `by` is the declared [kind].
final class ByDeclaredDate extends FlowFinder {
  /// Name of the declared kind.
  final String kind;

  /// Days after the anchor day.
  final int dayOffset;

  const ByDeclaredDate(this.kind, {required this.dayOffset});

  @override
  Map<String, Object?> toJson() => {'by': kind, 'dayOffset': dayOffset};
}

/// {@category Utils}
///
/// A finder that relates [matching] to what [of] finds.
sealed class FlowRelativeFinder extends FlowFinder {
  /// Finder of the widget the relation starts from.
  final FlowFinder of;

  /// Finder of the widgets that count.
  final FlowFinder matching;

  /// Whether [of] itself may match.
  final bool matchRoot;

  const FlowRelativeFinder({
    required this.of,
    required this.matching,
    this.matchRoot = false,
  });

  /// The `by` value of the JSON form.
  String get by;

  @override
  Map<String, Object?> toJson() => {
    'by': by,
    'of': of.toJson(),
    'matching': matching.toJson(),
    if (matchRoot) 'matchRoot': true,
  };
}

/// {@category Utils}
///
/// A widget that [matching] finds among the descendants of what [of] finds:
/// `by` `descendant`.
final class ByDescendant extends FlowRelativeFinder {
  const ByDescendant({
    required super.of,
    required super.matching,
    super.matchRoot,
  });

  @override
  String get by => 'descendant';
}

/// {@category Utils}
///
/// A widget that [matching] finds among the ancestors of what [of] finds: `by`
/// `ancestor`.
final class ByAncestor extends FlowRelativeFinder {
  const ByAncestor({
    required super.of,
    required super.matching,
    super.matchRoot,
  });

  @override
  String get by => 'ancestor';
}
