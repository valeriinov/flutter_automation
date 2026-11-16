import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_search_field.dart';
import 'package:flutter_automation_panel/src/blocks/automation_request_row.dart';
import 'package:flutter_automation_panel/src/panel/automation_journal_record.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_scope.dart';
import 'package:flutter_automation_panel/src/sheets/automation_response_sheet.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// The Log tab: the requests the app sent to the mock, newest first. A search
/// over the method, the path and the status code narrows the list. A tap opens
/// the response sheet of the request.
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
                hasMatches: matches.isNotEmpty,
                onChanged: (value) => setState(() => _query = value),
              );
            }

            final record = matches[index - 1];
            final path = AutomationJournalRecord.pathOf(record) ?? '';

            return AutomationRequestRow(
              method: AutomationJournalRecord.methodOf(record),
              path: path,
              statusCode: AutomationJournalRecord.statusCodeOf(record),
              failure: controller.failureOf(path),
              latency: controller.latencyOf(path),
              onClearOverride: () => controller.clearOverride(path),
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

  bool _matchesQuery(Map<String, Object?> record) {
    return matchesSearchQuery(_query, [
      AutomationJournalRecord.methodOf(record),
      AutomationJournalRecord.pathOf(record) ?? '',
      '${AutomationJournalRecord.statusCodeOf(record) ?? ''}',
    ]);
  }
}

class _Search extends StatelessWidget {
  final bool hasMatches;
  final ValueChanged<String> onChanged;

  const _Search({required this.hasMatches, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AutomationPanelTheme.gapMedium,
      children: [
        AutomationPanelSearchField(
          hint: AutomationPanelStrings.journalSearchHint,
          onChanged: onChanged,
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
