import 'dart:convert';

import 'package:collection/collection.dart';

import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_schema.dart';

/// {@category Utils}
///
/// Compares two journals of one stage the way a capture tells them apart: the
/// same records in another order are the same journal, since the requests and
/// the analytics of a stage finish in whichever order (`AtlasJournalOrder`
/// keeps the stored order for them). A uuid is drawn anew on every run, by the
/// mock for an id it issues and by an SDK for an id it sends, so any uuid
/// equals any other. An install value is issued once
/// per install of the app, and a generated value, such as the name of an
/// attachment, is drawn for each thing it names, so any of either equals any
/// other as well ([AtlasJournalSchema.installValue] and
/// [AtlasJournalSchema.generatedValue]).
final class AtlasJournalComparison {
  static const _equality = UnorderedIterableEquality<String>();
  static const _kindKey = 'kind';
  static const _shownPathCount = 3;
  static const _uuidPlaceholder = '<uuid>';
  static final _uuidPattern = RegExp(
    '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
  );

  final List<String> _identityKeys;
  final RegExp _installValuePattern;
  final String _installValuePlaceholder;
  final RegExp _generatedValuePattern;
  final String _generatedValuePlaceholder;

  AtlasJournalComparison(AtlasJournalSchema schema)
    : _identityKeys = ['method', 'path', 'call', 'name', schema.stateKey],
      _installValuePattern = RegExp(schema.installValue.pattern),
      _installValuePlaceholder = schema.installValue.placeholder,
      _generatedValuePattern = RegExp(schema.generatedValue.pattern),
      _generatedValuePlaceholder = schema.generatedValue.placeholder;

  /// Whether [left] and [right] hold the same records.
  bool isSame(List<Object?> left, List<Object?> right) {
    return _equality.equals(_encode(left), _encode(right));
  }

  /// Hashes [journal] so that two journals [isSame] tells alike hash alike.
  String hash(List<Object?> journal) {
    final records = _encode(journal)..sort();

    return AtlasContentHash.hashJson(records);
  }

  /// What [walked] holds otherwise than [recorded]: the first record either
  /// holds alone, named by its kind and identity, with the fields it differs
  /// in from the record of the same identity on the other side; absent when
  /// both hold the same records.
  String? tryDescribeDifference({
    required List<Object?> recorded,
    required List<Object?> walked,
  }) {
    final recordedOnly = _subtract(recorded, walked);
    final walkedOnly = _subtract(walked, recorded);
    final record = recordedOnly.firstOrNull ?? walkedOnly.firstOrNull;

    if (record == null) {
      return null;
    }

    final isRecorded = recordedOnly.isNotEmpty;
    final counterpart = (isRecorded ? walkedOnly : recordedOnly)
        .firstWhereOrNull((other) => _isSameIdentity(record, other));
    final identity = _describeIdentity(record);

    if (counterpart == null) {
      return isRecorded ? '$identity not walked' : '$identity not recorded';
    }

    final paths = _readDifferingPaths(
      isRecorded ? record : counterpart,
      isRecorded ? counterpart : record,
      '',
    );

    return '$identity ${paths.take(_shownPathCount).join(', ')}';
  }

  /// The first install value [records] hold, absent when they hold none.
  String? tryFindInstallValue(Iterable<Object?> records) {
    return records
        .map((record) => _installValuePattern.firstMatch(jsonEncode(record)))
        .nonNulls
        .firstOrNull
        ?.group(0);
  }

  /// The first record [walked] holds otherwise than [recorded] that holds a
  /// value only the walk drew — a uuid or a generated value [recorded]
  /// does not hold, or an install value when the device recorded none to write
  /// in its place — named by its kind and identity and the value; absent when
  /// [keepRecorded] writes [walked] as the device would.
  String? tryDescribeWalkValue({
    required List<Object?> walked,
    required List<Object?> recorded,
    required String? installValue,
  }) {
    final recordedSource = jsonEncode(recorded);

    return _subtract(walked, recorded)
        .map(
          (record) => switch (_tryFindWalkValue(
            jsonEncode(record),
            recordedSource,
            installValue,
          )) {
            final value? => '${_describeIdentity(record)} holds $value',
            null => null,
          },
        )
        .nonNulls
        .firstOrNull;
  }

