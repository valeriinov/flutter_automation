import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_scope.dart';
import 'package:flutter_automation_panel/src/panel/automation_walk_strip.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The QA button over the app and the panel it opens.
///
/// The launcher stands above the screens of the app, usually in the `builder`
/// of the `MaterialApp`. It brings its own [Navigator] and its own theme, so it
/// needs nothing from the app but a [Directionality], a [MediaQuery] and
/// [MaterialLocalizations]. The tester drags the button. While a manual walk
/// runs, the walk strip stands above the app.
///
/// While the panel is open, the system back button goes to the panel, never to
/// the app under it. The [AutomationPanelController] handles that button.
class AutomationPanelLauncher extends StatefulWidget {
  static const _buttonSize = 48.0;
  static const _edgeGap = 16.0;
  static const _bottomGap = 96.0;

  /// The controller of the panel.
  final AutomationPanelController controller;

  /// Whether the button and the walk strip show. The project ties it to its own
  /// switch for debug tools.
  final bool isVisible;

  /// The app under the button.
  final Widget child;

  /// Wraps the button, for the project to mark it for automation. The panel and
  /// the rest of the launcher stay unmarked.
  final Widget Function(Widget button)? wrapButton;

  /// The top left corner of the button before the tester drags it. The default
  /// stands at the bottom right, above the home indicator.
  final Offset Function(Size size, EdgeInsets padding)? startPosition;

  const AutomationPanelLauncher({
    required this.controller,
    required this.isVisible,
    required this.child,
    this.wrapButton,
    this.startPosition,
    super.key,
  });

  @override
  State<AutomationPanelLauncher> createState() =>
      _AutomationPanelLauncherState();
}

class _AutomationPanelLauncherState extends State<AutomationPanelLauncher> {
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final theme = controller.definition.theme;
        final size = MediaQuery.sizeOf(context);
        final padding = MediaQuery.paddingOf(context);

        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (widget.isVisible && !controller.isPanelOpen) ...[
              _WalkStripLayer(controller: controller),
              _QaButton(
                position: _position ?? _resolveStartPosition(size, padding),
                theme: theme,
                wrapButton: widget.wrapButton,
                onPressed: controller.openPanel,
                onDragged: (delta) => _drag(delta, size, padding),
              ),
            ],
            if (widget.isVisible && controller.isPanelOpen)
              Positioned.fill(child: _PanelLayer(controller: controller)),
          ],
        );
      },
    );
  }

  void _drag(Offset delta, Size size, EdgeInsets padding) {
    final current = _position ?? _resolveStartPosition(size, padding);
    final next = current + delta;
    final maxX =
        size.width - padding.right - AutomationPanelLauncher._buttonSize;
    final maxY =
        size.height - padding.bottom - AutomationPanelLauncher._buttonSize;

    setState(() {
      _position = Offset(
        next.dx.clamp(padding.left, maxX),
        next.dy.clamp(padding.top, maxY),
      );
    });
  }

  Offset _resolveStartPosition(Size size, EdgeInsets padding) {
    final custom = widget.startPosition;

    if (custom != null) {
      return custom(size, padding);
    }

    return Offset(
      size.width -
          AutomationPanelLauncher._buttonSize -
          AutomationPanelLauncher._edgeGap,
      size.height - padding.bottom - AutomationPanelLauncher._bottomGap,
    );
  }
}

class _WalkStripLayer extends StatelessWidget {
  final AutomationPanelController controller;

  const _WalkStripLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Positioned(
      left: 12,
      right: 12,
      top: top + 12,
      child: Theme(
        data: controller.definition.theme.toThemeData(),
        child: Material(
          type: MaterialType.transparency,
          child: AutomationWalkStrip(controller: controller),
        ),
      ),
    );
  }
}

class _QaButton extends StatelessWidget {
  final Offset position;
  final AutomationPanelTheme theme;
  final Widget Function(Widget button)? wrapButton;
  final VoidCallback onPressed;
  final ValueChanged<Offset> onDragged;

  const _QaButton({
    required this.position,
    required this.theme,
    required this.wrapButton,
    required this.onPressed,
    required this.onDragged,
  });

  @override
  Widget build(BuildContext context) {
    final wrap = wrapButton;
    final button = GestureDetector(
      onTap: onPressed,
      onPanUpdate: (details) => onDragged(details.delta),
      child: Container(
        width: AutomationPanelLauncher._buttonSize,
        height: AutomationPanelLauncher._buttonSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.accent,
          boxShadow: [
            BoxShadow(
              color: theme.text.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          'QA',
          style: theme.textStyle(
            size: 14,
            weight: FontWeight.w700,
            color: theme.surface,
          ),
        ),
      ),
    );

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: wrap == null ? button : wrap(button),
    );
  }
}

class _PanelLayer extends StatelessWidget {
  final AutomationPanelController controller;

  const _PanelLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = controller.definition.theme;

    return Theme(
      data: theme.toThemeData(),
      child: AutomationPanelScope(
        controller: controller,
        child: Material(
          color: theme.background,
          child: HeroControllerScope.none(
            child: Navigator(
              key: controller.navigatorKey,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const AutomationPanel(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
