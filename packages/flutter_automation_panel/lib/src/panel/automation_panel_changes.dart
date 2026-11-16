import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/pages/automation_section_panel.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/panel/automation_profile_selection.dart';

/// What the mock holds apart from its defaults, as the Changes page lists it.
final class AutomationPanelChanges {
  static const _hiddenKeys = {MockScenario.latencySeedKey};

  /// Whether the scenario sets the latency of every request.
  final bool hasLatency;

  /// The sections whose profile differs from their defaults.
  final List<AutomationSectionPanel> profiles;

  /// The paths with a failure, a latency of their own or both.
  final List<String> paths;

  /// The keys of the scenario no other change covers.
  final List<String> otherKeys;

  const AutomationPanelChanges({
    required this.hasLatency,
    required this.profiles,
    required this.paths,
    required this.otherKeys,
  });

  /// The changes the scenario of [controller] holds.
  factory AutomationPanelChanges.read(AutomationPanelController controller) {
    final scenario = controller.mock.scenario.toJson();
    final sections = controller.definition.sections;
    final coveredKeys = {
      MockScenario.latencyKey,
      MockScenario.failuresKey,
      MockScenario.latenciesKey,
      ..._hiddenKeys,
      for (final section in sections) ?section.section?.name,
    };

    return AutomationPanelChanges(
      hasLatency: scenario.containsKey(MockScenario.latencyKey),
      profiles: sections
          .where((section) => _isProfileChanged(controller, section))
          .toList(),
      paths: {
        ...controller.failures.keys,
        ...controller.latencies.keys,
      }.toList(),
      otherKeys: scenario.keys
          .where((key) => !coveredKeys.contains(key))
          .toList(),
    );
  }

  /// How many changes the mock holds, each of which a tester can remove.
  int get count {
    return (hasLatency ? 1 : 0) +
        profiles.length +
        paths.length +
        otherKeys.length;
  }

  static bool _isProfileChanged(
    AutomationPanelController controller,
    AutomationSectionPanel section,
  ) {
    final mockSection = section.section;

    return mockSection != null &&
        !AutomationProfileSelection.read(controller, mockSection).isDefault;
  }
}
