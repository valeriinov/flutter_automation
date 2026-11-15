import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_count.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_label.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_sheet.dart';
import 'package:flutter_automation_panel/src/blocks/automation_request_row.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The sheet that ends a run: what the run was, how long it took and the
/// requests it sent. The tester shares the logs, runs again or leaves the run.
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

  /// Called when the tester taps Exit run.
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
    return AutomationPanelSheet(
      header: _Header(
        outcome: outcome,
        stepCount: stepCount,
        duration: duration,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AutomationPanelTheme.gapSmall,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: AutomationPanelLabel(text: 'Run requests'),
          ),
          for (final request in requests)
            AutomationRequestRow(
              method: request.method,
              path: request.path,
              statusCode: request.statusCode,
            ),
          const SizedBox(height: 4),
          if (onShare != null)
            AutomationPanelButton(
              label: 'Share logs',
              kind: AutomationPanelButtonKind.primary,
              onPressed: onShare,
            ),
          AutomationPanelButton(label: 'Run again', onPressed: onRunAgain),
          AutomationPanelButton(
            label: 'Exit run',
            kind: AutomationPanelButtonKind.danger,
            onPressed: onExit,
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
                  'Run finished',
                  style: theme.textStyle(size: 18, weight: FontWeight.w700),
                ),
                Text(
                  '$outcome · ${describeCount(stepCount, 'step')} · '
                  '${duration.inSeconds} s',
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
