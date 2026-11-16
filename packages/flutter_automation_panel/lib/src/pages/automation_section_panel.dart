import 'package:flutter/foundation.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';

/// {@category Utils}
///
/// One section of the mock as the Sections page shows it: its title, its
/// profiles and its requests.
@immutable
final class AutomationSectionPanel {
  /// Title of the section card.
  final String title;

  /// What part of the app the section feeds, missing when the title says it.
  final String? description;

  /// The section whose profiles the card offers, missing for a section with
  /// none.
  final MockSection<Object?>? section;

  /// The api whose requests the card lists, missing for a section with none.
  final MockApi? api;

  /// Titles of the requests of [api], by path. A request without a title shows
  /// its path.
  final Map<String, String> requestTitles;

  /// Titles of the profiles, by profile name. A profile without a title shows
  /// its name.
  final Map<String, String> profileTitles;

  /// What each profile changes in the app, by profile name. A profile without
  /// a description shows none.
  final Map<String, String> profileDescriptions;

  const AutomationSectionPanel({
    required this.title,
    this.description,
    this.section,
    this.api,
    this.requestTitles = const {},
    this.profileTitles = const {},
    this.profileDescriptions = const {},
  });
}
