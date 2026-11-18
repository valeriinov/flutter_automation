import 'package:flutter_automation_runner/automation_flow_definition.dart';

import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_project.dart';

/// {@category Utils}
///
/// The areas and the groups the atlas page lists its flows by.
///
/// [AtlasProject.groupOrder] holds the groups in page order, and a group names
/// its area. A flow lists under the group it names through
/// `AutomationFlowGroup`, in the order the flows are declared. A shown flow
/// that declares no group joins [AtlasProject.defaultGroup]; a group
/// [AtlasProject.groupOrder] lacks stops the page. A group without an area
/// stands as an area of its own.
final class AtlasGroups {
  final AtlasDefinitions _definitions;
  final AtlasProject _project;

  /// The groups that the flows of the definitions declare.
  const AtlasGroups(this._definitions, this._project);

  /// The areas as the page data holds them: each group carries its title and
  /// the [shownFlows] it lists; a group listing none and an area listing none
  /// are left out.
  ///
  /// Throws an [AtlasException] when the group of a shown flow is not in
  /// [AtlasProject.groupOrder].
  List<Map<String, Object?>> buildPageData({required List<String> shownFlows}) {
    final flowsByGroup = _groupFlows(shownFlows);
    final areas = <String, ({AutomationFlowArea area, List<Object?> groups})>{};

    for (final group in _project.groupOrder) {
      final flows = flowsByGroup[group.name];

      if (flows == null) {
        continue;
      }

      final area =
          group.area ??
          AutomationFlowArea(name: group.name, title: group.title);

      areas.putIfAbsent(area.name, () => (area: area, groups: [])).groups.add({
        'name': group.name,
        'title': group.title.toJson(),
        'flows': flows,
      });
    }

    return [
      for (final (:area, :groups) in areas.values)
        {'name': area.name, 'title': area.title.toJson(), 'scenarios': groups},
    ];
  }

  Map<String, List<String>> _groupFlows(List<String> shownFlows) {
    final flowsByGroup = <String, List<String>>{};
    final declared = _definitions.declarationOrder;
    final ordered = [...shownFlows]
      ..sort((first, second) {
        return declared.indexOf(first).compareTo(declared.indexOf(second));
      });

    for (final flowName in ordered) {
      final groupName = _resolveGroupName(_definitions.findFlow(flowName));

      flowsByGroup.putIfAbsent(groupName, () => []).add(flowName);
    }

    return flowsByGroup;
  }

  String _resolveGroupName(AtlasDefinition flow) {
    final groupName = flow.groupName ?? _project.defaultGroup.name;
    final isKnown = _project.groupOrder.any((group) => group.name == groupName);

    if (isKnown) {
      return groupName;
    }

    throw AtlasException(
      'The group "$groupName" of flow "${flow.name}" is not in '
      'AtlasProject.groupOrder.',
    );
  }
}
