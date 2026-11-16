import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/blocks/automation_latency_note.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_card.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_frame.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_label.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_option.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_radio_tile.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_search_field.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_segments.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_sheet.dart';
import 'package:flutter_automation_panel/src/pages/automation_section_panel.dart';
import 'package:flutter_automation_panel/src/pages/mock_endpoint_panel.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_scope.dart';
import 'package:flutter_automation_panel/src/panel/automation_profile_selection.dart';
import 'package:flutter_automation_panel/src/sheets/automation_confirm_sheet.dart';
import 'package:flutter_automation_panel/src/sheets/automation_response_sheet.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The Sections tab: the latency of the mock and one card per section with its
/// profile and its requests. A search over section titles and request paths
/// narrows the cards.
///
/// A section shows `Default` when it holds no setting, the title of a profile
/// when its settings equal that profile, and `Custom` otherwise.
class AutomationSectionsPage extends StatefulWidget {
  /// The sections the page lists, in order.
  final List<AutomationSectionPanel> sections;

  const AutomationSectionsPage({required this.sections, super.key});

  @override
  State<AutomationSectionsPage> createState() => _AutomationSectionsPageState();
}

class _AutomationSectionsPageState extends State<AutomationSectionsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final controller = AutomationPanelScope.of(context);

    return ListView(
      padding: const EdgeInsets.all(AutomationPanelTheme.gapLarge),
      children: [
        AutomationPanelSearchField(
          hint: strings.sectionSearchHint,
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: AutomationPanelTheme.gapMedium),
        AutomationPanelLabel(text: strings.responseLatency),
        const SizedBox(height: AutomationPanelTheme.gapMedium),
        AutomationPanelSegments<MockLatencyProfile>(
          options: [
            for (final profile in MockLatencyProfile.values)
              AutomationPanelOption(
                value: profile,
                label: strings.latencyLabel(profile),
              ),
          ],
          selected: controller.mock.latency.profile,
          onChanged: (profile) => _selectLatency(controller, profile),
        ),
        const SizedBox(height: AutomationPanelTheme.gapSmall),
        AutomationLatencyNote(profile: controller.mock.latency.profile),
        for (final section in widget.sections.where(_matchesQuery)) ...[
          const SizedBox(height: AutomationPanelTheme.gapMedium),
          _SectionCard(section: section, controller: controller),
        ],
      ],
    );
  }

  bool _matchesQuery(AutomationSectionPanel section) {
    final languageCode = AutomationPanelStrings.of(context).languageCode;
    final endpoints = section.api?.endpoints ?? const <MockApiEndpoint>[];

    return matchesSearchQuery(_query, [
      section.title.resolve(languageCode),
      ?section.description?.resolve(languageCode),
      ?section.section?.name,
      for (final endpoint in endpoints) endpoint.path,
      for (final endpoint in endpoints) ?endpoint.title?.resolve(languageCode),
    ]);
  }

  void _selectLatency(
    AutomationPanelController controller,
    MockLatencyProfile profile,
  ) {
    final json = controller.mock.scenario.toJson();

    json[MockScenario.latencyKey] = profile.name;

    controller.updateScenario(MockScenario.fromJson(json));
  }
}

class _SectionCard extends StatelessWidget {
  final AutomationSectionPanel section;
  final AutomationPanelController controller;

  const _SectionCard({required this.section, required this.controller});

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final languageCode = strings.languageCode;
    final mockSection = section.section;
    final api = section.api;
    final endpoints = api?.endpoints ?? const <MockApiEndpoint>[];
    final overrides = endpoints
        .where((endpoint) => _hasOverride(endpoint.path))
        .length;

    return AutomationPanelCard(
      title: section.title.resolve(languageCode),
      subtitle: section.description?.resolve(languageCode),
      children: [
        if (mockSection != null)
          AutomationPanelCardRow(
            label: strings.profile,
            value: _describeProfile(mockSection, strings),
            onPressed: () => _openProfiles(context, mockSection),
          ),
        if (api != null)
          AutomationPanelCardRow(
            label: strings.requests,
            overrideValue: overrides == 0
                ? null
                : strings.overrideCount(overrides),
            note: overrides == 0
                ? '${endpoints.length}'
                : '· ${endpoints.length}',
            onPressed: () => _openRequests(context, endpoints),
          ),
      ],
    );
  }

  bool _hasOverride(String path) {
    return controller.failureOf(path) != null ||
        controller.latencyOf(path) != null;
  }

  String _describeProfile(
    MockSection<Object?> mockSection,
    AutomationPanelStrings strings,
  ) {
    return AutomationProfileSelection.read(
      controller,
      mockSection,
    ).describe(section, strings);
  }

  Future<void> _openProfiles(
    BuildContext context,
    MockSection<Object?> mockSection,
  ) {
    return showAutomationPanelSheet<void>(
      context: context,
      builder: (sheetContext) {
        return _ProfileSheet(
          section: section,
          mockSection: mockSection,
          controller: controller,
        );
      },
    );
  }

  Future<void> _openRequests(
    BuildContext context,
    List<MockApiEndpoint> endpoints,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RequestsPage(
          title: section.title.resolve(
            AutomationPanelStrings.of(context).languageCode,
          ),
          endpoints: endpoints,
        ),
      ),
    );
  }
}

