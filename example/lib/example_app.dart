import 'package:flutter/material.dart';

import 'package:example/automation/screen_name_observer.dart';
import 'package:example/catalog/catalog_api.dart';
import 'package:example/catalog/catalog_screen.dart';
import 'package:example/login_screen.dart';

/// Root widget: the login screen, then the catalog.
class ExampleApp extends StatelessWidget {
  final CatalogApi catalogApi;
  final ScreenNameObserver screenNameObserver;

  const ExampleApp({
    super.key,
    required this.catalogApi,
    required this.screenNameObserver,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Example',
      navigatorObservers: [screenNameObserver],
      initialRoute: LoginScreen.routeName,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => _buildScreen(context, settings.name),
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
    );
  }
}
