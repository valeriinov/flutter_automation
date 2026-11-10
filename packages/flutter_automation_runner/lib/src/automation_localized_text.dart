import 'package:collection/collection.dart';

import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

/// {@category Utils}
///
/// Text a flow file carries for people rather than for the driver, written
/// once per locale.
final class AutomationLocalizedText {
  final Map<String, String> _texts;

  const AutomationLocalizedText(this._texts);

  /// The locale codes that hold a version of the text.
  Iterable<String> get locales => _texts.keys;

  /// Reads the optional text under [key] of [json], `null` when it is missing.
  ///
  /// The [json] parameter is the object that holds the text. The [key]
  /// parameter is the name of the text in that object. The [subject] parameter
  /// names that object in the error that a malformed text fails with.
  static AutomationLocalizedText? tryRead(
    Map<String, Object?> json,
    String key,
    String subject,
  ) {
    final value = json[key];

    if (value == null) {
      return null;
    }

    if (value case final Map<String, Object?> texts when _areFilled(texts)) {
      return AutomationLocalizedText(Map<String, String>.from(texts));
    }

    throw AutomationRunnerException(
      '$subject has a malformed "$key". It takes '
      '{"<locale code>": "…"}, one or more non-empty strings.',
    );
  }

  /// The text written for [locale].
  ///
  /// Throws an [AutomationRunnerException] when the text has no entry for
  /// [locale].
  String read(String locale) {
    final text = _texts[locale];

    if (text == null) {
      throw AutomationRunnerException(
        'The text has no "$locale" entry. It holds ${_texts.keys.toList()}.',
      );
    }

    return text;
  }

  /// The text as a flow file writes it.
  Map<String, String> toJson() {
    final entries = _texts.entries.sortedBy((entry) => entry.key);

    return {for (final MapEntry(:key, :value) in entries) key: value};
  }

  static bool _areFilled(Map<String, Object?> texts) {
    return texts.isNotEmpty &&
        texts.values.every((text) => text is String && text.trim().isNotEmpty);
  }
}
