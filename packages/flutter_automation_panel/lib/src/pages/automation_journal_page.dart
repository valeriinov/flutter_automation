import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/blocks/automation_request_row.dart';
import 'package:flutter_automation_panel/src/panel/automation_journal_record.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_scope.dart';
import 'package:flutter_automation_panel/src/sheets/automation_response_sheet.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// The Log tab: the requests the app sent to the mock, newest first. A tap
/// opens the response sheet of the request.
class AutomationJournalPage extends StatelessWidget {
  const AutomationJournalPage({super.key});

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

        return ListView.separated(
          padding: const EdgeInsets.all(AutomationPanelTheme.gapLarge),
          itemCount: records.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AutomationPanelTheme.gapSmall),
          itemBuilder: (context, index) {
            final record = records[index];
            final path = AutomationJournalRecord.pathOf(record) ?? '';

            return AutomationRequestRow(
              method: AutomationJournalRecord.methodOf(record),
              path: path,
              statusCode: AutomationJournalRecord.statusCodeOf(record),
              failure: controller.failureOf(path),
              onClearOverride: () => controller.setFailure(path, null),
              onPressed: () => showAutomationResponseSheet(
                context: context,
                controller: controller,
                method: AutomationJournalRecord.methodOf(record),
                path: path,
                mockStatusCode: AutomationJournalRecord.statusCodeOf(record),
                mockDescription: 'last answer',
              ),
            );
          },
        );
      },
    );
  }
}
