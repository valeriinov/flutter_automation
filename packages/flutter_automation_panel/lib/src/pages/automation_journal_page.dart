import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/blocks/automation_latency_note.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_count.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_search_field.dart';
import 'package:flutter_automation_panel/src/blocks/automation_request_row.dart';
import 'package:flutter_automation_panel/src/panel/automation_journal_record.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_scope.dart';
import 'package:flutter_automation_panel/src/sheets/automation_confirm_sheet.dart';
import 'package:flutter_automation_panel/src/sheets/automation_response_sheet.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// The Log tab: the requests the app sent to the mock, newest first, each with
/// the status code it got. A row whose answer an override gave says so under
/// its path. A search over the method, the path and the status code narrows
/// the list. Clear log under the search empties the journal after the tester
/// confirms. A tap opens the response sheet,
/// where the tester changes the override of the request.
class AutomationJournalPage extends StatefulWidget {
  const AutomationJournalPage({super.key});

  @override
  State<AutomationJournalPage> createState() => _AutomationJournalPageState();
}

class _AutomationJournalPageState extends State<AutomationJournalPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final controller = AutomationPanelScope.of(context);
    final theme = AutomationPanelTheme.of(context);

    return ListenableBuilder(
      listenable: controller.mock.journal,
      builder: (context, _) {
        final records = controller.mock.journal.records.reversed
            .where((record) => AutomationJournalRecord.pathOf(record) != null)
            .toList();

        if (records.isEmpty) {
          return Center(
            child: Text(
              AutomationPanelStrings.noRequests,
              style: theme.textStyle(size: 14, color: theme.textSecondary),
            ),
          );
        }

        final matches = records.where(_matchesQuery).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(AutomationPanelTheme.gapLarge),
          itemCount: matches.length + 1,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AutomationPanelTheme.gapSmall),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _Search(
                recordCount: records.length,
                hasMatches: matches.isNotEmpty,
                onChanged: (value) => setState(() => _query = value),
                onClearPressed: () => _confirmClear(context),
              );
            }

            final record = matches[index - 1];
            final path = AutomationJournalRecord.pathOf(record) ?? '';

            return AutomationRequestRow(
              method: AutomationJournalRecord.methodOf(record),
              path: path,
              statusCode: AutomationJournalRecord.statusCodeOf(record),
              note: _describeOverride(record),
              onPressed: () => showAutomationResponseSheet(
                context: context,
                controller: controller,
                method: AutomationJournalRecord.methodOf(record),
                path: path,
                mockStatusCode: AutomationJournalRecord.statusCodeOf(record),
                mockDescription: AutomationPanelStrings.lastAnswer,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context) {
    final controller = AutomationPanelScope.of(context);

    return showAutomationConfirmSheet(
      context: context,
      title: AutomationPanelStrings.clearLogQuestion,
      message: AutomationPanelStrings.clearLogMessage,
      confirmLabel: AutomationPanelStrings.clearLog,
      onConfirmPressed: controller.mock.journal.clear,
    );
  }

  String? _describeOverride(Map<String, Object?> record) {
    final latencyLabel = AutomationLatencyNote
        .labels[AutomationJournalRecord.latencyOverrideOf(record)];
    final parts = [
      if (AutomationJournalRecord.hasFailureOverride(record))
        AutomationPanelStrings.errorAnswer,
      if (latencyLabel != null)
        AutomationPanelStrings.latencyOverrideOf(latencyLabel),
    ];

    if (parts.isEmpty) {
      return null;
    }

    return AutomationPanelStrings.answeredByOverride(parts.join(' · '));
  }

  bool _matchesQuery(Map<String, Object?> record) {
    return matchesSearchQuery(_query, [
      AutomationJournalRecord.methodOf(record),
      AutomationJournalRecord.pathOf(record) ?? '',
      '${AutomationJournalRecord.statusCodeOf(record) ?? ''}',
    ]);
  }
}

class _Search extends StatelessWidget {
  final int recordCount;
  final bool hasMatches;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearPressed;

  const _Search({
    required this.recordCount,
    required this.hasMatches,
    required this.onChanged,
    required this.onClearPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AutomationPanelTheme.gapSmall,
      children: [
        AutomationPanelSearchField(
          hint: AutomationPanelStrings.journalSearchHint,
          onChanged: onChanged,
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                describeCount(recordCount, AutomationPanelStrings.requestNoun),
                style: theme.textStyle(size: 13, color: theme.textSecondary),
              ),
            ),
            TextButton.icon(
              onPressed: onClearPressed,
              icon: Icon(Icons.delete_outline, size: 18, color: theme.danger),
              label: const Text(AutomationPanelStrings.clearLog),
              style: TextButton.styleFrom(
                foregroundColor: theme.danger,
                minimumSize: const Size(0, AutomationPanelTheme.touchTarget),
                textStyle: theme.textStyle(size: 14, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (!hasMatches)
          Text(
            AutomationPanelStrings.noMatches,
            textAlign: TextAlign.center,
            style: theme.textStyle(size: 14, color: theme.textSecondary),
          ),
      ],
    );
  }
}
