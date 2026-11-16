import 'package:flutter/foundation.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';

/// {@category Utils}
///
/// One section of the mock as the Sections page shows it: its title, its
/// profiles and its requests.
///
/// The texts come from the declarations: the section and its profiles carry
/// their titles, and each endpoint of [api] carries the title of its request.
@immutable
final class AutomationSectionPanel {
  /// Title of the section card.
  final AutomationLocalizedText title;

  /// What part of the app the section feeds, missing when the title says it.
  final AutomationLocalizedText? description;

  /// The section whose profiles the card offers, missing for a section with
  /// none.
  final MockSection<Object?>? section;

  /// The api whose requests the card lists, missing for a section with none.
  /// A request without a title shows its path.
  final MockApi? api;

  /// Creates a card for a section that has an [api] and no [MockSection]: it
  /// lists requests and offers no profile.
  const AutomationSectionPanel({
    required this.title,
    this.description,
    this.api,
  }) : section = null;

  /// Creates the card of [section] with the title, the description and the
  /// profiles of the section.
  ///
  /// The [api] parameter holds the requests the card lists, when the section
  /// has some.
  AutomationSectionPanel.fromSection(
    MockSection<Object?> this.section, {
    this.api,
  }) : title = section.title,
       description = section.description;

  /// The title of the profile [name] in [languageCode], else [name].
  String profileTitle(String name, String languageCode) {
    return section?.profiles[name]?.title.resolve(languageCode) ?? name;
  }
}
