import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_count.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The plaque that follows a manual walk of a flow. It is one line when
/// collapsed. A tap opens its [child]. A swipe up calls [onHide], so the plaque
/// does not cover a screen recording.
class AutomationWalkPlaque extends StatelessWidget {
  static const _shadowBlur = 24.0;
  static const _swipeVelocity = 200.0;

  /// The line of the collapsed plaque, such as the flow and the step.
  final String title;

  /// How many overrides the walk holds.
  final int overrideCount;

  /// Whether the plaque shows [child].
  final bool isExpanded;

  /// Called when the tester taps the line.
  final VoidCallback onToggle;

  /// Called when the tester swipes the plaque up.
  final VoidCallback onHide;

  /// Content of the expanded plaque.
  final Widget child;

  const AutomationWalkPlaque({
    required this.title,
    required this.overrideCount,
    required this.isExpanded,
    required this.onToggle,
    required this.onHide,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final radius = BorderRadius.circular(
      isExpanded ? AutomationPanelTheme.cardRadius : 999,
    );

    return GestureDetector(
      onVerticalDragEnd: _handleSwipe,
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

  void _handleSwipe(DragEndDetails details) {
    if (details.velocity.pixelsPerSecond.dy < -_swipeVelocity) {
      onHide();
    }
  }
}

class _Line extends StatelessWidget {
  final String title;
  final int overrideCount;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _Line({
    required this.title,
    required this.overrideCount,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(999),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AutomationPanelTheme.touchTarget,
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 14, right: 4),
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
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: title,
                    children: [
                      if (overrideCount > 0)
                        TextSpan(
                          text: ' · ${describeOverrideCount(overrideCount)}',
                          style: TextStyle(
                            color: theme.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  style: theme.textStyle(size: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox.square(
                dimension: AutomationPanelTheme.touchTarget,
                child: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
