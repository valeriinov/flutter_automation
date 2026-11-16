import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/blocks/automation_latency_note.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_frame.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_label.dart';
import 'package:flutter_automation_panel/src/blocks/automation_request_row.dart';
import 'package:flutter_automation_panel/src/pages/automation_section_panel.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_changes.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_scope.dart';
import 'package:flutter_automation_panel/src/panel/automation_profile_selection.dart';
import 'package:flutter_automation_panel/src/sheets/automation_confirm_sheet.dart';
import 'package:flutter_automation_panel/src/sheets/automation_response_sheet.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The Changes page: everything the mock holds apart from its defaults, in
/// one place. It lists the latency of every request, the profile of each
/// section that differs from its defaults, the overrides of single requests
/// and any other key of the scenario. A cross removes one change, and Reset
/// all removes every change.
///
/// The status row of the panel opens it. The profiles come from the
/// `sections` of the definition.
class AutomationChangesPage extends StatelessWidget {
  const AutomationChangesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AutomationPanelScope.of(context);
    final theme = AutomationPanelTheme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isChanged = controller.isChanged;

        return AutomationPanelFrame(
          title: AutomationPanelStrings.changes,
          onBack: () => Navigator.of(context).pop(),
          onClose: controller.closePanel,
          footer: isChanged
              ? AutomationPanelButton(
                  label: AutomationPanelStrings.resetAll,
                  onPressed: () => showAutomationResetSheet(
                    context: context,
                    controller: controller,
                    onReset: Navigator.of(context).pop,
                  ),
                )
              : null,
          child: Material(
            color: theme.background,
            child: isChanged
                ? _ChangeList(controller: controller)
                : const _NothingChanged(),
          ),
        );
      },
    );
  }
}

class _ChangeList extends StatelessWidget {
  final AutomationPanelController controller;

  const _ChangeList({required this.controller});

  @override
  Widget build(BuildContext context) {
    final outcomeTitle = controller.outcomeTitle;
    final changes = AutomationPanelChanges.read(controller);
    final profiles = changes.profiles;
    final paths = changes.paths;
    final otherKeys = changes.otherKeys;

    return ListView(
      padding: const EdgeInsets.all(AutomationPanelTheme.gapLarge),
      children: [
        if (outcomeTitle != null) ...[
          _ChangeRow(
            title: AutomationPanelStrings.outcome,
            value: outcomeTitle,
          ),
          const SizedBox(height: AutomationPanelTheme.gapMedium),
        ],
        if (changes.hasLatency) ...[
          _ChangeRow(
            title: AutomationPanelStrings.responseLatency,
            value:
                AutomationLatencyNote.labels[controller.mock.latency.profile] ??
                '',
            onRemove: () => _removeKey(context, MockScenario.latencyKey),
          ),
          const SizedBox(height: AutomationPanelTheme.gapMedium),
        ],
        if (profiles.isNotEmpty) ...[
          const AutomationPanelLabel(text: AutomationPanelStrings.profiles),
          const SizedBox(height: AutomationPanelTheme.gapSmall),
          for (final section in profiles) ...[
            _ChangeRow(
              title: section.title,
              value: _describeProfile(section),
              onRemove: () => _removeProfile(context, section),
            ),
            const SizedBox(height: AutomationPanelTheme.gapSmall),
          ],
          const SizedBox(height: AutomationPanelTheme.gapSmall),
        ],
        if (paths.isNotEmpty) ...[
          const AutomationPanelLabel(text: AutomationPanelStrings.requests),
          const SizedBox(height: AutomationPanelTheme.gapSmall),
          for (final path in paths) ...[
            AutomationRequestRow(
              method: '',
              path: path,
              failure: controller.failures[path],
              latency: controller.latencies[path],
              onPressed: () => showAutomationResponseSheet(
                context: context,
                controller: controller,
                path: path,
                mockDescription: AutomationPanelStrings.lastAnswer,
              ),
              onClearOverride: () => controller.clearOverride(path),
            ),
            const SizedBox(height: AutomationPanelTheme.gapSmall),
          ],
          const SizedBox(height: AutomationPanelTheme.gapSmall),
        ],
        if (otherKeys.isNotEmpty) ...[
          const AutomationPanelLabel(
            text: AutomationPanelStrings.otherSettings,
          ),
          const SizedBox(height: AutomationPanelTheme.gapSmall),
          for (final key in otherKeys) ...[
            _ChangeRow(
              title: key,
              value: AutomationPanelStrings.custom,
              onRemove: () => _removeKey(context, key),
            ),
            const SizedBox(height: AutomationPanelTheme.gapSmall),
          ],
        ],
      ],
    );
  }

  String _describeProfile(AutomationSectionPanel section) {
    final mockSection = section.section;

    if (mockSection == null) {
      return '';
    }

    return AutomationProfileSelection.read(
      controller,
      mockSection,
    ).describe(section);
  }

  void _removeProfile(BuildContext context, AutomationSectionPanel section) {
    final mockSection = section.section;

    if (mockSection == null) {
      return;
    }

    applyAutomationScenario(
      context: context,
      controller: controller,
      scenario: AutomationProfileSelection.scenarioWith(
        controller,
        mockSection,
        null,
      ),
    );
  }

  void _removeKey(BuildContext context, String key) {
    final json = controller.mock.scenario.toJson()..remove(key);

    applyAutomationScenario(
      context: context,
      controller: controller,
      scenario: MockScenario.fromJson(json),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onRemove;

  const _ChangeRow({required this.title, required this.value, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final onRemove = this.onRemove;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(AutomationPanelTheme.buttonRadius),
        border: Border.all(color: theme.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AutomationPanelTheme.buttonHeight,
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AutomationPanelTheme.gapSmall,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      title,
                      style: theme.textStyle(
                        size: 13,
                        color: theme.textSecondary,
                      ),
                    ),
                    Text(
                      value,
                      style: theme.textStyle(
                        size: 14,
                        weight: FontWeight.w600,
                        color: theme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onRemove == null)
              const SizedBox(width: 14)
            else
              IconButton(
                onPressed: onRemove,
                tooltip: AutomationPanelStrings.removeOverride,
                icon: Icon(Icons.close, size: 20, color: theme.danger),
              ),
          ],
        ),
      ),
    );
  }
}

class _NothingChanged extends StatelessWidget {
  const _NothingChanged();

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Center(
      child: Text(
        AutomationPanelStrings.nothingChanged,
        style: theme.textStyle(size: 14, color: theme.textSecondary),
      ),
    );
  }
}
