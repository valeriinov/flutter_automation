/// Reads the fields of a record of the mock journal that the panel shows.
abstract final class AutomationJournalRecord {
  static const _seqKey = 'seq';
  static const _methodKey = 'method';
  static const _pathKey = 'path';
  static const _statusKey = 'status';

  /// Position of [record] in the journal, `null` when it has none.
  static int? seqOf(Map<String, Object?> record) {
    final seq = record[_seqKey];

    return seq is int ? seq : null;
  }

  /// Path of the request that [record] reports, `null` for another record.
  static String? pathOf(Map<String, Object?> record) {
    final path = record[_pathKey];

    return path is String ? path : null;
  }

  /// HTTP method of [record], empty when it has none.
  static String methodOf(Map<String, Object?> record) {
    final method = record[_methodKey];

    return method is String ? method : '';
  }

  /// Status code of the answer of [record], `null` while it has none.
  static int? statusCodeOf(Map<String, Object?> record) {
    final status = record[_statusKey];

    return status is int ? status : null;
  }
}
