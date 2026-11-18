import 'package:flutter_automation_atlas/src/atlas_journal_schema.dart';

/// {@category Utils}
///
/// Strips a journal record of what differs between two runs of the same walk,
/// so a snapshot changes only when the app does.
///
/// The keys of [AtlasJournalSchema.volatileKeys] are removed at every depth of
/// a record: values the app or an SDK stand-in draws anew on every run, and
/// the timestamps the mock seeds from the time the app was launched at.
final class AtlasJournalCleaner {
  static const _sequenceKey = 'seq';
  static const _anchorKey = 'anchor';
  static const _launchedAtKey = 'launchedAt';

  final AtlasJournalSchema _schema;

  const AtlasJournalCleaner(this._schema);

  /// Returns the [launch] record without the moments every stage holds beside
  /// its journal.
  static Map<String, Object?> withoutMoments(Map<String, Object?> launch) {
    return {
      for (final MapEntry(:key, :value) in launch.entries)
        if (key != _anchorKey && key != _launchedAtKey) key: value,
    };
  }

  /// Returns [records] without their sequence numbers and volatile keys.
  List<Object?> clean(Iterable<Object?> records) {
    return records.map(_cleanRecord).toList();
  }

  /// The record of the [launch] a snapshot opens its first stage with:
  /// cleaned, without the moments every stage holds beside its journal;
  /// absent without a launch.
  Map<String, Object?>? tryDescribeLaunch(Map<String, Object?>? launch) {
    if (launch == null) {
      return null;
    }

    final record = _cleanRecord(withoutMoments(launch));

    return record is Map<String, Object?> ? record : null;
  }

  Object? _cleanRecord(Object? record) {
    if (record is! Map<String, Object?>) {
      return _removeVolatileKeys(record);
    }

    return _removeVolatileKeys({
      for (final MapEntry(:key, :value) in record.entries)
        if (key != _sequenceKey) key: value,
    });
  }

  Object? _removeVolatileKeys(Object? node) {
    if (node is Map<String, Object?>) {
      return {
        for (final MapEntry(:key, :value) in node.entries)
          if (!_schema.volatileKeys.contains(key))
            key: _removeVolatileKeys(value),
      };
    }

    if (node is List<Object?>) {
      return node.map(_removeVolatileKeys).toList();
    }

    return node;
  }
}
