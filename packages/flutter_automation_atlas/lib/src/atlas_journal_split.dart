import 'package:collection/collection.dart';

import 'package:flutter_automation_atlas/src/atlas_journal_schema.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';

/// {@category Utils}
///
/// Splits the journal of a stage into what its action produced and what the
/// screen the action opened produced while opening.
///
/// A stage opens a screen when it logged a screen view of a screen other
/// than its own; otherwise every record belongs to the action. When it does,
/// the opening holds every screen view, the analytics logged on the
/// destination screen and the states of every owner created within the stage.
/// A record naming no screen of its own follows the record it comes after: an
/// analytics copy without a screen name follows the nearest earlier event of
/// the same name, a request the nearest earlier state
/// ([AtlasJournalSchema]).
final class AtlasJournalSplit {
  final AtlasJournalSchema _schema;

  const AtlasJournalSplit(this._schema);

  /// Splits the [journal] of a stage, keeping the order of its records.
  ///
  /// The [screen] parameter is the screen the stage's action was taken on and
  /// the [destination] parameter is the screen the next stage, or the end of
  /// the run, was logged on.
  ({List<Object?> afterAction, List<Object?> onScreenOpen}) split({
    required List<Object?> journal,
    required String? screen,
    required String? destination,
  }) {
    final stageJournal = _StageJournal(
      journal.map(_readRecord).toList(),
      destination,
      _schema,
    );

    if (!stageJournal.hasScreenViewOtherThan(screen)) {
      return (afterAction: journal, onScreenOpen: const []);
    }

    final isOnScreenOpen = List.generate(
      journal.length,
      stageJournal.isOnScreenOpen,
    );

    return (
      afterAction: [
        for (final (index, record) in journal.indexed)
          if (!isOnScreenOpen[index]) record,
      ],
      onScreenOpen: [
        for (final (index, record) in journal.indexed)
          if (isOnScreenOpen[index]) record,
      ],
    );
  }

  static Map<String, Object?> _readRecord(Object? record) {
    return record is Map<String, Object?> ? record : const {};
  }
}

final class _StageJournal {
  static const _kindKey = 'kind';
  static const _nameKey = 'name';

  final List<Map<String, Object?>> _records;
  final Set<Object?> _createdOwners;
  final String? _destination;
  final AtlasJournalSchema _schema;

  _StageJournal(this._records, this._destination, this._schema)
    : _createdOwners = _records
          .where((record) => _isCreatedState(record, _schema))
          .map((record) => record[_schema.stateKey])
          .toSet();

  bool hasScreenViewOtherThan(String? screen) {
    return _records.any(
      (record) => _isScreenView(record) && _tryReadScreenName(record) != screen,
    );
  }

  bool isOnScreenOpen(int index) {
    final record = _records[index];
    final kind = record[_kindKey];

    if (kind == _schema.analyticsKind) {
      return _isAnalyticsOnScreenOpen(index, record);
    }

    if (kind == _schema.stateKind) {
      return _createdOwners.contains(record[_schema.stateKey]);
    }

    if (_schema.requestKinds.contains(kind)) {
      return _isNearestEarlierOnScreenOpen(index, _isState);
    }

    return false;
  }

  static bool _isCreatedState(
    Map<String, Object?> record,
    AtlasJournalSchema schema,
  ) {
    return record[_kindKey] == schema.stateKind &&
        record[schema.createdKey] == true;
  }

  bool _isScreenView(Map<String, Object?> record) {
    return _isAnalytics(record) && record[_nameKey] == _schema.screenViewName;
  }

  bool _isAnalyticsOnScreenOpen(int index, Map<String, Object?> record) {
    if (record[_nameKey] == _schema.screenViewName) {
      return true;
    }

    final screenName = _tryReadScreenName(record);

    if (screenName == null) {
      return _isNearestEarlierOnScreenOpen(
        index,
        (earlier) => _isSameAnalyticsEvent(earlier, record),
      );
    }

    return screenName == _destination;
  }

  bool _isState(Map<String, Object?> record) {
    return record[_kindKey] == _schema.stateKind;
  }

  String? _tryReadScreenName(Map<String, Object?> record) {
    final parameters = AtlasJson.tryReadObject(record, _schema.parametersKey);

    return parameters == null
        ? null
        : AtlasJson.tryReadString(parameters, _schema.screenNameParameter);
  }

  bool _isNearestEarlierOnScreenOpen(
    int index,
    bool Function(Map<String, Object?> record) test,
  ) {
    final earlierIndex = _records.indexed
        .take(index)
        .lastWhereOrNull((entry) => test(entry.$2))
        ?.$1;

    return earlierIndex != null && isOnScreenOpen(earlierIndex);
  }

  bool _isSameAnalyticsEvent(
    Map<String, Object?> earlier,
    Map<String, Object?> record,
  ) {
    return _isAnalytics(earlier) && earlier[_nameKey] == record[_nameKey];
  }

  bool _isAnalytics(Map<String, Object?> record) {
    return record[_kindKey] == _schema.analyticsKind;
  }
}
