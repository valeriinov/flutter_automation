import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Utils}
///
/// The words that count [count] things, such as `1 step` or `3 steps`.
///
/// The [noun] parameter is the singular noun. The plural adds an `s`.
String describeCount(int count, String noun) {
  return '$count ${count == 1 ? noun : '${noun}s'}';
}

/// {@category Utils}
///
/// The words that count the overrides of the panel, such as `2 overrides`.
String describeOverrideCount(int count) =>
    describeCount(count, AutomationPanelStrings.overrideNoun);
