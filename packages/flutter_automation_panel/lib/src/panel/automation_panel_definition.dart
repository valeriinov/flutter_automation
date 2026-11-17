import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/src/pages/automation_autorun_page.dart';
import 'package:flutter_automation_panel/src/pages/automation_flows_page.dart';
import 'package:flutter_automation_panel/src/pages/automation_journal_page.dart';
import 'package:flutter_automation_panel/src/pages/automation_section_panel.dart';
import 'package:flutter_automation_panel/src/pages/automation_sections_page.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_page.dart';
import 'package:flutter_automation_panel/src/player/automation_player_settings.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Utils}
///
/// What a project hands to the panel: the mock, the catalogue of flows, the
/// pages and the callbacks that only the project can do. The panel sets
/// `isRestartRequired` to true at each start of a walk and at each change that
/// needs a restart. An `AutomationRestartOverlay` shows the restart screen.
///
/// A project builds its panel from pages, the way it builds its flows from
/// blocks. [AutomationPanelDefinition.standard] builds the usual four pages:
/// Flows, Autorun, Sections and Log.
@immutable
final class AutomationPanelDefinition {
  /// The mock the panel changes.
  final AutomationMock mock;

  /// The flows a tester can walk.
  final AutomationCatalogue catalogue;

  /// Pages in tab order.
  final List<AutomationPanelPage> pages;

  /// Backend error codes that every request can answer with. The response
  /// sheet offers them as chips, after them the codes of the endpoint of the
  /// request.
  final List<String> backendErrorCodes;

  /// Look of the panel.
  final AutomationPanelTheme theme;

  /// Every text of the panel. Its language code selects the texts of the
  /// sections, the profiles and the catalogue. English by default.
  final AutomationPanelStrings strings;

  /// The panel sets it to true when a change needs a restart of the app, and
  /// at each start of a walk. An `AutomationRestartOverlay` shows the restart
  /// screen.
  final ValueNotifier<bool> isRestartRequired;

  /// Called when the tester taps Share logs at the end of a run. It gets the
  /// context of the end-of-run layer and the `report.json` file of the run.
  /// The project shares the file. The summary hides the button when it is
  /// missing.
  final FutureOr<void> Function(BuildContext context, File report)? onShare;

  /// What the player reads a step with, and how fast it moves.
  final AutomationPlayerSettings playerSettings;

  /// The sections of the mock, as the Sections page lists them. The Changes
  /// page names the profile of each one that differs from its defaults.
  final List<AutomationSectionPanel> sections;

  /// Reads the endpoints of the mock backend, so an override of an endpoint
  /// with a path id shows on each request under it, as the mock applies it,
  /// and the response sheet offers the backend error codes of the endpoint.
  /// Without it the panel matches an override on the exact path only and
  /// offers [backendErrorCodes] alone.
  final MockApiEndpointResolver Function()? readEndpointResolver;

  const AutomationPanelDefinition({
    required this.mock,
    required this.catalogue,
    required this.pages,
    required this.isRestartRequired,
    this.backendErrorCodes = const [],
    this.theme = const AutomationPanelTheme.light(),
    this.strings = const AutomationPanelStrings(),
    this.onShare,
    this.playerSettings = const AutomationPlayerSettings(),
    this.readEndpointResolver,
    this.sections = const [],
  });

  /// Creates the definition with the four usual pages: Flows, Autorun,
  /// Sections and Log, in this order.
  ///
  /// The [mock] parameter is the mock the panel changes.
  /// The [catalogue] parameter holds the flows a tester can walk.
  /// The [isRestartRequired] parameter is the flag the panel sets when the
  /// app must restart.
  /// The [sections] parameter lists the sections of the Sections page.
  /// The [wrapPage] parameter wraps each page, for the project to mark it for
  /// automation.
  /// The other parameters are those of [AutomationPanelDefinition.new].
  factory AutomationPanelDefinition.standard({
    required AutomationMock mock,
    required AutomationCatalogue catalogue,
    required ValueNotifier<bool> isRestartRequired,
    List<AutomationSectionPanel> sections = const [],
    FutureOr<void> Function(BuildContext context, File report)? onShare,
    List<String> backendErrorCodes = const [],
    AutomationPlayerSettings playerSettings = const AutomationPlayerSettings(),
    MockApiEndpointResolver Function()? readEndpointResolver,
    AutomationPanelTheme theme = const AutomationPanelTheme.light(),
    AutomationPanelStrings strings = const AutomationPanelStrings(),
    Widget Function(Widget page)? wrapPage,
  }) {
    Widget wrap(Widget page) => wrapPage == null ? page : wrapPage(page);

    return AutomationPanelDefinition(
      mock: mock,
      catalogue: catalogue,
      isRestartRequired: isRestartRequired,
      backendErrorCodes: backendErrorCodes,
      theme: theme,
      strings: strings,
      onShare: onShare,
      playerSettings: playerSettings,
      readEndpointResolver: readEndpointResolver,
      sections: sections,
      pages: [
        AutomationPanelPage(
          label: strings.flowsTab,
          builder: (_) => wrap(const AutomationFlowsPage()),
        ),
        AutomationPanelPage(
          label: strings.autorunTab,
          builder: (_) => wrap(const AutomationAutorunPage()),
        ),
        AutomationPanelPage(
          label: strings.sectionsTab,
          builder: (_) => wrap(AutomationSectionsPage(sections: sections)),
        ),
        AutomationPanelPage(
          label: strings.logTab,
          builder: (_) => wrap(const AutomationJournalPage()),
        ),
      ],
    );
  }
}
