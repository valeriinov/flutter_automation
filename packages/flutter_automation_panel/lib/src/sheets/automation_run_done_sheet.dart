import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_label.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_sheet.dart';
import 'package:flutter_automation_panel/src/blocks/automation_request_row.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The sheet that ends a run: what the run was, how long it took and the
/// requests it sent. The tester shares the logs, runs again or leaves the run.
/// The sheet stands still and has no grabber. The buttons stay at the bottom,
/// and the requests scroll above them. Exit is
/// the main button; Share logs and Run again are second actions.
///
/// The sheet takes the data of a stored report, so a project shows it after a
/// run that ended before the app restarted.
class AutomationRunDoneSheet extends StatelessWidget {
  /// Title of the outcome the run walked.
  final String outcome;

  /// How many steps the run walked.
  final int stepCount;

  /// How long the run took.
  final Duration duration;

  /// Requests the run sent, in order.
  final List<AutomationCatalogueRequest> requests;

  /// Called when the tester taps Share logs, missing when the project shares
  /// nothing. The sheet then hides the button.
  final VoidCallback? onShare;

  /// Called when the tester taps Run again.
  final VoidCallback onRunAgain;

  /// Called when the tester taps Exit.
  final VoidCallback onExit;

  const AutomationRunDoneSheet({
    required this.outcome,
    required this.stepCount,
    required this.duration,
    required this.requests,
    required this.onRunAgain,
    required this.onExit,
    this.onShare,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);

    return AutomationPanelSheet(
      hasGrabber: false,
      header: _Header(
        outcome: outcome,
        stepCount: stepCount,
        duration: duration,
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AutomationPanelTheme.gapSmall,
        children: [
          if (onShare != null)
            AutomationPanelButton(label: strings.shareLogs, onPressed: onShare),
          AutomationPanelButton(label: strings.runAgain, onPressed: onRunAgain),
          AutomationPanelButton(
            label: strings.exit,
            kind: AutomationPanelButtonKind.primary,
            onPressed: onExit,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AutomationPanelTheme.gapSmall,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: AutomationPanelLabel(text: strings.runRequests),
          ),
          for (final request in requests)
            AutomationRequestRow(
              method: request.method,
              path: request.path,
              statusCode: request.statusCode,
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String outcome;
  final int stepCount;
  final Duration duration;

  const _Header({
    required this.outcome,
    required this.stepCount,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        spacing: AutomationPanelTheme.gapMedium,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.successSoft,
            ),
            child: Icon(Icons.check, color: theme.success),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.runFinished,
                  style: theme.textStyle(size: 18, weight: FontWeight.w700),
                ),
                Text(
                  [
                    outcome,
                    strings.stepCount(stepCount),
                    strings.seconds(duration.inSeconds),
                  ].join(' · '),
                  style: theme.textStyle(size: 13, color: theme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
