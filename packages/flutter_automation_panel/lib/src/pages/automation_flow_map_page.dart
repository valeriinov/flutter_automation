import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/src/blocks/automation_flow_step.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_frame.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_radio_tile.dart';
import 'package:flutter_automation_panel/src/blocks/automation_request_row.dart';
import 'package:flutter_automation_panel/src/blocks/automation_restart_note.dart';
import 'package:flutter_automation_panel/src/pages/automation_catalogue_text.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_scope.dart';
import 'package:flutter_automation_panel/src/sheets/automation_response_sheet.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// The map of one flow: its steps with their requests and its fork. The tester
/// picks the branches that a restart applies, overrides the answer of a request
/// and starts the walk.
///
/// A start saves the scenario and the walk, asks the project to restart the
/// app and starts nothing. The walk begins when the tester opens the app
/// again. The tester picks the other branches at the fork, during the walk.
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

  List<AutomationCatalogueBranch> get _beforeStartBranches {
    final branches = widget.flow.fork?.branches ?? const [];

    return branches.where((branch) => branch.isChosenBeforeStart).toList();
  }

  AutomationCatalogueVariant? get _selectedVariant {
    final variants = widget.flow.variants;
    final name = _variantName ?? _resolveInitialName();

    return variants.firstWhereOrNull((variant) => variant.name == name) ??
        variants.firstOrNull;
  }

  String? _resolveInitialName() {
    final branches = _beforeStartBranches;
    final defaultName = widget.flow.defaultVariant;
    final isDefaultListed = branches.any(
      (branch) => branch.variant == defaultName,
    );

    if (branches.isEmpty || isDefaultListed) {
      return defaultName;
    }

    return branches.first.variant;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final controller = AutomationPanelScope.of(context);
    final variant = _selectedVariant;
    final shown = _shownSteps(variant);

    return AutomationPanelFrame(
      title: AutomationCatalogueText.read(
        widget.flow.title,
        widget.flow.name,
        strings.languageCode,
      ),
      subtitle: _describe(variant),
      onBack: () => Navigator.of(context).pop(),
      onClose: controller.closePanel,
      footer: variant == null
          ? null
          : _Footer(
              variant: variant,
              onStart: () => _start(controller, variant),
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
              title: strings.outcome,
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
              beforeStartBranches: _beforeStartBranches,
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
    final strings = AutomationPanelStrings.of(context);
    final entry = AutomationCatalogueText.read(
      variant?.entry,
      '',
      strings.languageCode,
    );
    final parts = [
      if (entry.isNotEmpty) strings.startOf(entry),
      if (widget.flow.fork != null) strings.oneFork,
    ];

    return parts.join(' · ');
  }

  void _select(AutomationCatalogueVariant variant) {
    setState(() => _variantName = variant.name);
  }

  Future<void> _start(
    AutomationPanelController controller,
    AutomationCatalogueVariant variant,
  ) {
    return controller.startWalk(widget.flow.name, variant.name);
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
    final strings = AutomationPanelStrings.of(context);
    final title = AutomationCatalogueText.read(
      variant.title,
      variant.name,
      strings.languageCode,
    );
    final proves = AutomationCatalogueText.read(
      variant.proves,
      '',
      strings.languageCode,
    );
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
  final List<AutomationCatalogueBranch> beforeStartBranches;
  final ValueChanged<AutomationCatalogueVariant> onVariantSelected;

  const _StepTile({
    required this.flow,
    required this.controller,
    required this.number,
    required this.isLast,
    required this.index,
    required this.step,
    required this.selectedVariant,
    required this.beforeStartBranches,
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
              latency: controller.latencyOf(request.path),
              onPressed: () => _openResponse(context, request),
              onClearOverride: () => controller.clearOverride(request.path),
            ),
        if (fork != null && isFork)
          for (final option in _forkOptions(fork))
            _OutcomeTile(
              variant: option.$1,
              label: option.$2,
              isSelected: option.$1.name == selectedVariant,
              onSelected: () => onVariantSelected(option.$1),
            ),
        if (fork != null && isFork && beforeStartBranches.isEmpty)
          const _ForkHint(),
      ],
    );
  }

  List<(AutomationCatalogueVariant, String?)> _forkOptions(
    AutomationCatalogueFork fork,
  ) {
    final listed = beforeStartBranches.isEmpty
        ? fork.branches
        : beforeStartBranches;
    final options = <(AutomationCatalogueVariant, String?)>[];

    for (final branch in listed) {
      final variant = flow.variants.firstWhereOrNull(
        (variant) => variant.name == branch.variant,
      );

      if (variant != null) {
        options.add((variant, branch.label));
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

class _ForkHint extends StatelessWidget {
  const _ForkHint();

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);

    return Text(
      strings.forkNote,
      style: theme.textStyle(size: 13, color: theme.textSecondary),
    );
  }
}

class _Footer extends StatelessWidget {
  final AutomationCatalogueVariant variant;
  final VoidCallback onStart;

  const _Footer({required this.variant, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);
    final title = AutomationCatalogueText.read(
      variant.title,
      variant.name,
      strings.languageCode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AutomationPanelTheme.gapSmall,
      children: [
        Text.rich(
          TextSpan(
            text: strings.resultPrefix,
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
        AutomationRestartNote(text: strings.walkRestartNote),
        AutomationPanelButton(
          label: strings.restartAndBegin,
          kind: AutomationPanelButtonKind.primary,
          onPressed: onStart,
        ),
      ],
    );
  }
}
