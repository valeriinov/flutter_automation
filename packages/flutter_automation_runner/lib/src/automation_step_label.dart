/// {@category Utils}
///
/// The short words that report and title a step, read off the step object.
///
/// A step that names its own `label` keeps it. The runner calls each other step
/// after the action and what it addresses. A step that nobody titled therefore
/// still reads as something a person can follow.
final class AutomationStepLabel {
  const AutomationStepLabel._();

  /// The label of the step [json] holds, which runs the [action].
  static String resolve(Map<String, Object?> json, String action) {
    final label = json['label'];

    if (label is String) {
      return label;
    }

    final named = json['text'] ?? json['command'];
    final subject = named is String ? named : _describeFinder(json['finder']);

    return subject == null ? action : '$action $subject';
  }

  static String? _describeFinder(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }

    final value = json['value'];

    return switch (value) {
      null => _describeFinder(json['matching']),
      final Map<String, Object?> localized => localized.values.join(' / '),
      _ => '$value',
    };
  }
}
