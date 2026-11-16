import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The plaque that leads a walk of a flow.
///
/// Collapsed, it is one line: a cross that exits the walk, the flow and the
/// step, and a round button that does the next step. A tap on the line opens
/// the plaque. Open, it shows the collapse button in its head, the [child]
/// under it and the Exit and Next step buttons pinned at the bottom. The
/// [child] scrolls when it does not fit.
///
/// The plaque does not move itself. The owner moves it in [onDragged], so the
/// area that takes the finger moves with the plaque. Only the head takes the
/// drag; a vertical drag in the [child] scrolls the [child]. The plaque shows
/// no tooltip, because it stands above the [Overlay] of the app.
class AutomationWalkPlaque extends StatelessWidget {
  static const _shadowBlur = 24.0;
  static const _collapsedRadius = 24.0;
  static const _motion = Duration(milliseconds: 220);

  /// Title of the flow.
  final String flowTitle;

  /// The step on the collapsed line, such as `3/10`.
  final String collapsedStep;

  /// The step in the head of the open plaque, such as `step 3 of 10`.
  final String expandedStep;

  /// How many overrides the walk holds.
  final int overrideCount;

  /// Whether the plaque is open.
  final bool isExpanded;

  /// Text of the main button of the open plaque.
  final String nextLabel;

  /// Whether the main button ends the walk. It then shows a check mark before
  /// its label, not an arrow after it.
  final bool isFinishing;

  /// Called when the tester taps the line or the collapse button.
  final VoidCallback onToggle;

  /// Called when the tester taps the cross or Exit.
  final VoidCallback onExit;

  /// Called when the tester taps the round button or the main button, `null`
  /// while the buttons are disabled.
  final VoidCallback? onNext;

  /// Content of the open plaque, above the pinned buttons.
  final Widget child;

  /// Called with the vertical move, in pixels, while the tester drags the
  /// head. A drag does nothing when it is missing.
  final ValueChanged<double>? onDragged;

  const AutomationWalkPlaque({
    required this.flowTitle,
    required this.collapsedStep,
    required this.expandedStep,
    required this.overrideCount,
    required this.isExpanded,
    required this.nextLabel,
    required this.onToggle,
    required this.onExit,
    required this.onNext,
    required this.child,
    this.isFinishing = false,
    this.onDragged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: isExpanded ? 1 : 0),
      duration: _motion,
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        final radius = BorderRadius.circular(
          lerpDouble(
                _collapsedRadius,
                AutomationPanelTheme.cardRadius,
                progress,
              ) ??
              AutomationPanelTheme.cardRadius,
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: theme.text.withValues(alpha: 0.18),
                blurRadius: _shadowBlur,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: theme.surface,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onVerticalDragUpdate: (details) {
                    onDragged?.call(details.delta.dy);
                  },
                  child: isExpanded
                      ? _Head(
                          flowTitle: flowTitle,
                          step: expandedStep,
                          onToggle: onToggle,
                        )
                      : _Line(
                          flowTitle: flowTitle,
                          step: collapsedStep,
                          overrideCount: overrideCount,
                          onToggle: onToggle,
                          onExit: onExit,
                          onNext: onNext,
                        ),
                ),
                if (progress > 0)
                  Flexible(
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: progress,
                        child: _Body(
                          nextLabel: nextLabel,
                          isFinishing: isFinishing,
                          onExit: onExit,
                          onNext: onNext,
                          child: child,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  static const _nextDiameter = 40.0;

  final String flowTitle;
  final String step;
  final int overrideCount;
  final VoidCallback onToggle;
  final VoidCallback onExit;
  final VoidCallback? onNext;

  const _Line({
    required this.flowTitle,
    required this.step,
    required this.overrideCount,
    required this.onToggle,
    required this.onExit,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return SizedBox(
      height: AutomationPanelTheme.buttonHeight,
      child: Row(
        children: [
          IconButton(
            onPressed: onExit,
            icon: const Icon(Icons.close, size: 20),
          ),
          Expanded(
            child: InkWell(
              onTap: onToggle,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Title(
                  flowTitle: flowTitle,
                  step: step,
                  overrideCount: overrideCount,
                ),
              ),
            ),
          ),
          SizedBox.square(
            dimension: AutomationPanelTheme.touchTarget,
            child: Center(
              child: IconButton.filled(
                onPressed: onNext,
                constraints: const BoxConstraints.tightFor(
                  width: _nextDiameter,
                  height: _nextDiameter,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: theme.surface,
                ),
                icon: const Icon(Icons.chevron_right, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  static const _height = 52.0;

  final String flowTitle;
  final String step;
  final VoidCallback onToggle;

  const _Head({
    required this.flowTitle,
    required this.step,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.line)),
      ),
      child: SizedBox(
        height: _height,
        child: Row(
          children: [
            const SizedBox(width: 14),
            Expanded(
              child: InkWell(
                onTap: onToggle,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _Title(
                    flowTitle: flowTitle,
                    step: step,
                    overrideCount: 0,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onToggle,
              icon: const Icon(Icons.expand_less),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String flowTitle;
  final String step;
  final int overrideCount;

  const _Title({
    required this.flowTitle,
    required this.step,
    required this.overrideCount,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);

    return Row(
      spacing: AutomationPanelTheme.gapSmall,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.accent,
          ),
          child: const SizedBox.square(dimension: 8),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: flowTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: ' · $step'),
                if (overrideCount > 0)
                  TextSpan(
                    text: ' · ${strings.overrideCount(overrideCount)}',
                    style: TextStyle(
                      color: theme.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            style: theme.textStyle(size: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final String nextLabel;
  final bool isFinishing;
  final VoidCallback onExit;
  final VoidCallback? onNext;
  final Widget child;

  const _Body({
    required this.nextLabel,
    required this.isFinishing,
    required this.onExit,
    required this.onNext,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(AutomationPanelTheme.gapMedium),
            child: child,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.line)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AutomationPanelTheme.gapMedium,
              10,
              AutomationPanelTheme.gapMedium,
              AutomationPanelTheme.gapMedium,
            ),
            child: Row(
              spacing: AutomationPanelTheme.gapSmall,
              children: [
                AutomationPanelButton(
                  label: strings.exit,
                  leadingIcon: Icons.close,
                  onPressed: onExit,
                ),
                Expanded(
                  child: AutomationPanelButton(
                    label: nextLabel,
                    kind: AutomationPanelButtonKind.primary,
                    leadingIcon: isFinishing ? Icons.check : null,
                    trailingIcon: isFinishing ? null : Icons.chevron_right,
                    onPressed: onNext,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
