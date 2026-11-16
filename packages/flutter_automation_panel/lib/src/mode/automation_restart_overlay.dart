import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The screen that asks the tester to close and open the app, drawn over the
/// app while [isRestartRequired] is true.
///
/// The screen has no button: only the tester restarts the app.
/// It works in both modes of the app.
/// It needs no `AutomationPanelController`, so a switch of the mode by an
/// `AutomationModeController` shows it too.
/// The overlay stands above the app, usually in the `builder` of the
/// `MaterialApp` and around an `AutomationPanelLauncher`.
class AutomationRestartOverlay extends StatelessWidget {
  /// Whether the screen shows.
  final ValueListenable<bool> isRestartRequired;

  /// Look of the screen.
  final AutomationPanelTheme theme;

  /// The texts of the screen, the strings of the nearest panel when missing.
  final AutomationPanelStrings? strings;

  /// The app under the screen.
  final Widget child;

  const AutomationRestartOverlay({
    required this.isRestartRequired,
    required this.child,
    this.theme = const AutomationPanelTheme.light(),
    this.strings,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final strings = this.strings ?? AutomationPanelStrings.of(context);

    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned.fill(
          child: ValueListenableBuilder<bool>(
            valueListenable: isRestartRequired,
            builder: (context, isRequired, _) {
              if (!isRequired) {
                return const SizedBox.shrink();
              }

              return _RestartScreen(theme: theme, strings: strings);
            },
          ),
        ),
      ],
    );
  }
}

class _RestartScreen extends StatelessWidget {
  final AutomationPanelTheme theme;
  final AutomationPanelStrings strings;

  const _RestartScreen({required this.theme, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme.toThemeData(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Material(
          color: theme.background,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AutomationPanelTheme.gapLarge),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: AutomationPanelTheme.gapMedium,
                children: [
                  Icon(Icons.refresh, size: 48, color: theme.restart),
                  Text(
                    strings.restartScreenTitle,
                    textAlign: TextAlign.center,
                    style: theme.textStyle(size: 22, weight: FontWeight.w700),
                  ),
                  Text(
                    strings.restartScreenNote,
                    textAlign: TextAlign.center,
                    style: theme.textStyle(
                      size: 15,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
