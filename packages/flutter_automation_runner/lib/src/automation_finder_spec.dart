/// {@category Utils}
///
/// What a flow finder looks for, free of any driver or test type.
///
/// The host builds a `SerializableFinder` from it and a widget test builds a
/// `Finder`, so both read one description of the same `by` value.
sealed class AutomationFinderSpec {
  const AutomationFinderSpec();
}

/// {@category Utils}
///
/// A widget with the `ValueKey` [key], a string or an integer.
final class AutomationValueKeySpec extends AutomationFinderSpec {
  final Object key;

  const AutomationValueKeySpec(this.key);
}

/// {@category Utils}
///
/// A text with the value [text], locale key marks ignored.
final class AutomationTextSpec extends AutomationFinderSpec {
  final String text;

  const AutomationTextSpec(this.text);
}

/// {@category Utils}
///
/// A tooltip with the message [text], locale key marks ignored.
final class AutomationTooltipSpec extends AutomationFinderSpec {
  final String text;

  const AutomationTooltipSpec(this.text);
}

/// {@category Utils}
///
/// A text that carries the mark of the locale key [key].
final class AutomationLocaleKeySpec extends AutomationFinderSpec {
  final String key;

  const AutomationLocaleKeySpec(this.key);
}

/// {@category Utils}
///
/// A tooltip that carries the mark of the locale key [key].
final class AutomationLocaleKeyTooltipSpec extends AutomationFinderSpec {
  final String key;

  const AutomationLocaleKeyTooltipSpec(this.key);
}

/// {@category Utils}
///
/// A widget of the runtime type named [typeName].
final class AutomationTypeSpec extends AutomationFinderSpec {
  final String typeName;

  const AutomationTypeSpec(this.typeName);
}

/// {@category Utils}
///
/// The back button of a page.
final class AutomationPageBackSpec extends AutomationFinderSpec {
  const AutomationPageBackSpec();
}

/// {@category Utils}
///
/// A widget that [matching] finds among the descendants of what [of] finds, or
/// among its ancestors when [isAncestor] is true.
final class AutomationRelativeSpec extends AutomationFinderSpec {
  final bool isAncestor;
  final AutomationFinderSpec of;
  final AutomationFinderSpec matching;
  final bool matchRoot;

  const AutomationRelativeSpec({
    required this.isAncestor,
    required this.of,
    required this.matching,
    required this.matchRoot,
  });
}
