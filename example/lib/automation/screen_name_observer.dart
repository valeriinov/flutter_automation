import 'package:flutter/widgets.dart';

/// Keeps the name of the route on top, for the `screen.read` command.
final class ScreenNameObserver extends NavigatorObserver {
  /// Name of the route on top, null before the first route.
  String? screenName;

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    screenName = route.settings.name;
  }

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) {
    screenName = previousRoute?.settings.name;
  }
}
