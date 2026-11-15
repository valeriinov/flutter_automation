import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// One step of a flow: a numbered circle on a rail and a card with the title
/// and the requests of the step. A step that forks the flow fills its circle
/// with the accent.
class AutomationFlowStep extends StatelessWidget {
  static const _circleSize = 28.0;
  static const _railLineWidth = 2.0;

  /// Number of the step in its flow.
  final int number;

  /// Title of the step.
  final String title;

  /// Whether the flow forks in this step.
  final bool isFork;

  /// Whether the rail ends with this step.
  final bool isLast;

  /// Whether the circle shows the step the walk stands on.
  final bool isCurrent;

  /// Requests, choices and overrides of the step.
  final List<Widget> children;

  const AutomationFlowStep({
    required this.number,
    required this.title,
    this.isFork = false,
    this.isLast = false,
    this.isCurrent = false,
    this.children = const [],
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AutomationPanelTheme.gapMedium,
        children: [
          _Rail(number: number, isFilled: isFork || isCurrent, isLast: isLast),
          Expanded(
            child: _Card(title: title, children: children),
          ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  final int number;
  final bool isFilled;
  final bool isLast;

  const _Rail({
    required this.number,
    required this.isFilled,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return SizedBox(
      width: AutomationFlowStep._circleSize,
      child: Column(
        children: [
          Container(
            width: AutomationFlowStep._circleSize,
            height: AutomationFlowStep._circleSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? theme.accent : theme.surface,
              border: Border.all(
                color: isFilled ? theme.accent : theme.lineStrong,
                width: 1.5,
              ),
            ),
            child: Text(
              '$number',
              style: theme.textStyle(
                size: 13,
                weight: FontWeight.w600,
                color: isFilled ? theme.surface : theme.text,
              ),
            ),
          ),
          if (!isLast)
            Expanded(
              child: Container(
                width: AutomationFlowStep._railLineWidth,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: theme.lineStrong,
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AutomationPanelTheme.gapSmall),
      padding: const EdgeInsets.all(AutomationPanelTheme.gapMedium),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(AutomationPanelTheme.cardRadius),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AutomationPanelTheme.gapSmall,
        children: [
          Text(
            title,
            style: theme.textStyle(size: 15, weight: FontWeight.w600),
          ),
          ...children,
        ],
      ),
    );
  }
}
