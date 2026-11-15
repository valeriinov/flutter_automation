import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/src/blocks/automation_flow_step.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button_group.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_frame.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_radio_tile.dart';
import 'package:flutter_automation_panel/src/blocks/automation_request_row.dart';
import 'package:flutter_automation_panel/src/pages/automation_catalogue_text.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_scope.dart';
import 'package:flutter_automation_panel/src/sheets/automation_response_sheet.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The map of one flow: its steps with their requests and its fork. The tester
/// picks an outcome at the fork, overrides the answer of a request and starts
/// the flow or only sets its state.
///
/// A start that needs a restart of the app saves the state and the walk, asks
/// the project to restart and starts nothing.
class AutomationFlowMapPage extends StatefulWidget {
  /// The flow to show.
  final AutomationCatalogueFlow flow;

  const AutomationFlowMapPage({required this.flow, super.key});

  @override
  State<AutomationFlowMapPage> createState() => _AutomationFlowMapPageState();
}

class _AutomationFlowMapPageState extends State<AutomationFlowMapPage> {
  String? _variantName;

  bool get _hasOutcomeStep {
    return widget.flow.fork == null && widget.flow.variants.length > 1;
  }

  AutomationCatalogueVariant? get _selectedVariant {
    final variants = widget.flow.variants;
    final name = _variantName ?? widget.flow.defaultVariant;

    return variants.firstWhereOrNull((variant) => variant.name == name) ??
        variants.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AutomationPanelScope.of(context);
    final variant = _selectedVariant;
    final shown = _shownSteps(variant);

    return AutomationPanelFrame(
      title: AutomationCatalogueText.english(
        widget.flow.title,
        widget.flow.name,
      ),
      subtitle: _describe(variant),
      onBack: () => Navigator.of(context).pop(),
      onClose: controller.closePanel,
      footer: variant == null
          ? null
          : _Footer(
              variant: variant,
              controller: controller,
              onApplyAndStart: () => _applyAndStart(controller, variant),
              onSetState: () => _applyOutcome(controller, variant),
            ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AutomationPanelTheme.gapLarge,
          AutomationPanelTheme.gapLarge,
          AutomationPanelTheme.gapLarge,
          0,
        ),
        children: [
          if (_hasOutcomeStep)
            AutomationFlowStep(
              number: 1,
              title: 'Outcome',
              isFork: true,
              isLast: shown.isEmpty,
              children: [
                for (final outcome in widget.flow.variants)
                  _OutcomeTile(
                    variant: outcome,
                    isSelected: outcome.name == variant?.name,
                    onSelected: () => _select(outcome),
                  ),
              ],
            ),
          for (int position = 0; position < shown.length; position += 1)
            _StepTile(
              flow: widget.flow,
              controller: controller,
              number: position + 1 + (_hasOutcomeStep ? 1 : 0),
              isLast: position == shown.length - 1,
              index: shown[position].$1,
              step: shown[position].$2,
              selectedVariant: variant?.name,
              onVariantSelected: _select,
            ),
        ],
      ),
    );
  }

  List<(int, AutomationCatalogueStep)> _shownSteps(
    AutomationCatalogueVariant? variant,
  ) {
    if (variant == null) {
      return const [];
    }

    return [
      for (int index = 0; index < variant.steps.length; index += 1)
        if (!variant.steps[index].isService) (index, variant.steps[index]),
    ];
  }

  String _describe(AutomationCatalogueVariant? variant) {
    final entry = AutomationCatalogueText.english(variant?.entry, '');
    final parts = [
      if (entry.isNotEmpty) 'Start: $entry',
      if (widget.flow.fork != null) '1 fork',
    ];

    return parts.join(' · ');
  }

  void _select(AutomationCatalogueVariant variant) {
    setState(() => _variantName = variant.name);
  }

  Future<bool> _applyOutcome(
    AutomationPanelController controller,
    AutomationCatalogueVariant variant, {
    AutomationWalkProgress? walk,
  }) {
    return controller.applyOutcome(
      variant.scenario,
      title: AutomationCatalogueText.english(variant.title, variant.name),
      walk: walk,
    );
  }

  Future<void> _applyAndStart(
    AutomationPanelController controller,
    AutomationCatalogueVariant variant,
  ) async {
    final needsRestart = await _applyOutcome(
      controller,
      variant,
      walk: AutomationWalkProgress(
        flow: widget.flow.name,
        variant: variant.name,
      ),
    );

    if (needsRestart) {
      return;
    }

    controller.closePanel();

    await controller.definition.onStart?.call(widget.flow.name, variant.name);
  }
}

