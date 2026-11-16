import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_page.dart';
import 'package:flutter_automation_panel/src/player/automation_player_settings.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Utils}
///
/// What a project hands to the panel: the mock, the catalogue of flows, the
/// pages and the callbacks that only the project can do. The panel calls
/// `onRestartRequired` once at each start of a walk, so the project shows its
/// restart screen.
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

  /// Called when a change needs a restart of the app, and once at each start
  /// of a walk. The project shows its restart screen.
  final FutureOr<void> Function() onRestartRequired;

  /// Called with the `report.json` file of a run when the tester taps Share
  /// logs at the end of a run. The project shares the file. The summary hides
  /// the button when it is missing.
  final FutureOr<void> Function(File report)? onShare;

  /// What the player reads a step with, and how fast it moves.
  final AutomationPlayerSettings playerSettings;

  const AutomationPanelDefinition({
    required this.mock,
    required this.catalogue,
    required this.pages,
    required this.onRestartRequired,
    this.backendErrorCodes = const [],
    this.theme = const AutomationPanelTheme.light(),
    this.onShare,
    this.playerSettings = const AutomationPlayerSettings(),
  });
}
