import 'package:flutter_automation_mock/src/scenario/automation_localized_text.dart';

/// {@category Utils}
///
/// Named change of the settings of one `MockSection`, with the texts that the
/// QA panel shows for it.
///
/// [S] is the settings class of the section.
final class MockProfile<S> {
  /// Title of the profile in the QA panel.
  final AutomationLocalizedText title;

  /// What the profile changes in the app, missing when the title says it.
  final AutomationLocalizedText? description;

  final S Function(S settings) _update;

  /// Creates a profile.
  ///
  /// The [update] parameter receives the settings that the earlier overrides
  /// of the scenario built and returns the settings the run needs.
  /// The [title] parameter is the title of the profile in the QA panel.
  /// The [description] parameter tells what the profile changes in the app.
  const MockProfile(
    S Function(S settings) update, {
    required this.title,
    this.description,
  }) : _update = update;

  /// Returns the settings the run needs, built out of [settings].
  S update(S settings) => _update(settings);
}
