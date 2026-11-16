import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The line under a latency choice: the delay of [profile] in milliseconds.
class AutomationLatencyNote extends StatelessWidget {
  /// Labels of the latency profiles, in the order a latency choice shows them.
  static const labels = {
    MockLatencyProfile.fast: AutomationPanelStrings.latencyFast,
    MockLatencyProfile.realistic: AutomationPanelStrings.latencyRealistic,
    MockLatencyProfile.slow: AutomationPanelStrings.latencySlow,
  };

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
    final theme = AutomationPanelTheme.of(context);
    final delay = _describeDelay();

    return Text(
      isInherited ? AutomationPanelStrings.asEveryRequest(delay) : delay,
      style: theme.textStyle(size: 13, color: theme.textSecondary),
    );
  }

  String _describeDelay() {
    final maxDelay = profile.maxDelay;

    if (maxDelay == Duration.zero) {
      return AutomationPanelStrings.noDelay;
    }

    return AutomationPanelStrings.delayOf(
      profile.minDelay.inMilliseconds,
      maxDelay.inMilliseconds,
    );
  }
}
