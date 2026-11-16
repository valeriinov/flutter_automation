import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_label.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_radio_tile.dart';
import 'package:flutter_automation_panel/src/blocks/automation_walk_plaque.dart';
import 'package:flutter_automation_panel/src/pages/automation_catalogue_text.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/player/automation_flow_player.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The plaque of a walk: it names the next action, does it on a tap of Next
/// step and shows the branches at a fork. The selected branch is the variant
/// of the walk until the tester selects another one, so Next step goes on at
/// once. When no action is left, Next step reads Finish and opens the summary
/// of the run.
///
/// The strip shows nothing while no walk runs or while an autorun plays its
/// steps.
class AutomationWalkStrip extends StatelessWidget {
  /// The controller that holds the walk.
  final AutomationPanelController controller;

  /// Called with the vertical move, in pixels, while the tester drags the
  /// plaque. The owner of the strip moves it.
  final ValueChanged<double>? onDragged;

  const AutomationWalkStrip({
    required this.controller,
    this.onDragged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final flow = controller.walkFlow;

        if (flow == null || !_isShown()) {
          return const SizedBox.shrink();
        }

        return AutomationWalkPlaque(
          flowTitle: AutomationCatalogueText.read(
            flow.title,
            flow.name,
            strings.languageCode,
          ),
          collapsedStep: _describeStep(strings, strings.stepShort),
          expandedStep: _describeStep(strings, strings.stepOf),
          overrideCount: controller.overrideCount,
          isExpanded: controller.isWalkExpanded,
          nextLabel: _resolveNextLabel(strings),
          isFinishing: _isFinishing(),
          onToggle: controller.toggleWalk,
          onExit: controller.exitWalk,
          onNext: controller.isWalkBusy ? null : _resolveNextAction(),
          onDragged: onDragged,
          child: _WalkBody(controller: controller),
        );
      },
    );
  }

  bool _isShown() {
    return controller.isWalkActive && !controller.isAutorunPlaying;
  }

  String _describeStep(
    AutomationPanelStrings strings,
    String Function(int number, int count) describe,
  ) {
    final count = controller.actionCount;

    if (controller.isWalkFinished || count == 0) {
      return strings.finished;
    }

    final number = (controller.doneActionCount + 1).clamp(1, count);

    return describe(number, count);
  }

  String _resolveNextLabel(AutomationPanelStrings strings) {
    if (controller.isWalkBusy) {
      return strings.working;
    }

    if (controller.walkFailure != null) {
      return strings.tryAgain;
    }

    return _isFinishing() ? strings.finish : strings.nextStep;
  }

  bool _isFinishing() {
    return !_isAutorun() && !controller.hasActionLeft;
  }

  VoidCallback _resolveNextAction() {
    if (_isAutorun()) {
      return controller.runWalk;
    }

    return _isFinishing() ? controller.finishWalk : controller.playNext;
  }

  bool _isAutorun() {
    return controller.walk?.mode == AutomationWalkMode.autorun;
  }
}

class _WalkBody extends StatelessWidget {
  final AutomationPanelController controller;

  const _WalkBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final fork = controller.pendingFork;
    final failure = controller.walkFailure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AutomationPanelTheme.gapSmall,
      children: [
        if (failure != null) _Failure(reason: failure),
        if (fork != null)
          _Branches(controller: controller)
        else if (controller.hasActionLeft)
          _NextAction(controller: controller)
        else
          _Hint(text: strings.walkFinished),
      ],
    );
  }
}

class _NextAction extends StatelessWidget {
  final AutomationPanelController controller;

  const _NextAction({required this.controller});

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);
    final next = controller.nextAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AutomationPanelTheme.gapSmall,
      children: [
        AutomationPanelLabel(text: strings.nextAction),
        Text(
          next == null
              ? strings.waitsLeft
              : AutomationFlowPlayer.describe(next, strings.languageCode),
          style: theme.textStyle(size: 15, weight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _Branches extends StatelessWidget {
  final AutomationPanelController controller;

  const _Branches({required this.controller});

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final selected = controller.selectedBranch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AutomationPanelTheme.gapSmall,
      children: [
        AutomationPanelLabel(text: strings.chooseBranch),
        for (final branch in controller.forkChoices)
          AutomationPanelRadioTile(
            title: branch.label,
            isSelected: branch.variant == selected,
            onPressed: () => controller.selectBranch(branch.variant),
          ),
      ],
    );
  }
}

class _Failure extends StatelessWidget {
  final String reason;

  const _Failure({required this.reason});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.dangerSoft,
        borderRadius: BorderRadius.circular(AutomationPanelTheme.buttonRadius),
      ),
      child: Text(
        reason,
        style: theme.textStyle(size: 13, color: theme.danger),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Text(
      text,
      style: theme.textStyle(size: 13, color: theme.textSecondary),
    );
  }
}
