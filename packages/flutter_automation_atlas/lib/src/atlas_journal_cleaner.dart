import 'package:flutter_automation_atlas/src/atlas_journal_schema.dart';

/// {@category Utils}
///
/// Strips a journal record of what differs between two runs of the same walk,
/// so a snapshot changes only when the app does.
///
/// The cleaner removes the keys of [AtlasJournalSchema.volatileKeys] at every
/// depth of a record. These keys hold the values that the app or an SDK
/// stand-in draws anew on every run, and the timestamps that the mock seeds
/// from the launch time of the app.
///
/// A script of a project cleans journal records with the cleaner of its
/// journal schema:
///
/// ```dart
/// final cleaner = AtlasJournalCleaner(project.journalSchema);
/// final records = cleaner.clean(journal);
/// ```
final class AtlasJournalCleaner {
  static const _sequenceKey = 'seq';
  static const _anchorKey = 'anchor';
  static const _launchedAtKey = 'launchedAt';

  final AtlasJournalSchema _schema;

  /// Takes the journal schema of the project. The schema names the volatile
  /// keys that the cleaner removes.
  const AtlasJournalCleaner(this._schema);

  /// Returns the [launch] record without its `anchor` and `launchedAt`
  /// moments. Each stage of a snapshot holds these moments beside its
  /// journal.
  static Map<String, Object?> withoutMoments(Map<String, Object?> launch) {
    return {
      for (final MapEntry(:key, :value) in launch.entries)
        if (key != _anchorKey && key != _launchedAtKey) key: value,
    };
  }

  /// Returns [records] in their order, each without its sequence number
  /// `seq` and without the volatile keys of the schema. A record that is not
  /// a map loses only the volatile keys inside it.
  List<Object?> clean(Iterable<Object?> records) {
    return records.map(_cleanRecord).toList();
  }

  /// Returns the record that a snapshot opens its first stage with: the
  /// [launch] record, cleaned as [clean] does and without the moments that
  /// [withoutMoments] removes. Returns `null` when [launch] is `null`.
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
