import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The line under a latency choice: the delay of [profile] in milliseconds.
class AutomationLatencyNote extends StatelessWidget {
  /// The profile whose delay the line tells.
  final MockLatencyProfile profile;

  /// Whether the request follows the latency of every request. The line then
  /// says so before the delay.
  final bool isInherited;

  const AutomationLatencyNote({
    required this.profile,
    this.isInherited = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);
    final delay = _describeDelay(strings);

    return Text(
      isInherited ? strings.asEveryRequest(delay) : delay,
      style: theme.textStyle(size: 13, color: theme.textSecondary),
    );
  }

  String _describeDelay(AutomationPanelStrings strings) {
    final maxDelay = profile.maxDelay;

    if (maxDelay == Duration.zero) {
      return strings.noDelay;
    }

    return strings.delayOf(
      profile.minDelay.inMilliseconds,
      maxDelay.inMilliseconds,
    );
  }
}
