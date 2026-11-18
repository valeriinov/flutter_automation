import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/src/blocks/automation_flow_tile.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_label.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_search_field.dart';
import 'package:flutter_automation_panel/src/pages/automation_catalogue_text.dart';
import 'package:flutter_automation_panel/src/pages/automation_flow_map_page.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_scope.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// The Flows tab: the flows of the catalogue under their groups, and the groups
/// under their areas, with a search over flows, outcomes and requests. A tap
/// opens the map of the flow.
class AutomationFlowsPage extends StatefulWidget {
  const AutomationFlowsPage({super.key});

  @override
  State<AutomationFlowsPage> createState() => _AutomationFlowsPageState();
}

class _AutomationFlowsPageState extends State<AutomationFlowsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);
    final controller = AutomationPanelScope.of(context);
    final catalogue = controller.definition.catalogue;
    final flows = catalogue.flows.where(_matchesQuery).toList();

    return ListView(
      padding: const EdgeInsets.all(AutomationPanelTheme.gapLarge),
      children: [
        AutomationPanelSearchField(
          hint: strings.flowSearchHint,
          onChanged: (value) => setState(() => _query = value),
        ),
        for (final section in _sectionsOf(strings, catalogue, flows)) ...[
          const SizedBox(height: AutomationPanelTheme.gapMedium),
          if (section.areaTitle case final areaTitle?)
            Padding(
              padding: const EdgeInsets.only(
                bottom: AutomationPanelTheme.gapSmall,
              ),
              child: Text(
                areaTitle,
                style: theme.textStyle(
                  size: 16,
                  weight: FontWeight.w700,
                  color: theme.text,
                ),
              ),
            ),
          for (final group in section.groups) ...[
            Padding(
              padding: const EdgeInsets.only(
                bottom: AutomationPanelTheme.gapSmall,
              ),
              child: AutomationPanelLabel(text: group.title),
            ),
            for (final flow in group.flows)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AutomationPanelTheme.gapSmall,
                ),
                child: AutomationFlowTile(
                  title: AutomationCatalogueText.read(
                    flow.title,
                    flow.name,
                    strings.languageCode,
                  ),
                  subtitle: _describe(flow),
                  onPressed: () => _open(context, controller, flow),
                ),
              ),
          ],
        ],
      ],
    );
  }

  bool _matchesQuery(AutomationCatalogueFlow flow) {
    final strings = AutomationPanelStrings.of(context);

    return matchesSearchQuery(_query, [
      AutomationCatalogueText.read(flow.title, flow.name, strings.languageCode),
      for (final variant in flow.variants)
        AutomationCatalogueText.read(
          variant.title,
          variant.name,
          strings.languageCode,
        ),
      for (final variant in flow.variants)
        for (final step in variant.steps)
          for (final request in step.requests) request.path,
    ]);
  }

  List<_Section> _sectionsOf(
    AutomationPanelStrings strings,
    AutomationCatalogue catalogue,
    List<AutomationCatalogueFlow> flows,
  ) {
    final areas = {for (final area in catalogue.areas) area.name: area};
    final sections = <String, _Section>{};

    for (final group in _groupsOf(strings, catalogue, flows)) {
      final area = areas[group.area];
      final key = area?.name ?? group.name;
      final areaTitle = area == null
          ? null
          : AutomationCatalogueText.read(
              area.title,
              area.name,
              strings.languageCode,
            );

      sections.putIfAbsent(key, () => _Section(areaTitle)).groups.add(group);
    }

    return sections.values.toList();
  }

  List<_Group> _groupsOf(
    AutomationPanelStrings strings,
    AutomationCatalogue catalogue,
    List<AutomationCatalogueFlow> flows,
  ) {
    final groups = <_Group>[];

    for (final group in catalogue.groups) {
      final inGroup = flows.where((flow) => flow.group == group.name).toList();

      if (inGroup.isNotEmpty) {
        groups.add(
          _Group(
            group.name,
            AutomationCatalogueText.read(
              group.title,
              group.name,
              strings.languageCode,
            ),
            inGroup,
            area: group.area,
          ),
        );
      }
    }

    final known = catalogue.groups.map((group) => group.name).toSet();
    final others = flows.where((flow) => !known.contains(flow.group)).toList();

    if (others.isNotEmpty) {
      groups.add(_Group('', strings.flows, others));
    }

    return groups;
  }

  String _describe(AutomationCatalogueFlow flow) {
    final strings = AutomationPanelStrings.of(context);
    final steps = flow.variants
        .map((variant) => variant.steps.where((step) => !step.isService).length)
        .fold<int>(0, (most, count) => count > most ? count : most);
    final parts = [
      strings.variantCount(flow.variants.length),
      if (steps > 0) strings.stepCount(steps),
      if (flow.fork != null) strings.oneFork,
    ];

    return parts.join(' · ');
  }

  Future<void> _open(
    BuildContext context,
    AutomationPanelController controller,
    AutomationCatalogueFlow flow,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AutomationFlowMapPage(flow: flow),
      ),
    );
  }
}

class _Group {
  final String name;
  final String title;
  final List<AutomationCatalogueFlow> flows;
  final String? area;

  const _Group(this.name, this.title, this.flows, {this.area});
}

class _Section {
  final String? areaTitle;
  final List<_Group> groups = [];

  _Section(this.areaTitle);
}
