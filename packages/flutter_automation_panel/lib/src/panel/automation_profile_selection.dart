import 'package:collection/collection.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/pages/automation_section_panel.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// What a section of the mock holds now, against its profiles.
final class AutomationProfileSelection {
  static const _equality = DeepCollectionEquality();

  /// Whether the section holds no setting.
  final bool isDefault;

  /// The profile whose settings the section holds, missing otherwise.
  final String? profileName;

  const AutomationProfileSelection({required this.isDefault, this.profileName});

  /// What [mockSection] holds in the scenario of [controller].
  factory AutomationProfileSelection.read(
    AutomationPanelController controller,
    MockSection<Object?> mockSection,
  ) {
    final current = controller.mock.scenario.toJson()[mockSection.name];

    if (current == null || (current is Map && current.isEmpty)) {
      return const AutomationProfileSelection(isDefault: true);
    }

    final name = mockSection.profileNames.firstWhereOrNull((name) {
      final applied = MockScenario([mockSection.profile(name)]).toJson();

      return _equality.equals(applied[mockSection.name], current);
    });

    return AutomationProfileSelection(isDefault: false, profileName: name);
  }

  /// The words a card shows for this selection of [section]: `Default`, the
  /// title of the profile, or `Custom`. The [strings] parameter holds the words
  /// and the language of the profile title.
  String describe(
    AutomationSectionPanel section,
    AutomationPanelStrings strings,
  ) {
    final name = profileName;

    if (isDefault) {
      return strings.defaultName;
    }

    if (name == null) {
      return strings.custom;
    }

    return section.profileTitle(name, strings.languageCode);
  }

  /// The scenario of [controller] with [mockSection] set to the profile
  /// [profileName], or to its defaults when [profileName] is `null`.
  static MockScenario scenarioWith(
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
}
