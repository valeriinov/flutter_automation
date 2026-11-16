import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_count.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_label.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_radio_tile.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_search_field.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_switch_tile.dart';
import 'package:flutter_automation_panel/src/blocks/automation_restart_note.dart';
import 'package:flutter_automation_panel/src/pages/automation_catalogue_text.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_scope.dart';
import 'package:flutter_automation_panel/src/player/automation_flow_player.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// The Autorun tab: the tester picks a flow and an outcome, sets what the run
/// shows and starts an autorun. A search over flows and outcomes narrows the
/// flows; the selected flow is one of those the search leaves.
///
/// The start saves the scenario and the walk, asks the project to restart the
/// app and starts nothing. The autorun begins when the tester opens the app
/// again.
class AutomationAutorunPage extends StatefulWidget {
  const AutomationAutorunPage({super.key});

  @override
  State<AutomationAutorunPage> createState() => _AutomationAutorunPageState();
}

class _AutomationAutorunPageState extends State<AutomationAutorunPage> {
  String? _flowName;
  String? _variantName;
  String _query = '';
  bool _shouldShowTouches = true;
  bool _shouldSignalEnd = true;

  @override
  Widget build(BuildContext context) {
    final controller = AutomationPanelScope.of(context);
    final flows = controller.definition.catalogue.flows
        .where(_matchesQuery)
        .toList();
    final flow = _selectFlow(flows);
    final variant = _selectVariant(flow);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AutomationPanelTheme.gapLarge),
            children: [
              AutomationPanelSearchField(
                hint: AutomationPanelStrings.autorunSearchHint,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: AutomationPanelTheme.gapMedium),
              const AutomationPanelLabel(text: AutomationPanelStrings.flow),
              const SizedBox(height: AutomationPanelTheme.gapSmall),
              for (final candidate in flows)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: AutomationPanelTheme.gapSmall,
                  ),
                  child: AutomationPanelRadioTile(
                    title: AutomationCatalogueText.english(
                      candidate.title,
                      candidate.name,
                    ),
                    isSelected: candidate.name == flow?.name,
                    onPressed: () => _selectFlowByName(candidate.name),
                  ),
                ),
              if (flow != null) ...[
                const SizedBox(height: AutomationPanelTheme.gapMedium),
                const AutomationPanelLabel(
                  text: AutomationPanelStrings.outcome,
                ),
                const SizedBox(height: AutomationPanelTheme.gapSmall),
                for (final candidate in flow.variants)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: AutomationPanelTheme.gapSmall,
                    ),
                    child: AutomationPanelRadioTile(
                      title: AutomationCatalogueText.english(
                        candidate.title,
                        candidate.name,
                      ),
                      subtitle: _describe(candidate),
                      isSelected: candidate.name == variant?.name,
                      onPressed: () => _selectVariantByName(candidate.name),
                    ),
                  ),
              ],
              const SizedBox(height: AutomationPanelTheme.gapMedium),
              const AutomationPanelLabel(
                text: AutomationPanelStrings.recording,
              ),
              const SizedBox(height: AutomationPanelTheme.gapSmall),
              _Recording(
                shouldShowTouches: _shouldShowTouches,
                shouldSignalEnd: _shouldSignalEnd,
                onTouchesChanged: (value) {
                  setState(() => _shouldShowTouches = value);
                },
                onSignalChanged: (value) {
                  setState(() => _shouldSignalEnd = value);
                },
              ),
            ],
          ),
        ),
        _Footer(
          onStart: flow == null || variant == null
              ? null
              : () => _start(controller, flow, variant),
        ),
      ],
    );
  }

  bool _matchesQuery(AutomationCatalogueFlow flow) {
    return matchesSearchQuery(_query, [
      AutomationCatalogueText.english(flow.title, flow.name),
      for (final variant in flow.variants)
        AutomationCatalogueText.english(variant.title, variant.name),
    ]);
  }

  AutomationCatalogueFlow? _selectFlow(List<AutomationCatalogueFlow> flows) {
    return flows.firstWhereOrNull((flow) => flow.name == _flowName) ??
        flows.firstOrNull;
  }

  AutomationCatalogueVariant? _selectVariant(AutomationCatalogueFlow? flow) {
    final variants = flow?.variants ?? const <AutomationCatalogueVariant>[];
    final name = _variantName ?? flow?.defaultVariant;

    return variants.firstWhereOrNull((variant) => variant.name == name) ??
        variants.firstOrNull;
  }

  String _describe(AutomationCatalogueVariant variant) {
    final steps = variant.steps.where(AutomationFlowPlayer.isAction).length;

    return describeCount(steps, AutomationPanelStrings.stepNoun);
  }

  void _selectFlowByName(String name) {
    setState(() {
      _flowName = name;
      _variantName = null;
    });
  }

  void _selectVariantByName(String name) {
    setState(() => _variantName = name);
  }

  Future<void> _start(
    AutomationPanelController controller,
    AutomationCatalogueFlow flow,
    AutomationCatalogueVariant variant,
  ) {
    return controller.startWalk(
      flow.name,
      variant.name,
      mode: AutomationWalkMode.autorun,
      shouldShowTouches: _shouldShowTouches,
      shouldSignalEnd: _shouldSignalEnd,
    );
  }
}

class _Recording extends StatelessWidget {
  final bool shouldShowTouches;
  final bool shouldSignalEnd;
  final ValueChanged<bool> onTouchesChanged;
  final ValueChanged<bool> onSignalChanged;

  const _Recording({
    required this.shouldShowTouches,
    required this.shouldSignalEnd,
    required this.onTouchesChanged,
    required this.onSignalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(AutomationPanelTheme.cardRadius),
        border: Border.all(color: theme.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AutomationPanelTheme.gapMedium,
        ),
        child: Column(
          children: [
            AutomationPanelSwitchTile(
              title: AutomationPanelStrings.showTouches,
              subtitle: AutomationPanelStrings.showTouchesNote,
              isOn: shouldShowTouches,
              onChanged: onTouchesChanged,
            ),
            AutomationPanelSwitchTile(
              title: AutomationPanelStrings.signalAtEnd,
              subtitle: AutomationPanelStrings.signalAtEndNote,
              isOn: shouldSignalEnd,
              onChanged: onSignalChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final VoidCallback? onStart;

  const _Footer({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AutomationPanelTheme.gapLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AutomationPanelTheme.gapSmall,
          children: [
            const AutomationRestartNote(
              text: AutomationPanelStrings.autorunNote,
            ),
            AutomationPanelButton(
              label: AutomationPanelStrings.restartAndRun,
              kind: AutomationPanelButtonKind.primary,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}
