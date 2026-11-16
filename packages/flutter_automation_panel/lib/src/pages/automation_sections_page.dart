import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/blocks/automation_latency_note.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_card.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_count.dart';
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
    final controller = AutomationPanelScope.of(context);

    return ListView(
      padding: const EdgeInsets.all(AutomationPanelTheme.gapLarge),
      children: [
        AutomationPanelSearchField(
          hint: AutomationPanelStrings.sectionSearchHint,
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: AutomationPanelTheme.gapMedium),
        const AutomationPanelLabel(
          text: AutomationPanelStrings.responseLatency,
        ),
        const SizedBox(height: AutomationPanelTheme.gapMedium),
        AutomationPanelSegments<MockLatencyProfile>(
          options: [
            for (final MapEntry(:key, :value)
                in AutomationLatencyNote.labels.entries)
              AutomationPanelOption(value: key, label: value),
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
    final endpoints = section.api?.endpoints ?? const <MockApiEndpoint>[];

    return matchesSearchQuery(_query, [
      section.title,
      ?section.description,
      ?section.section?.name,
      for (final endpoint in endpoints) endpoint.path,
      for (final endpoint in endpoints) ?section.requestTitles[endpoint.path],
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
    final mockSection = section.section;
    final api = section.api;
    final endpoints = api?.endpoints ?? const <MockApiEndpoint>[];
    final overrides = endpoints
        .where((endpoint) => _hasOverride(endpoint.path))
        .length;

    return AutomationPanelCard(
      title: section.title,
      subtitle: section.description,
      children: [
        if (mockSection != null)
          AutomationPanelCardRow(
            label: AutomationPanelStrings.profile,
            value: _describeProfile(mockSection),
            onPressed: () => _openProfiles(context, mockSection),
          ),
        if (api != null)
          AutomationPanelCardRow(
            label: AutomationPanelStrings.requests,
            overrideValue: overrides == 0
                ? null
                : describeOverrideCount(overrides),
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

  String _describeProfile(MockSection<Object?> mockSection) {
    return AutomationProfileSelection.read(
      controller,
      mockSection,
    ).describe(section);
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
          title: section.title,
          endpoints: endpoints,
          requestTitles: section.requestTitles,
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
    final theme = AutomationPanelTheme.of(context);
    final section = widget.section;
    final description = section.description;
    final profileNames = widget.mockSection.profileNames;
    final selection = AutomationProfileSelection.read(
      widget.controller,
      widget.mockSection,
    );

    return AutomationPanelSheet(
      title: '${section.title} profile',
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
              hint: AutomationPanelStrings.profileSearchHint,
              onChanged: (value) => setState(() => _query = value),
            ),
          for (final name in [null, ...profileNames].where(_matchesQuery))
            AutomationPanelRadioTile(
              title: _resolveTitle(name),
              subtitle: _describeProfile(name),
              code: _resolveCode(name),
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

    return matchesSearchQuery(_query, [
      profileName,
      ?widget.section.profileTitles[profileName],
      ?widget.section.profileDescriptions[profileName],
    ]);
  }

  String _resolveTitle(String? profileName) {
    if (profileName == null) {
      return AutomationPanelStrings.defaultName;
    }

    return widget.section.profileTitles[profileName] ?? profileName;
  }

  String? _resolveCode(String? profileName) {
    final hasTitle = widget.section.profileTitles.containsKey(profileName);

    return hasTitle ? profileName : null;
  }

  String? _describeProfile(String? profileName) {
    return profileName == null
        ? AutomationPanelStrings.defaultProfileDescription
        : widget.section.profileDescriptions[profileName];
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
  final Map<String, String> requestTitles;

  const _RequestsPage({
    required this.title,
    required this.endpoints,
    required this.requestTitles,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AutomationPanelScope.of(context);
    final theme = AutomationPanelTheme.of(context);

    return AutomationPanelFrame(
      title: title,
      subtitle: AutomationPanelStrings.requests,
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
                title: requestTitles[endpoint.path] ?? endpoint.path,
                failure: controller.failureOf(endpoint.path),
                latency: controller.latencyOf(endpoint.path),
                onPressed: () => _openResponse(context, controller, endpoint),
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
  ) {
    return showAutomationResponseSheet(
      context: context,
      controller: controller,
      path: endpoint.path,
      mockDescription: requestTitles[endpoint.path] ?? endpoint.path,
    );
  }
}
