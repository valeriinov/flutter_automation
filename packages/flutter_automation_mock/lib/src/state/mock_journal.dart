import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_automation_mock/src/state/mock_request_record_kind.dart';

/// {@category Utils}
///
/// What the app did while a run walked it, in the order it happened.
///
/// Every part of the mock that sees the app act writes a record here. A capture
/// run reads the records before each user action and after each step. A record
/// is a JSON object. Its `seq` orders it, and its `kind` names the fields it
/// carries. The kind is a value of an enum that the project declares.
///
/// The mock writes a request before it answers it. [waitForResponses] lets a
/// reader take the records only once each request among them carries its
/// answer.
///
/// The journal keeps the newest records only and drops the oldest one once it
/// is full. A run that never reads it again therefore holds a bounded amount of
/// memory.
class MockJournal {
  static const _capacity = 1024;
  static const _seqKey = 'seq';
  static const _kindKey = 'kind';
  static const _statusKey = 'status';
  static const _responseKey = 'response';

  final ListQueue<Map<String, Object?>> _records = ListQueue();
  final Set<Map<String, Object?>> _requestsAwaitingResponse = Set.identity();

  int _nextSeq = 0;

  Map<String, Object?>? _launch;
  Completer<void>? _responsesCompleter;

  /// The record of the launch, kept apart from the records that a read empties.
  /// The mock writes it before a run reads the journal for the first time.
  Map<String, Object?>? get launch => _launch;

  /// Records written through [addRequest] that carry no answer yet.
  List<Map<String, Object?>> get requestsAwaitingResponse {
    return List.unmodifiable(_requestsAwaitingResponse);
  }

  /// Writes a record of [kind] that carries [fields] and returns it.
  ///
  /// The journal stores [fields] as the JSON they encode to, so a record reads
  /// the same whenever a reader reads it. The record returned is the one
  /// stored. A writer uses it to add a field that it learns later. An example
  /// is the answer that [attachResponse] writes onto a request that the mock
  /// answers after its delay.
  Map<String, Object?> add(Enum kind, Map<String, Object?> fields) {
    final record = <String, Object?>{
      _seqKey: _nextSeq++,
      _kindKey: kind.name,
      ..._toJsonObject(fields),
    };

    _records.addLast(record);

    if (_records.length > _capacity) {
      _records.removeFirst();
    }

    return record;
  }

  /// Writes a record for a request the mock is about to answer and returns it.
  ///
  /// [waitForResponses] waits on the record until [attachResponse] writes the
  /// answer onto it.
  ///
  /// The record is of the kind `request` unless the [kind] parameter names
  /// another one.
  Map<String, Object?> addRequest(
    Map<String, Object?> fields, {
    Enum kind = MockRequestRecordKind.request,
  }) {
    final record = add(kind, fields);

    _requestsAwaitingResponse.add(record);

    return record;
  }

  /// Keeps [fields] as the launch record of the kind [kind].
  ///
  /// The new record replaces the kept one.
  void recordLaunch(Enum kind, Map<String, Object?> fields) {
    _launch = {_kindKey: kind.name, ..._toJsonObject(fields)};
  }

  /// Writes onto a request [record] the [statusCode] of its answer and the
  /// [body] of the answer. It writes the body only when the body carries a key.
  void attachResponse(
    Map<String, Object?> record, {
    required int statusCode,
    required Map<String, Object?> body,
  }) {
    record[_statusKey] = statusCode;

    if (body.isNotEmpty) {
      record[_responseKey] = _toJsonObject(body);
    }

    _requestsAwaitingResponse.remove(record);
    _maybeCompleteResponses();
  }

  /// Completes once every record written through [addRequest] carries its
  /// answer.
  Future<void> waitForResponses() {
    if (_requestsAwaitingResponse.isEmpty) {
      return Future.value();
    }

    final completer = _responsesCompleter ??= Completer<void>();

    return completer.future;
  }

  /// Returns every record, oldest first, and empties the journal.
  List<Map<String, Object?>> readAndClear() {
    final records = List<Map<String, Object?>>.of(_records, growable: false);

    clear();

    return records;
  }

  /// Empties the journal and numbers the next record from zero.
  void clear() {
    _records.clear();
    _requestsAwaitingResponse.clear();

    _nextSeq = 0;

    _maybeCompleteResponses();
  }

  void _maybeCompleteResponses() {
    final completer = _responsesCompleter;

    if (completer == null || _requestsAwaitingResponse.isNotEmpty) {
      return;
    }

    _responsesCompleter = null;

    completer.complete();
  }

  static Map<String, Object?> _toJsonObject(Map<String, Object?> fields) {
    final json = jsonDecode(
      jsonEncode(fields, toEncodable: _describeUnencodableValue),
    );

    return json is Map<String, Object?> ? json : const {};
  }

  static String _describeUnencodableValue(Object? value) => value.toString();
}
