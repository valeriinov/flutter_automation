import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_card.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_count.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_frame.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_label.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_option.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_radio_tile.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_segments.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_sheet.dart';
import 'package:flutter_automation_panel/src/pages/automation_section_panel.dart';
import 'package:flutter_automation_panel/src/pages/mock_endpoint_panel.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_scope.dart';
import 'package:flutter_automation_panel/src/sheets/automation_response_sheet.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The Sections tab: the latency of the mock and one card per section with its
/// profile and its requests.
///
/// A section shows `Default` when it holds no setting, the title of a profile
/// when its settings equal that profile, and `Custom` otherwise.
class AutomationSectionsPage extends StatelessWidget {
  static const _latencyLabels = {
    MockLatencyProfile.fast: 'Fast',
    MockLatencyProfile.realistic: 'Real',
    MockLatencyProfile.slow: 'Slow',
  };

  /// The sections the page lists, in order.
  final List<AutomationSectionPanel> sections;

  const AutomationSectionsPage({required this.sections, super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AutomationPanelScope.of(context);

    return ListView(
      padding: const EdgeInsets.all(AutomationPanelTheme.gapLarge),
      children: [
        const AutomationPanelLabel(text: 'Response latency'),
        const SizedBox(height: AutomationPanelTheme.gapMedium),
        AutomationPanelSegments<MockLatencyProfile>(
          options: [
            for (final MapEntry(:key, :value) in _latencyLabels.entries)
              AutomationPanelOption(value: key, label: value),
          ],
          selected: controller.mock.latency.profile,
          onChanged: (profile) => _selectLatency(controller, profile),
        ),
        for (final section in sections) ...[
          const SizedBox(height: AutomationPanelTheme.gapMedium),
          _SectionCard(section: section, controller: controller),
        ],
      ],
    );
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

/// What a section holds now, against its profiles.
final class _ProfileSelection {
  static const _equality = DeepCollectionEquality();

  /// Whether the section holds no setting.
  final bool isDefault;

  /// The profile whose settings the section holds, missing otherwise.
  final String? profileName;

  const _ProfileSelection({required this.isDefault, this.profileName});

  factory _ProfileSelection.read(
    AutomationPanelController controller,
    MockSection<Object?> mockSection,
  ) {
    final current = controller.mock.scenario.toJson()[mockSection.name];

    if (current == null || (current is Map && current.isEmpty)) {
      return const _ProfileSelection(isDefault: true);
    }

    final name = mockSection.profileNames.firstWhereOrNull((name) {
      final applied = MockScenario([mockSection.profile(name)]).toJson();

      return _equality.equals(applied[mockSection.name], current);
    });

    return _ProfileSelection(isDefault: false, profileName: name);
  }

  bool get isCustom => !isDefault && profileName == null;
}

/// The scenario of [controller] with the section [mockSection] set to the
/// profile [profileName], or to its defaults when [profileName] is `null`.
MockScenario _scenarioWithProfile(
  AutomationPanelController controller,
  MockSection<Object?> mockSection,
  String? profileName,
) {
  final json = controller.mock.scenario.toJson()..remove(mockSection.name);

  return MockScenario([
    ...MockScenario.fromJson(json).overrides,
    if (profileName != null) mockSection.profile(profileName),
  ]);
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
        .where((endpoint) => controller.failureOf(endpoint.path) != null)
        .length;

    return AutomationPanelCard(
      title: section.title,
      children: [
        if (mockSection != null)
          AutomationPanelCardRow(
            label: 'Profile',
            value: _describeProfile(mockSection),
            onPressed: () => _openProfiles(context, mockSection),
          ),
        if (api != null)
          AutomationPanelCardRow(
            label: 'Requests',
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

  String _describeProfile(MockSection<Object?> mockSection) {
    final selection = _ProfileSelection.read(controller, mockSection);
    final name = selection.profileName;

    if (selection.isDefault) {
      return 'Default';
    }

    return name == null ? 'Custom' : section.profileTitles[name] ?? name;
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

class _ProfileSheet extends StatelessWidget {
  final AutomationSectionPanel section;
  final MockSection<Object?> mockSection;
  final AutomationPanelController controller;

  const _ProfileSheet({
    required this.section,
    required this.mockSection,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final selection = _ProfileSelection.read(controller, mockSection);

    return AutomationPanelSheet(
      title: '${section.title} profile',
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AutomationPanelTheme.gapSmall,
        children: [
          for (final name in [null, ...mockSection.profileNames])
            AutomationPanelRadioTile(
              title: name == null
                  ? 'Default'
                  : section.profileTitles[name] ?? name,
              subtitle: _needsRestart(name) ? '⟳ Restarts the app' : null,
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

  bool _needsRestart(String? profileName) {
    final next = _scenarioWithProfile(controller, mockSection, profileName);

    return controller.requiresRestart(next.toJson());
  }

  void _select(BuildContext context, String? profileName) {
    controller.updateScenario(
      _scenarioWithProfile(controller, mockSection, profileName),
    );
    Navigator.of(context).pop();
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
      subtitle: 'Requests',
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
                onPressed: () => _openResponse(context, controller, endpoint),
                onClearOverride: () =>
                    controller.setFailure(endpoint.path, null),
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
