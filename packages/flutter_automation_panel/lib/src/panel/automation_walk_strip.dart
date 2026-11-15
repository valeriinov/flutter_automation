import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_label.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_radio_tile.dart';
import 'package:flutter_automation_panel/src/blocks/automation_walk_plaque.dart';
import 'package:flutter_automation_panel/src/pages/automation_catalogue_text.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/player/automation_flow_player.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The plaque of a walk: it names the next action, does it on a tap of Next
/// step and shows the branches at a fork.
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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final flow = controller.walkFlow;

        if (flow == null || !_isShown()) {
          return const SizedBox.shrink();
        }

        return AutomationWalkPlaque(
          title: _describeTitle(flow),
          overrideCount: controller.overrideCount,
          isExpanded: controller.isWalkExpanded,
          onToggle: controller.toggleWalk,
          onExit: controller.exitWalk,
          onDragged: onDragged,
          child: _WalkBody(controller: controller),
        );
      },
    );
  }

  bool _isShown() {
    return controller.isWalkActive && !controller.isAutorunPlaying;
  }

  String _describeTitle(AutomationCatalogueFlow flow) {
    final flowTitle = AutomationCatalogueText.english(flow.title, flow.name);
    final count = controller.actionCount;

    if (controller.isWalkFinished || count == 0) {
      return '$flowTitle · finished';
    }

    final number = (controller.doneActionCount + 1).clamp(1, count);

    return '$flowTitle · step $number of $count';
  }
}

class _WalkBody extends StatelessWidget {
  final AutomationPanelController controller;

  const _WalkBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final fork = controller.pendingFork;
    final failure = controller.walkFailure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AutomationPanelTheme.gapSmall,
      children: [
        if (failure != null) _Failure(reason: failure),
        if (controller.isWalkFinished)
          const _Hint(text: 'The flow is finished. Tap Exit to leave the walk.')
        else if (fork != null)
          _Branches(controller: controller)
        else
          _NextAction(controller: controller),
      ],
    );
  }
}

class _NextAction extends StatelessWidget {
  final AutomationPanelController controller;

  const _NextAction({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final next = controller.nextAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AutomationPanelTheme.gapSmall,
      children: [
        const AutomationPanelLabel(text: 'Next action'),
        Text(
          next == null ? 'The waits that are left' : _describe(next),
          style: theme.textStyle(size: 15, weight: FontWeight.w700),
        ),
        AutomationPanelButton(
          label: _resolveLabel(),
          kind: AutomationPanelButtonKind.primary,
          onPressed: controller.isWalkBusy ? null : _resolveAction(),
        ),
      ],
    );
  }

  VoidCallback _resolveAction() {
    final isAutorun = controller.walk?.mode == AutomationWalkMode.autorun;

    return isAutorun ? controller.runWalk : controller.playNext;
  }

  String _describe(AutomationCatalogueStep step) {
    return AutomationFlowPlayer.describe(step);
  }

  String _resolveLabel() {
    if (controller.isWalkBusy) {
      return 'Working…';
    }

    return controller.walkFailure == null ? 'Next step' : 'Try again';
  }
}

class _Branches extends StatelessWidget {
  final AutomationPanelController controller;

  const _Branches({required this.controller});

  @override
  Widget build(BuildContext context) {
    final current = controller.walk?.variant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AutomationPanelTheme.gapSmall,
      children: [
        const AutomationPanelLabel(text: 'Choose the branch'),
        for (final branch in controller.forkChoices)
          AutomationPanelRadioTile(
            title: branch.label,
            isSelected: branch.variant == current,
            onPressed: () => controller.chooseBranch(branch.variant),
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
