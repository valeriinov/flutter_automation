import 'package:collection/collection.dart';

import 'package:flutter_automation_runner/src/automation_launch_source.dart';
import 'package:flutter_automation_runner/src/automation_localized_text.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

/// {@category Utils}
///
/// The way a variant enters its journey, read from the variant's `entry`.
///
/// Variants of one flow that differ by their entry are the ways a user starts
/// the same journey. A flow catalogue offers them as a choice on the
/// first frame of the flow.
final class AutomationFlowEntry {
  static const _titleKey = 'title';
  static const _launchedByKey = 'launchedBy';

  /// Where the user starts, in words for people.
  final AutomationLocalizedText title;

  /// What opened the app on the first screen, missing for a launch from the app
  /// icon.
  final AutomationLaunchSource? launchedBy;

  const AutomationFlowEntry({required this.title, required this.launchedBy});

  /// Reads the optional `entry` of [variant], `null` when it names none.
  ///
  /// The [variant] parameter is the variant object and the [subject]
  /// parameter names it in the error a malformed entry fails with.
  static AutomationFlowEntry? tryRead(
    Map<String, Object?> variant,
    String subject,
  ) {
    final json = variant['entry'];

    if (json == null) {
      return null;
    }

    if (json is! Map<String, Object?>) {
      throw AutomationRunnerException(
        '$subject has an "entry" that is not a JSON object.',
      );
    }

    final title = AutomationLocalizedText.tryRead(
      json,
      _titleKey,
      '$subject entry',
    );

    if (title == null) {
      throw AutomationRunnerException(
        '$subject has an "entry" without a "$_titleKey".',
      );
    }

    return AutomationFlowEntry(
      title: title,
      launchedBy: _tryReadLaunchSource(json[_launchedByKey], subject),
    );
  }

  /// The entry as the resolved JSON a dry run prints.
  Map<String, Object?> toJson() {
    return {_titleKey: title.toJson(), _launchedByKey: ?launchedBy?.name};
  }

  static AutomationLaunchSource? _tryReadLaunchSource(
    Object? value,
    String subject,
  ) {
    if (value == null) {
      return null;
    }

    final source = AutomationLaunchSource.values.firstWhereOrNull(
      (source) => source.name == value,
    );

    if (source == null) {
      throw AutomationRunnerException(
        '$subject has an unknown "$_launchedByKey" "$value". It takes one of '
        '${AutomationLaunchSource.values.map((source) => source.name)}.',
      );
    }

    return source;
  }
}
