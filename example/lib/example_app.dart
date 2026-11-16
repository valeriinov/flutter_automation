import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';

import 'package:example/automation/screen_name_observer.dart';
import 'package:example/catalog/catalog_api.dart';
import 'package:example/catalog/catalog_screen.dart';
import 'package:example/login_screen.dart';

/// Root widget: the login screen, then the catalog.
class ExampleApp extends StatelessWidget {
  final CatalogApi catalogApi;
  final ScreenNameObserver screenNameObserver;
  final ValueListenable<Locale> locale;

  /// The restart screen shows while this flag is true.
  final ValueListenable<bool> isRestartRequired;

  /// Switches the mode of the app. It is null in a build that cannot switch.
  final AutomationModeController? modeController;

  /// The controller of the QA panel, missing when the app runs without the
  /// mock.
  final AutomationPanelController? panelController;

  const ExampleApp({
    super.key,
    required this.catalogApi,
    required this.screenNameObserver,
    required this.locale,
    required this.isRestartRequired,
    this.modeController,
    this.panelController,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: locale,
      builder: (context, value, _) => MaterialApp(
        title: 'Example',
        locale: value,
        navigatorObservers: [screenNameObserver],
        builder: _buildLauncher,
        initialRoute: LoginScreen.routeName,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _buildScreen(context, settings.name),
        ),
      ),
    );
  }

  Widget _buildLauncher(BuildContext context, Widget? child) {
    final controller = panelController;
    final app = child ?? const SizedBox.shrink();

    return AutomationRestartOverlay(
      isRestartRequired: isRestartRequired,
      child: controller == null
          ? app
          : AutomationPanelLauncher(
              controller: controller,
              isVisible: true,
              child: app,
            ),
    );
  }

  Widget _buildScreen(BuildContext context, String? routeName) {
    if (routeName == CatalogScreen.routeName) {
      return CatalogScreen(catalogApi: catalogApi);
    }

    return LoginScreen(
      onSignInPressed: () =>
          Navigator.of(context).pushNamed(CatalogScreen.routeName),
      onMockModePressed: _resolveMockModeAction(context),
    );
  }

  VoidCallback? _resolveMockModeAction(BuildContext context) {
    final controller = modeController;

    if (controller == null) {
      return null;
    }

    return () =>
        showAutomationMockModeSheet(context: context, controller: controller);
  }
}
