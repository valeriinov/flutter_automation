import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_scope.dart';
import 'package:flutter_automation_panel/src/panel/automation_run_summary.dart';
import 'package:flutter_automation_panel/src/panel/automation_walk_strip.dart';
import 'package:flutter_automation_panel/src/player/automation_flow_player.dart';
import 'package:flutter_automation_panel/src/player/automation_input_gate.dart';
import 'package:flutter_automation_panel/src/player/automation_touch_indicator.dart';
import 'package:flutter_automation_panel/src/sheets/automation_run_done_sheet.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// The QA button over the app and the panel it opens.
///
/// The launcher stands above the screens of the app, usually in the `builder`
/// of the `MaterialApp`. It brings its own [Navigator] and its own theme, so it
/// needs nothing from the app but a [Directionality], a [MediaQuery] and
/// [MaterialLocalizations]. The tester drags the button.
///
/// While a walk runs, an [AutomationInputGate] covers the app, its dialogs and
/// its sheets, so only the player touches the screen. The walk plaque and the
/// button stay under the finger. An autorun shows the touch circle only while
/// it plays its steps. A failure brings the plaque back.
///
/// While the panel is open, the system back button goes to the panel, never to
/// the app under it. While a walk runs, the button does nothing. The
/// [AutomationPanelController] handles that button. The launcher then reports
/// a [NavigationNotification] that can pop, so Android sends the button to the
/// framework also on the first screen of the app.
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
  final _outerKey = GlobalKey();
  Offset? _position;
  bool _canAppPop = false;
  bool _holdsBack = false;

  @override
  void initState() {
    super.initState();

    widget.controller.isLauncherVisible = widget.isVisible;

    widget.controller.addListener(_maybeReportBack);
    _maybeReportBack();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.resumeWalk();
    });
  }

  @override
  void didUpdateWidget(AutomationPanelLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.isLauncherVisible = false;

      oldWidget.controller.removeListener(_maybeReportBack);
      widget.controller.addListener(_maybeReportBack);
    }

    widget.controller.isLauncherVisible = widget.isVisible;

    _maybeReportBack();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _outerKey,
      child: NotificationListener<NavigationNotification>(
        onNotification: _onAppNavigation,
        child: _buildLayers(),
      ),
    );
  }

  Widget _buildLayers() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final theme = controller.definition.theme;
        final size = MediaQuery.sizeOf(context);
        final padding = MediaQuery.paddingOf(context);

        return Stack(
          children: [
            Positioned.fill(
              child: AutomationInputGate(
                isBlocked: () => _isFingerBlocked(controller),
                child: widget.child,
              ),
            ),
            if (widget.isVisible && _shouldShowTouches(controller))
              Positioned.fill(
                child: AutomationTouchIndicator(
                  player: controller.player,
                  theme: theme,
                ),
              ),
            if (widget.isVisible && !controller.isPanelOpen) ...[
              if (!controller.isAutorunPlaying)
                _WalkStripLayer(controller: controller),
              if (!controller.isAutorunPlaying)
                _QaButton(
                  player: controller.player,
                  position: _position ?? _resolveStartPosition(size, padding),
                  theme: theme,
                  wrapButton: widget.wrapButton,
                  onPressed: controller.openPanel,
                  onDragged: (delta) => _drag(delta, size, padding),
                ),
            ],
            if (widget.isVisible && controller.isPanelOpen)
              Positioned.fill(child: _PanelLayer(controller: controller)),
            if (widget.isVisible && controller.runSummary != null)
              Positioned.fill(child: _RunDoneLayer(controller: controller)),
          ],
        );
      },
    );
  }

  bool _onAppNavigation(NavigationNotification notification) {
    _canAppPop = notification.canHandlePop;

    return _holdsBack;
  }

  bool _isFingerBlocked(AutomationPanelController controller) {
    return controller.isInputBlocked && !controller.player.isInjecting;
  }

  bool _shouldShowTouches(AutomationPanelController controller) {
    return controller.isWalkActive &&
        (controller.walk?.shouldShowTouches ?? false);
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

  void _maybeReportBack() {
    final controller = widget.controller;
    final holdsBack = controller.isInputBlocked || controller.isPanelOpen;

    if (holdsBack == _holdsBack) {
      return;
    }

    _holdsBack = holdsBack;

    WidgetsBinding.instance.addPostFrameCallback((_) => _reportBack());
  }

  void _reportBack() {
    final outerContext = _outerKey.currentContext;

    if (outerContext == null) {
      return;
    }

    NavigationNotification(
      canHandlePop: _holdsBack || _canAppPop,
    ).dispatch(outerContext);
  }

  @override
  void dispose() {
    widget.controller.isLauncherVisible = false;

    widget.controller.removeListener(_maybeReportBack);
    super.dispose();
  }
}