class _OutcomeTile extends StatelessWidget {
  final AutomationCatalogueVariant variant;
  final String? label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _OutcomeTile({
    required this.variant,
    required this.isSelected,
    required this.onSelected,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final title = AutomationCatalogueText.english(variant.title, variant.name);
    final proves = AutomationCatalogueText.english(variant.proves, '');
    final label = this.label;

    return AutomationPanelRadioTile(
      title: label == null || label.isEmpty ? title : label,
      subtitle: proves.isEmpty ? null : proves,
      isSelected: isSelected,
      onPressed: onSelected,
    );
  }
}

class _StepTile extends StatelessWidget {
  final AutomationCatalogueFlow flow;
  final AutomationPanelController controller;
  final int number;
  final bool isLast;
  final int index;
  final AutomationCatalogueStep step;
  final String? selectedVariant;
  final ValueChanged<AutomationCatalogueVariant> onVariantSelected;

  const _StepTile({
    required this.flow,
    required this.controller,
    required this.number,
    required this.isLast,
    required this.index,
    required this.step,
    required this.selectedVariant,
    required this.onVariantSelected,
  });

  @override
  Widget build(BuildContext context) {
    final fork = flow.fork;
    final isFork = fork != null && fork.stepIndex == index;

    return AutomationFlowStep(
      number: number,
      title: step.label,
      isFork: isFork,
      isLast: isLast,
      children: [
        if (!isFork)
          for (final request in step.requests)
            AutomationRequestRow(
              method: request.method,
              path: request.path,
              statusCode: request.statusCode,
              failure: controller.failureOf(request.path),
              onPressed: () => _openResponse(context, request),
              onClearOverride: () => controller.setFailure(request.path, null),
            ),
        if (fork != null && isFork)
          for (final option in _forkOptions(fork))
            _OutcomeTile(
              variant: option.$1,
              label: option.$2,
              isSelected: option.$1.name == selectedVariant,
              onSelected: () => onVariantSelected(option.$1),
            ),
      ],
    );
  }

  List<(AutomationCatalogueVariant, String?)> _forkOptions(
    AutomationCatalogueFork fork,
  ) {
    final branched = <String>{};
    final options = <(AutomationCatalogueVariant, String?)>[];

    for (final branch in fork.branches) {
      final variant = flow.variants.firstWhereOrNull(
        (variant) => variant.name == branch.variant,
      );

      if (variant != null) {
        branched.add(variant.name);
        options.add((variant, branch.label));
      }
    }

    for (final variant in flow.variants) {
      if (!branched.contains(variant.name)) {
        options.add((variant, null));
      }
    }

    return options;
  }

  Future<void> _openResponse(
    BuildContext context,
    AutomationCatalogueRequest request,
  ) {
    return showAutomationResponseSheet(
      context: context,
      controller: controller,
      method: request.method,
      path: request.path,
      mockStatusCode: request.statusCode,
      mockDescription: 'default answer',
    );
  }
}

class _Footer extends StatelessWidget {
  final AutomationCatalogueVariant variant;
  final AutomationPanelController controller;
  final VoidCallback onApplyAndStart;
  final VoidCallback onSetState;

  const _Footer({
    required this.variant,
    required this.controller,
    required this.onApplyAndStart,
    required this.onSetState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final title = AutomationCatalogueText.english(variant.title, variant.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AutomationPanelTheme.gapSmall,
      children: [
        Text.rich(
          TextSpan(
            text: 'Result: ',
            children: [
              TextSpan(
                text: title,
                style: TextStyle(
                  color: theme.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          style: theme.textStyle(size: 13, color: theme.textSecondary),
        ),
        if (controller.requiresRestart(variant.scenario)) const _RestartNote(),
        AutomationPanelButtonGroup(
          buttons: [
            AutomationPanelButton(
              label: 'Apply and start',
              kind: AutomationPanelButtonKind.primary,
              onPressed: onApplyAndStart,
            ),
            AutomationPanelButton(label: 'Set state', onPressed: onSetState),
          ],
        ),
      ],
    );
  }
}

class _RestartNote extends StatelessWidget {
  const _RestartNote();

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.restartSoft,
        borderRadius: BorderRadius.circular(AutomationPanelTheme.buttonRadius),
      ),
      child: Row(
        spacing: AutomationPanelTheme.gapSmall,
        children: [
          Icon(Icons.refresh, size: 20, color: theme.restart),
          Expanded(
            child: Text(
              'Launch settings change: the app restarts',
              style: theme.textStyle(size: 13, color: theme.restartText),
            ),
          ),
        ],
      ),
    );
  }
}