class _ProfileSheet extends StatefulWidget {
  static const maxProfilesWithoutSearch = 8;

  final AutomationSectionPanel section;
  final MockSection<Object?> mockSection;
  final AutomationPanelController controller;

  const _ProfileSheet({
    required this.section,
    required this.mockSection,
    required this.controller,
  });

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);
    final section = widget.section;
    final description = section.description?.resolve(strings.languageCode);
    final profileNames = widget.mockSection.profileNames;
    final selection = AutomationProfileSelection.read(
      widget.controller,
      widget.mockSection,
    );

    return AutomationPanelSheet(
      title: strings.profileSheetTitle(
        section.title.resolve(strings.languageCode),
      ),
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AutomationPanelTheme.gapSmall,
        children: [
          if (description != null)
            Text(
              description,
              style: theme.textStyle(size: 14, color: theme.textSecondary),
            ),
          if (profileNames.length > _ProfileSheet.maxProfilesWithoutSearch)
            AutomationPanelSearchField(
              hint: strings.profileSearchHint,
              onChanged: (value) => setState(() => _query = value),
            ),
          for (final name in [null, ...profileNames].where(_matchesQuery))
            AutomationPanelRadioTile(
              title: _resolveTitle(name),
              subtitle: _describeProfile(name),
              code: name,
              needsRestart: _needsRestart(name),
              isSelected: name == null
                  ? selection.isDefault
                  : name == selection.profileName,
              activeColor: _needsRestart(name) ? theme.restart : null,
              onPressed: () => _select(context, name),
            ),
        ],
      ),
    );
  }

  bool _matchesQuery(String? profileName) {
    if (profileName == null) {
      return _query.trim().isEmpty;
    }

    final languageCode = AutomationPanelStrings.of(context).languageCode;
    final profile = widget.mockSection.profiles[profileName];

    return matchesSearchQuery(_query, [
      profileName,
      ?profile?.title.resolve(languageCode),
      ?profile?.description?.resolve(languageCode),
    ]);
  }

  String _resolveTitle(String? profileName) {
    final strings = AutomationPanelStrings.of(context);

    if (profileName == null) {
      return strings.defaultName;
    }

    return widget.section.profileTitle(profileName, strings.languageCode);
  }

  String? _describeProfile(String? profileName) {
    final strings = AutomationPanelStrings.of(context);

    return profileName == null
        ? strings.defaultProfileDescription
        : widget.mockSection.profiles[profileName]?.description?.resolve(
            strings.languageCode,
          );
  }

  bool _needsRestart(String? profileName) {
    final next = AutomationProfileSelection.scenarioWith(
      widget.controller,
      widget.mockSection,
      profileName,
    );

    return widget.controller.requiresRestart(next.toJson());
  }

  void _select(BuildContext context, String? profileName) {
    applyAutomationScenario(
      context: context,
      controller: widget.controller,
      scenario: AutomationProfileSelection.scenarioWith(
        widget.controller,
        widget.mockSection,
        profileName,
      ),
      onApplied: Navigator.of(context).pop,
    );
  }
}

class _RequestsPage extends StatelessWidget {
  final String title;
  final List<MockApiEndpoint> endpoints;

  const _RequestsPage({required this.title, required this.endpoints});

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final controller = AutomationPanelScope.of(context);
    final languageCode = strings.languageCode;
    final theme = AutomationPanelTheme.of(context);

    return AutomationPanelFrame(
      title: title,
      subtitle: strings.requests,
      onBack: () => Navigator.of(context).pop(),
      onClose: controller.closePanel,
      child: Material(
        color: theme.background,
        child: ListView(
          padding: const EdgeInsets.all(AutomationPanelTheme.gapLarge),
          children: [
            for (final endpoint in endpoints) ...[
              MockEndpointPanel(
                endpoint: endpoint,
                title: _titleOf(endpoint, languageCode),
                failure: controller.failureOf(endpoint.path),
                latency: controller.latencyOf(endpoint.path),
                onPressed: () =>
                    _openResponse(context, controller, endpoint, languageCode),
                onClearOverride: () => controller.clearOverride(endpoint.path),
              ),
              const SizedBox(height: AutomationPanelTheme.gapMedium),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openResponse(
    BuildContext context,
    AutomationPanelController controller,
    MockApiEndpoint endpoint,
    String languageCode,
  ) {
    return showAutomationResponseSheet(
      context: context,
      controller: controller,
      path: endpoint.path,
      mockDescription: _titleOf(endpoint, languageCode),
    );
  }

  String _titleOf(MockApiEndpoint endpoint, String languageCode) {
    return endpoint.title?.resolve(languageCode) ?? endpoint.path;
  }
}
