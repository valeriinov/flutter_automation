/// {@category Utils}
///
/// One answer of the app's `journal.read` command. It holds the records that
/// the app wrote since the previous read, and the record of the launch that the
/// app keeps beside them.
final class AutomationJournalAnswer {
  /// Records in the order the app wrote them.
  final List<Map<String, Object?>> records;

  /// The record of the launch, missing when the app keeps none.
  final Map<String, Object?>? launch;

  const AutomationJournalAnswer({required this.records, this.launch});

  /// Reads the decoded answer [json].
  ///
  /// Throws a [StateError] when [json] is not a `{"records"}` object whose
  /// records are objects.
  factory AutomationJournalAnswer.fromJson(Object? json) {
    if (json case {
      'records': final List<Object?> records,
    } when records.every((record) => record is Map<String, Object?>)) {
      return AutomationJournalAnswer(
        records: records.whereType<Map<String, Object?>>().toList(),
        launch: _tryReadLaunch(json),
      );
    }

    throw StateError('The journal answer is not a {"records"} object.');
  }

  static Map<String, Object?>? _tryReadLaunch(Object? json) {
    if (json case {'launch': final Map<String, Object?> launch}) {
      return launch;
    }

    return null;
  }
}
