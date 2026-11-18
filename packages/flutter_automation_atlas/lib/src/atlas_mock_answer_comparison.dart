import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_schema.dart';

/// {@category Utils}
///
/// Compares an answer of the mock a snapshot recorded with the answer the
/// current mock gives in its place, both cleaned the way a snapshot stores a
/// record.
///
/// Of a request record the `status` and, when the recording
/// holds one, the `response` are compared; of every other record each field
/// either holds. Two values differ unless they are equal, with two
/// exceptions the mock draws anew on every run:
///
/// - a date-time read off the mock's anchor or launch, when the stage holds
///   neither: a whole-hour difference is a shift of the anchor, which the
///   caller resolves by replaying on another anchor, and a difference of no
///   whole number of minutes is the launch moment, which only the recent
///   notifications are dated off, and is ignored;
/// - an id the mock issues as a uuid, which pairs the recorded id with the
///   issued one, so the caller asks later requests with the issued one.
final class AtlasMockAnswerComparison {
  static final _uuidPattern = RegExp(
    '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
  );
  static final _dateTimePattern = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}');
  static const _uuidPlaceholder = '<id>';
  static const _kindKey = 'kind';
  static const _statusKey = 'status';
  static const _responseKey = 'response';
  static const _shownValueLength = 60;

  final AtlasJournalSchema _schema;

  const AtlasMockAnswerComparison(this._schema);

  /// Compares the [recorded] answer with the [replayed] one.
  ///
  /// The [hasKnownMoments] parameter tells that the replay ran on the anchor
  /// and the launch moment the stage was captured on, so a date differs as any
  /// other value does.
  AtlasMockAnswerDifference compare({
    required Map<String, Object?> recorded,
    required Map<String, Object?> replayed,
    bool hasKnownMoments = false,
  }) {
    final difference = _DifferenceCollector(hasKnownMoments: hasKnownMoments);
    final comparedKeys = _schema.requestKinds.contains(recorded[_kindKey])
        ? [_statusKey, if (recorded.containsKey(_responseKey)) _responseKey]
        : {...recorded.keys, ...replayed.keys}.where((key) => key != _kindKey);

    for (final key in comparedKeys) {
      _compareNodes(recorded[key], replayed[key], key, difference);
    }

    return difference.build();
  }

  /// The [record] with every uuid [issuedIds] maps replaced by the id it maps
  /// to.
  static Map<String, Object?> substituteIssuedIds(
    Map<String, Object?> record,
    Map<String, String> issuedIds,
  ) {
    return {
      for (final MapEntry(:key, :value) in record.entries)
        key: _substituteIssuedIds(value, issuedIds),
    };
  }

  static void _compareNodes(
    Object? recorded,
    Object? replayed,
    String path,
    _DifferenceCollector difference,
  ) {
    if (difference.hasMismatch) {
      return;
    }

    switch ((recorded, replayed)) {
      case (final Map<String, Object?> left, final Map<String, Object?> right):
        _compareObjects(left, right, path, difference);
      case (final List<Object?> left, final List<Object?> right):
        _compareLists(left, right, path, difference);
      case (final String left, final String right):
        _compareStrings(left, right, path, difference);
      case _ when recorded != replayed:
        difference.addMismatch(_describe(path, recorded, replayed));
    }
  }

  static void _compareObjects(
    Map<String, Object?> recorded,
    Map<String, Object?> replayed,
    String path,
    _DifferenceCollector difference,
  ) {
    final keys = {...recorded.keys, ...replayed.keys};

    for (final key in keys) {
      _compareNodes(recorded[key], replayed[key], '$path.$key', difference);
    }
  }

  static void _compareLists(
    List<Object?> recorded,
    List<Object?> replayed,
    String path,
    _DifferenceCollector difference,
  ) {
    if (recorded.length != replayed.length) {
      difference.addMismatch(
        '$path holds ${recorded.length} items, now ${replayed.length}',
      );

      return;
    }

    for (final (index, item) in recorded.indexed) {
      _compareNodes(item, replayed[index], '$path[$index]', difference);
    }
  }

  static void _compareStrings(
    String recorded,
    String replayed,
    String path,
    _DifferenceCollector difference,
  ) {
    if (recorded == replayed) {
      return;
    }

    final shift = difference.hasKnownMoments
        ? null
        : _tryReadDateTimeShift(recorded, replayed);

    if (shift != null) {
      _addDateTimeShift(shift, path, difference, (recorded, replayed));

      return;
    }

    if (_isSameButIssuedIds(recorded, replayed)) {
      difference.addIssuedIds(_pairIssuedIds(recorded, replayed));

      return;
    }

    difference.addMismatch(_describe(path, recorded, replayed));
  }

  static Duration? _tryReadDateTimeShift(String recorded, String replayed) {
    if (!_dateTimePattern.hasMatch(recorded) ||
        !_dateTimePattern.hasMatch(replayed)) {
      return null;
    }

    final recordedDate = DateTime.tryParse(recorded);
    final replayedDate = DateTime.tryParse(replayed);

    if (recordedDate == null || replayedDate == null) {
      return null;
    }

    return recordedDate.difference(replayedDate);
  }

  static void _addDateTimeShift(
    Duration shift,
    String path,
    _DifferenceCollector difference,
    (String, String) values,
  ) {
    if (_isWhole(shift, const Duration(hours: 1))) {
      difference.addAnchorShift(shift);

      return;
    }

    if (!_isWhole(shift, const Duration(minutes: 1))) {
      return;
    }

    difference.addMismatch(_describe(path, values.$1, values.$2));
  }

  static bool _isSameButIssuedIds(String recorded, String replayed) {
    final recordedIds = _uuidPattern.allMatches(recorded).length;

    return recordedIds > 0 &&
        recordedIds == _uuidPattern.allMatches(replayed).length &&
        _maskIds(recorded) == _maskIds(replayed);
  }

  static Map<String, String> _pairIssuedIds(String recorded, String replayed) {
    final recordedIds = _readIds(recorded);
    final replayedIds = _readIds(replayed);

    return {
      for (final (index, recordedId) in recordedIds.indexed)
        recordedId: replayedIds[index],
    };
  }

  static bool _isWhole(Duration shift, Duration unit) {
    return shift.inMicroseconds % unit.inMicroseconds == 0;
  }

  static String _describe(String path, Object? recorded, Object? replayed) {
    return '$path ${_shorten(recorded)}, now ${_shorten(replayed)}';
  }

  static String _maskIds(String text) {
    return text.replaceAll(_uuidPattern, _uuidPlaceholder);
  }

  static List<String> _readIds(String text) {
    return _uuidPattern
        .allMatches(text)
        .map((match) => match[0])
        .nonNulls
        .toList();
  }

  static String _shorten(Object? value) {
    final text = jsonEncode(value);

    return text.length <= _shownValueLength
        ? text
        : '${text.substring(0, _shownValueLength)}…';
  }
}

