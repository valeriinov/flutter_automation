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

  const AutomationSectionPanel({
    required this.title,
    this.section,
    this.api,
    this.requestTitles = const {},
    this.profileTitles = const {},
  });
}
