import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/player/automation_flow_player.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The circle that shows where the player taps. It lets every touch through.
class AutomationTouchIndicator extends StatelessWidget {
  static const _size = 44.0;
  static const _borderWidth = 2.0;
  static const _fillAlpha = 0.35;

  /// The player whose touch the circle follows.
  final AutomationFlowPlayer player;

  /// Look of the circle.
  final AutomationPanelTheme theme;

  const AutomationTouchIndicator({
    required this.player,
    required this.theme,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<Offset?>(
        valueListenable: player.touch,
        builder: (context, touch, _) {
          if (touch == null) {
            return const SizedBox.expand();
          }

          return Stack(
            children: [
              Positioned(
                left: touch.dx - _size / 2,
                top: touch.dy - _size / 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.accent.withValues(alpha: _fillAlpha),
                    border: Border.all(
                      color: theme.accent,
                      width: _borderWidth,
                    ),
                  ),
                  child: const SizedBox.square(dimension: _size),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
