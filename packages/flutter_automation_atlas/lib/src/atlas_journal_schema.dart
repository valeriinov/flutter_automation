/// {@category Utils}
///
/// The shape of the journal records the app writes, as the atlas reads them.
///
/// A journal record is a JSON object. Its `kind` key tells what the record
/// is, and its `name` key names an event.
final class AtlasJournalSchema {
  /// The kind of the record of an analytics event.
  final String analyticsKind;

  /// The kind of the record of a state change.
  final String stateKind;

  /// The kinds of the records of a request; a request record follows the
  /// state change that sent it.
  final Set<String> requestKinds;

  /// The kind of the record of a launch.
  final String launchKind;

  /// The kinds of the records that answer a question the atlas asks the mock
  /// again.
  final Set<String> answerKinds;

  /// The key of a state record that names the owner of the state.
  final String stateKey;

  /// The key of a state record whose value is `true` when the state change
  /// created its owner.
  final String createdKey;

  /// The key of an analytics record that holds the parameters of the event.
  final String parametersKey;

  /// The key of the parameter that names a screen, in an analytics record.
  final String screenNameParameter;

  /// The name of the analytics event the app logs when a screen opens.
  final String screenViewName;

  /// The keys removed at every depth of a record: values the app draws anew
  /// on every run.
  final Set<String> volatileKeys;

  /// The regular expression of a value the app draws once per install, and
  /// the text that stands for it in a comparison.
  final AtlasJournalPlaceholder installValue;

  /// The regular expression of a value the app draws anew for each thing it
  /// names, and the text that stands for it in a comparison.
  final AtlasJournalPlaceholder generatedValue;

  /// The record the mock answers implicitly, for an [answer] that follows
  /// [earlierAnswers]; absent when the answer implies none.
  ///
  /// The atlas puts the record before the answer when it replays a snapshot.
  final Map<String, Object?>? Function(
    List<Map<String, Object?>> earlierAnswers,
    Map<String, Object?> answer,
  )?
  tryImplyAnswer;

  const AtlasJournalSchema({
    required this.analyticsKind,
    required this.stateKind,
    required this.requestKinds,
    required this.launchKind,
    required this.answerKinds,
    required this.stateKey,
    required this.createdKey,
    required this.parametersKey,
    required this.screenNameParameter,
    required this.screenViewName,
    required this.installValue,
    required this.generatedValue,
    this.volatileKeys = const {},
    this.tryImplyAnswer,
  });
}

/// {@category Utils}
///
/// A kind of value a journal holds that differs between two runs of the same
/// walk.
final class AtlasJournalPlaceholder {
  /// The regular expression that matches the value.
  final String pattern;

  /// The text that stands for every match in a comparison and in a hash.
  final String placeholder;

  const AtlasJournalPlaceholder({
    required this.pattern,
    required this.placeholder,
  });
}