class _WalkStripLayer extends StatefulWidget {
  static const _edgeGap = 12.0;
  static const _reservedBottom = 160.0;
  static const _minHeight = 160.0;

  final AutomationPanelController controller;

  const _WalkStripLayer({required this.controller});

  @override
  State<_WalkStripLayer> createState() => _WalkStripLayerState();
}

class _WalkStripLayerState extends State<_WalkStripLayer> {
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final top = padding.top + _WalkStripLayer._edgeGap + _dragOffset;
    final maxHeight =
        MediaQuery.sizeOf(context).height -
        top -
        padding.bottom -
        _WalkStripLayer._edgeGap;

    return Positioned(
      left: _WalkStripLayer._edgeGap,
      right: _WalkStripLayer._edgeGap,
      top: top,
      child: AutomationInputPassThrough(
        isPassing: () => widget.controller.player.isInjecting,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: max(_WalkStripLayer._minHeight, maxHeight),
          ),
          child: Theme(
            data: widget.controller.definition.theme.toThemeData(),
            child: Material(
              type: MaterialType.transparency,
              child: AutomationWalkStrip(
                controller: widget.controller,
                onDragged: _drag,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _drag(double delta) {
    final maxOffset =
        MediaQuery.sizeOf(context).height - _WalkStripLayer._reservedBottom;

    setState(() {
      _dragOffset = (_dragOffset + delta).clamp(0, maxOffset);
    });
  }
}

class _QaButton extends StatelessWidget {
  final AutomationFlowPlayer player;
  final Offset position;
  final AutomationPanelTheme theme;
  final Widget Function(Widget button)? wrapButton;
  final VoidCallback onPressed;
  final ValueChanged<Offset> onDragged;

  const _QaButton({
    required this.player,
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
          AutomationPanelStrings.qaBadge,
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
      child: AutomationInputPassThrough(
        isPassing: () => player.isInjecting,
        child: wrap == null ? button : wrap(button),
      ),
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

class _RunDoneLayer extends StatelessWidget {
  final AutomationPanelController controller;

  const _RunDoneLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = controller.definition.theme;
    final summary = controller.runSummary;

    if (summary == null) {
      return const SizedBox.shrink();
    }

    return Theme(
      data: theme.toThemeData(),
      child: Material(
        color: theme.scrim,
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AutomationRunDoneSheet(
              outcome: summary.outcome,
              stepCount: summary.stepCount,
              duration: summary.duration,
              requests: summary.requests,
              onShare: _resolveShare(summary),
              onRunAgain: () => controller.startWalk(
                summary.flow,
                summary.variant,
                mode: summary.mode,
                shouldShowTouches: summary.shouldShowTouches,
                shouldSignalEnd: summary.shouldSignalEnd,
              ),
              onExit: controller.exitWalk,
            ),
          ),
        ),
      ),
    );
  }

  VoidCallback? _resolveShare(AutomationRunSummary summary) {
    final share = controller.definition.onShare;
    final report = summary.report;

    if (share == null || report == null) {
      return null;
    }

    return () => share(report);
  }
}