  /// The journals of every stage of a variant, [walked] all on one walk, as
  /// the device that recorded [recorded] writes them: each generated
  /// value the walk drew is the one the device recorded in its place, in the
  /// order the journals first hold them, and every install value is
  /// [installValue], the value of that device. Absent when the walk holds an
  /// install value and the device recorded none, or the walk and the device
  /// hold another number of generated values.
  List<List<Object?>>? tryRewriteWalk({
    required List<List<Object?>> walked,
    required List<List<Object?>> recorded,
    required String? installValue,
  }) {
    final walkedSources = walked.map(jsonEncode).toList();
    final walkNames = _readGeneratedValues(walkedSources);
    final recordedNames = _readGeneratedValues(recorded.map(jsonEncode));
    final hasWalkInstallValue = walkedSources.any(
      _installValuePattern.hasMatch,
    );

    if (walkNames.length != recordedNames.length) {
      return null;
    }

    if (installValue == null && hasWalkInstallValue) {
      return null;
    }

    return [
      for (final source in walkedSources)
        _decodeJournal(
          source
              .replaceAll(_installValuePattern, installValue ?? '')
              .replaceAllMapped(
                _generatedValuePattern,
                (match) =>
                    recordedNames[walkNames.indexOf('${match.group(0)}')],
              ),
        ),
    ];
  }

  /// [walked] as the device that recorded [recorded] writes it: a record
  /// [recorded] holds alike is taken as recorded, and every install value of
  /// any other record is [installValue], the value of that device, when given.
  List<Object?> keepRecorded({
    required List<Object?> walked,
    required List<Object?> recorded,
    required String? installValue,
  }) {
    final remaining = [...recorded];

    return [
      for (final record in _withInstallValue(walked, installValue))
        if (_tryFindAlikeIndex(record, remaining) case final index?)
          remaining.removeAt(index)
        else
          record,
    ];
  }

  bool _isSameIdentity(Object? record, Object? other) {
    if (record is! Map<String, Object?> || other is! Map<String, Object?>) {
      return false;
    }

    return [
      _kindKey,
      ..._identityKeys,
    ].every((key) => record[key] == other[key]);
  }

  List<String> _readDifferingPaths(
    Object? recorded,
    Object? walked,
    String path,
  ) {
    if (recorded is Map<String, Object?> && walked is Map<String, Object?>) {
      return [
        for (final key in {...recorded.keys, ...walked.keys})
          ..._readDifferingPaths(
            recorded[key],
            walked[key],
            path.isEmpty ? key : '$path.$key',
          ),
      ];
    }

    final isSame = _encodeRecord(recorded) == _encodeRecord(walked);

    return isSame ? const [] : [path];
  }

  List<Object?> _subtract(List<Object?> from, List<Object?> records) {
    final remaining = _encode(records);

    return [
      for (final record in from)
        if (!remaining.remove(_encodeRecord(record))) record,
    ];
  }

  String? _tryFindWalkValue(
    String recordSource,
    String recordedSource,
    String? installValue,
  ) {
    final installValueMatch = _installValuePattern.firstMatch(recordSource);

    if (installValue == null && installValueMatch != null) {
      return installValueMatch.group(0);
    }

    return [
          ..._uuidPattern.allMatches(recordSource),
          ..._generatedValuePattern.allMatches(recordSource),
        ]
        .map((match) => match.group(0))
        .nonNulls
        .firstWhereOrNull((value) => !recordedSource.contains(value));
  }

  String _describeIdentity(Object? record) {
    if (record is! Map<String, Object?>) {
      return '$record';
    }

    return [
      for (final key in [_kindKey, ..._identityKeys]) ?record[key],
    ].join(' ');
  }

  List<String> _readGeneratedValues(Iterable<String> sources) {
    return {
      for (final source in sources)
        for (final match in _generatedValuePattern.allMatches(source))
          ?match.group(0),
    }.toList();
  }

  List<Object?> _withInstallValue(List<Object?> journal, String? installValue) {
    if (installValue == null) {
      return journal;
    }

    return _decodeJournal(
      jsonEncode(journal).replaceAll(_installValuePattern, installValue),
    );
  }

  int? _tryFindAlikeIndex(Object? record, List<Object?> remaining) {
    final encoded = _encodeRecord(record);
    final index = remaining.indexWhere(
      (other) => _encodeRecord(other) == encoded,
    );

    if (index < 0) {
      return null;
    }

    return index;
  }

  List<String> _encode(List<Object?> journal) {
    return journal.map(_encodeRecord).toList();
  }

  List<Object?> _decodeJournal(String source) {
    return switch (jsonDecode(source)) {
      final List<Object?> journal => journal,
      _ => const [],
    };
  }

  String _encodeRecord(Object? record) {
    return AtlasContentHash.encodeCanonicalJson(record)
        .replaceAll(_installValuePattern, _installValuePlaceholder)
        .replaceAll(_generatedValuePattern, _generatedValuePlaceholder)
        .replaceAll(_uuidPattern, _uuidPlaceholder);
  }
}
