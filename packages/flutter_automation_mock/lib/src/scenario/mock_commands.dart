/// {@category Utils}
///
/// Names of the commands the runner sends and the mock answers.
abstract final class MockCommands {
  /// Applies a scenario.
  static const apply = 'mock.apply';

  /// Reads and empties the journal.
  static const journalRead = 'journal.read';

  /// Applies a language.
  static const localeApply = 'locale.apply';
}
