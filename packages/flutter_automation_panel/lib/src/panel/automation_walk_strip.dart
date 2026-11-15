import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button_group.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_chips.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_label.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_option.dart';
import 'package:flutter_automation_panel/src/blocks/automation_request_row.dart';
import 'package:flutter_automation_panel/src/blocks/automation_walk_plaque.dart';
import 'package:flutter_automation_panel/src/pages/automation_catalogue_text.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The strip of a manual walk: it shows where the walk stands, the requests
/// the tester has passed and the answer of the next request.
///
/// The controller moves the walk forward when the journal shows a request of a
/// later step. The strip shows nothing while the tester hides it or when the
/// variant of the walk has no steps.
class AutomationWalkStrip extends StatelessWidget {
  /// The controller that holds the walk.
  final AutomationPanelController controller;

  const AutomationWalkStrip({required this.controller, super.key});

  bool _isShown(List<AutomationCatalogueStep> steps) {
    return steps.isNotEmpty && !controller.isWalkHidden;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final walk = controller.walk;
        final flow = controller.walkFlow;
        final steps = controller.walkSteps;

        if (walk == null || flow == null || !_isShown(steps)) {
          return const SizedBox.shrink();
        }

        final current = walk.stepIndex.clamp(0, steps.length - 1);
        final flowTitle = AutomationCatalogueText.english(
          flow.title,
          flow.name,
        );

        return AutomationWalkPlaque(
          title: '$flowTitle · step ${current + 1} of ${steps.length}',
          overrideCount: controller.overrideCount,
          isExpanded: controller.isWalkExpanded,
          onToggle: controller.toggleWalk,
          onHide: controller.hideWalk,
          child: _WalkBody(
            controller: controller,
            steps: steps,
            current: current,
          ),
        );
      },
    );
  }
}

class _WalkBody extends StatelessWidget {
  final AutomationPanelController controller;
  final List<AutomationCatalogueStep> steps;
  final int current;

  const _WalkBody({
    required this.controller,
    required this.steps,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final passed = [
      for (int index = 0; index < current && index < steps.length; index += 1)
        ...steps[index].requests,
    ];
    final next = _findNextRequest();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AutomationPanelTheme.gapSmall,
      children: [
        for (final request in passed.reversed.take(2).toList().reversed)
          AutomationRequestRow(
            method: request.method,
            path: request.path,
            statusCode: request.statusCode,
          ),
        if (next != null) _NextResponse(controller: controller, next: next),
        AutomationPanelButtonGroup(
          buttons: [
            AutomationPanelButton(
              label: 'Start over',
              onPressed: () => controller.moveWalk(0),
            ),
            AutomationPanelButton(
              label: 'Finish',
              onPressed: controller.finishWalk,
            ),
          ],
        ),
      ],
    );
  }

  AutomationCatalogueRequest? _findNextRequest() {
    for (int index = current; index < steps.length; index += 1) {
      if (steps[index].requests.isNotEmpty) {
        return steps[index].requests.first;
      }
    }

    return null;
  }
}

class _NextResponse extends StatelessWidget {
  final AutomationPanelController controller;
  final AutomationCatalogueRequest next;

  const _NextResponse({required this.controller, required this.next});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AutomationPanelTheme.gapSmall,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: AutomationPanelLabel(
            text: 'Next response',
            detail: '${next.method} ${next.path}',
          ),
        ),
        AutomationPanelChips<_NextAnswer>(
          options: const [
            AutomationPanelOption(
              value: _NextAnswer.mock,
              label: 'Mock response',
            ),
            AutomationPanelOption(value: _NextAnswer.error, label: '500'),
            AutomationPanelOption(
              value: _NextAnswer.noNetwork,
              label: 'No network',
            ),
          ],
          selected: _describeAnswer(controller.failureOf(next.path)),
          selectedColor: theme.danger,
          onChanged: _setAnswer,
        ),
      ],
    );
  }

  _NextAnswer? _describeAnswer(MockApiFailure? failure) {
    if (failure == null) {
      return null;
    }

    return failure.isConnectionError
        ? _NextAnswer.noNetwork
        : _NextAnswer.error;
  }

  void _setAnswer(_NextAnswer answer) {
    final failure = switch (answer) {
      _NextAnswer.mock => null,
      _NextAnswer.error => const MockApiFailure(),
      _NextAnswer.noNetwork => const MockApiFailure(isConnectionError: true),
    };

    controller.setFailure(next.path, failure);
  }
}

enum _NextAnswer { mock, error, noNetwork }
