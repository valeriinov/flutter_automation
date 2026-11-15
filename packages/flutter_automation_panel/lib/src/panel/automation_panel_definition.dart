import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_page.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Utils}
///
/// Callback that starts a flow variant in the app.
typedef AutomationFlowStarter =
    FutureOr<void> Function(String flow, String variant);

/// {@category Utils}
///
/// What a project hands to the panel: the mock, the catalogue of flows, the
/// pages and the callbacks that only the project can do.
///
/// A project builds its panel from pages, the way it builds its flows from
/// blocks. The panel adds no page of its own.
@immutable
final class AutomationPanelDefinition {
  /// The mock the panel changes.
  final AutomationMock mock;

  /// The flows a tester can walk.
  final AutomationCatalogue catalogue;

  /// Pages in tab order.
  final List<AutomationPanelPage> pages;

  /// Backend error codes the response sheet offers as chips.
  final List<String> backendErrorCodes;

  /// Look of the panel.
  final AutomationPanelTheme theme;

  /// Called when a change needs a restart of the app. The project shows its
  /// restart screen.
  final FutureOr<void> Function() onRestartRequired;

  /// Called when the tester starts a flow. The project opens the first screen
  /// of the flow. The panel is already closed.
  final AutomationFlowStarter? onStart;

  const AutomationPanelDefinition({
    required this.mock,
    required this.catalogue,
    required this.pages,
    required this.onRestartRequired,
    this.backendErrorCodes = const [],
    this.theme = const AutomationPanelTheme.light(),
    this.onStart,
  });
}
