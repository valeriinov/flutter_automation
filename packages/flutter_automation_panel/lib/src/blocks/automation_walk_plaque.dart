import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_count.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The plaque that leads a walk of a flow. It is one line when collapsed. A
/// tap opens its [child]. The tester drags the plaque down to see what it
/// covers, and taps the stop icon to exit the walk.
///
/// The plaque does not move itself. The owner moves it in [onDragged], so the
/// area that takes the finger moves with the plaque.
class AutomationWalkPlaque extends StatelessWidget {
  static const _shadowBlur = 24.0;

  /// The line of the collapsed plaque, such as the flow and the step.
  final String title;

  /// How many overrides the walk holds.
  final int overrideCount;

  /// Whether the plaque shows [child].
  final bool isExpanded;

  /// Called when the tester taps the line.
  final VoidCallback onToggle;

  /// Called when the tester taps the stop icon.
  final VoidCallback onExit;

  /// Content of the expanded plaque.
  final Widget child;

  /// Called with the vertical move, in pixels, while the tester drags the
  /// plaque. A drag does nothing when it is missing.
  final ValueChanged<double>? onDragged;

  const AutomationWalkPlaque({
    required this.title,
    required this.overrideCount,
    required this.isExpanded,
    required this.onToggle,
    required this.onExit,
    required this.child,
    this.onDragged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final radius = BorderRadius.circular(
      isExpanded ? AutomationPanelTheme.cardRadius : 999,
    );

    return GestureDetector(
      onVerticalDragUpdate: (details) => onDragged?.call(details.delta.dy),
      child: DecoratedBox(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Line(
                title: title,
                overrideCount: overrideCount,
                isExpanded: isExpanded,
                onToggle: onToggle,
                onExit: onExit,
              ),
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AutomationPanelTheme.gapMedium,
                    0,
                    AutomationPanelTheme.gapMedium,
                    AutomationPanelTheme.gapMedium,
                  ),
                  child: child,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  static const _exitDiameter = 24.0;

  final String title;
  final int overrideCount;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onExit;

  const _Line({
    required this.title,
    required this.overrideCount,
    required this.isExpanded,
    required this.onToggle,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AutomationPanelTheme.touchTarget,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onToggle,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
                child: Row(
                  spacing: AutomationPanelTheme.gapSmall,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.accent,
                      ),
                      child: const SizedBox.square(dimension: 8),
                    ),
                    Expanded(child: _Title(title, overrideCount)),
                  ],
                ),
              ),
            ),
          ),
          InkWell(
            onTap: onExit,
            borderRadius: BorderRadius.circular(AutomationPanelTheme.gapSmall),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.danger,
                    ),
                    child: SizedBox.square(
                      dimension: _exitDiameter,
                      child: Icon(Icons.stop, size: 16, color: theme.surface),
                    ),
                  ),
                  Text(
                    'Exit',
                    style: theme.textStyle(
                      size: 10,
                      weight: FontWeight.w600,
                      color: theme.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onToggle,
            child: SizedBox.square(
              dimension: AutomationPanelTheme.touchTarget,
              child: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: theme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String title;
  final int overrideCount;

  const _Title(this.title, this.overrideCount);

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Text.rich(
      TextSpan(
        text: title,
        children: [
          if (overrideCount > 0)
            TextSpan(
              text: ' · ${_describeCount()}',
              style: TextStyle(
                color: theme.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      style: theme.textStyle(size: 13),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _describeCount() {
    return describeOverrideCount(overrideCount).replaceAll(' ', '\u00A0');
  }
}