/// {@category Utils}
///
/// How a replayed answer differs from the recorded one.
final class AtlasMockAnswerDifference {
  /// The whole-hour shifts of the dates read off the anchor, recorded minus
  /// replayed.
  final List<Duration> anchorShifts;

  /// The ids the recording holds mapped to the ids the mock issued in their
  /// place.
  final Map<String, String> issuedIds;

  /// The first value that differs and how, `null` when only the exceptions
  /// [AtlasMockAnswerComparison] names differ.
  final String? mismatch;

  const AtlasMockAnswerDifference({
    required this.anchorShifts,
    required this.issuedIds,
    this.mismatch,
  });

  /// A difference no anchor or issued id explains, described by [mismatch].
  const AtlasMockAnswerDifference.mismatch(String this.mismatch)
    : anchorShifts = const [],
      issuedIds = const {};

  /// Whether the answers are alike once the issued ids are paired.
  bool get isSame => mismatch == null && anchorShifts.isEmpty;

  /// The shift most dates moved by, `null` when none moved or a value
  /// differs otherwise.
  Duration? get modalAnchorShift {
    if (mismatch != null) {
      return null;
    }

    return AtlasMockAnswerDifference.findModalShift(anchorShifts);
  }

  /// How the answers differ, for the `stale` line.
  String describe() {
    return mismatch ??
        'dates ${anchorShifts.map((shift) => '${shift.inHours}h').toSet()} '
            'off the anchor';
  }

  /// The shift most of [shifts] are, `null` when there are none.
  static Duration? findModalShift(Iterable<Duration> shifts) {
    final counts = shifts.groupFoldBy<Duration, int>(
      (shift) => shift,
      (count, _) => (count ?? 0) + 1,
    );

    return maxBy(counts.entries, (entry) => entry.value)?.key;
  }
}

final class _DifferenceCollector {
  final bool hasKnownMoments;

  final List<Duration> _anchorShifts = [];
  final Map<String, String> _issuedIds = {};

  String? _mismatch;

  _DifferenceCollector({required this.hasKnownMoments});

  bool get hasMismatch => _mismatch != null;

  void addMismatch(String mismatch) => _mismatch ??= mismatch;

  void addAnchorShift(Duration shift) => _anchorShifts.add(shift);

  void addIssuedIds(Map<String, String> issuedIds) =>
      _issuedIds.addAll(issuedIds);

  AtlasMockAnswerDifference build() {
    return AtlasMockAnswerDifference(
      anchorShifts: List.unmodifiable(_anchorShifts),
      issuedIds: Map.unmodifiable(_issuedIds),
      mismatch: _mismatch,
    );
  }
}

Object? _substituteIssuedIds(Object? json, Map<String, String> issuedIds) {
  return switch (json) {
    final String text => text.replaceAllMapped(
      AtlasMockAnswerComparison._uuidPattern,
      (match) => issuedIds[match[0]] ?? match[0] ?? '',
    ),
    final Map<String, Object?> object => {
      for (final MapEntry(:key, :value) in object.entries)
        key: _substituteIssuedIds(value, issuedIds),
    },
    final List<Object?> list =>
      list.map((item) => _substituteIssuedIds(item, issuedIds)).toList(),
    _ => json,
  };
}
