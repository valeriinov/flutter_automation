import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_automation_mock/src/state/mock_journal.dart';
import 'package:flutter_test/flutter_test.dart';

const _capacity = 1024;
const _recordsToAdd = _capacity + 1;
const _requestPath = '/items/create';
const _channelPath = '/streams/main/sample-9001/query';
const _screenName = 'details-screen';
const _itemId = 42;

final _sut = MockJournal();

void main() {
  _setup();
  group('MockJournal Tests', () {
    _mockJournal_should_numberRecordsInTheOrderTheyWereAdded();
    _mockJournal_should_dropTheOldestRecordsOnceFull();
    _mockJournal_should_numberTheNextRecordFromZeroOnceEmptied();
    _mockJournal_should_storeTheFieldsAsTheJsonTheyEncodeTo();
    _mockJournal_should_carryAFieldAddedToTheReturnedRecord();
    _mockJournal_should_writeARequestRecordOfTheDefaultKind();
    _mockJournal_should_writeARequestRecordOfTheGivenKind();
    _mockJournal_should_keepTheLaunchRecordApartFromTheRecordsARead();
    _mockJournal_should_attachTheStatusAndTheBodyOfAResponse();
    _mockJournal_should_attachOnlyTheStatusOfAResponseWithAnEmptyBody();
    _mockJournal_should_waitForResponsesWhileARequestAwaitsItsAnswer();
    _mockJournal_should_completeWaitForResponsesOnceEveryRequestIsAnswered();
    _mockJournal_should_completeWaitForResponsesWithNoRequestAwaitingOne();
    _mockJournal_should_completeWaitForResponsesOnceEmptied();
  });
}

void _setup() {
  tearDown(() {
    _sut.clear();
  });
}

void _mockJournal_should_numberRecordsInTheOrderTheyWereAdded() {
  test('MockJournal should number records in the order they were added', () {
    _sut
      ..add(_TestRecordKind.request, {'path': _requestPath})
      ..add(_TestRecordKind.state, {'isLoading': true});

    expect(_sut.readAndClear(), [
      {'seq': 0, 'kind': 'request', 'path': _requestPath},
      {'seq': 1, 'kind': 'state', 'isLoading': true},
    ]);
  });
}

void _mockJournal_should_dropTheOldestRecordsOnceFull() {
  test('MockJournal should drop the oldest records once full', () {
    for (int index = 0; index < _recordsToAdd; index += 1) {
      _sut.add(_TestRecordKind.stream, {'path': '/streams/$index'});
    }

    final records = _sut.readAndClear();

    expect(records, hasLength(_capacity));
    expect(records.firstOrNull?['seq'], 1);
    expect(records.lastOrNull?['seq'], _capacity);
  });
}

void _mockJournal_should_numberTheNextRecordFromZeroOnceEmptied() {
  test('MockJournal should number the next record from zero once emptied', () {
    _sut
      ..add(_TestRecordKind.request, {'path': _requestPath})
      ..add(_TestRecordKind.request, {'path': _requestPath})
      ..clear()
      ..add(_TestRecordKind.request, {'path': _requestPath});

    final seqAfterClear = _sut.readAndClear().single['seq'];

    _sut.add(_TestRecordKind.request, {'path': _requestPath});

    final seqAfterRead = _sut.readAndClear().single['seq'];

    expect(seqAfterClear, 0);
    expect(seqAfterRead, 0);
  });
}

void _mockJournal_should_storeTheFieldsAsTheJsonTheyEncodeTo() {
  test('MockJournal should store the fields as the JSON they encode to', () {
    final parameters = <String, Object?>{'screen_name': _screenName};

    _sut.add(_TestRecordKind.detail, {
      'parameters': parameters,
      'sentAt': DateTime.utc(2026, 9, 17, 12),
    });
    parameters.clear();

    final record = _sut.readAndClear().single;

    expect(record['parameters'], {'screen_name': _screenName});
    expect(record['sentAt'], '2026-09-17 12:00:00.000Z');
  });
}

void _mockJournal_should_carryAFieldAddedToTheReturnedRecord() {
  test('MockJournal should carry a field added to the returned record', () {
    final record = _sut.add(_TestRecordKind.request, {'path': _requestPath});

    record['status'] = HttpStatus.ok;

    expect(_sut.readAndClear().single, containsPair('status', HttpStatus.ok));
  });
}

void _mockJournal_should_attachTheStatusAndTheBodyOfAResponse() {
  test('MockJournal should attach the status and the body of a response', () {
    final body = <String, Object?>{
      'data': {'itemId': _itemId},
    };
    final record = _sut.add(_TestRecordKind.request, {'path': _requestPath});

    _sut.attachResponse(record, statusCode: HttpStatus.ok, body: body);
    body.clear();

    final records = _sut.readAndClear();

    expect(records, [
      {
        'seq': 0,
        'kind': 'request',
        'path': _requestPath,
        'status': HttpStatus.ok,
        'response': {
          'data': {'itemId': _itemId},
        },
      },
    ]);
  });
}

void _mockJournal_should_attachOnlyTheStatusOfAResponseWithAnEmptyBody() {
  test('MockJournal should attach only the status of '
      'a response with an empty body', () {
    final record = _sut.add(_TestRecordKind.stream, {'path': _requestPath});

    _sut.attachResponse(record, statusCode: HttpStatus.noContent, body: {});

    final records = _sut.readAndClear();

    expect(records, [
      {
        'seq': 0,
        'kind': 'stream',
        'path': _requestPath,
        'status': HttpStatus.noContent,
      },
    ]);
  });
}

void _mockJournal_should_waitForResponsesWhileARequestAwaitsItsAnswer() {
  test(
    'MockJournal should wait for responses while a request awaits its answer',
    () async {
      _sut.addRequest({'path': _requestPath});

      await expectLater(
        _sut.waitForResponses().timeout(Duration.zero),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}

void _mockJournal_should_completeWaitForResponsesOnceEveryRequestIsAnswered() {
  test('MockJournal should complete wait for responses '
      'once every request is answered', () async {
    final request = _sut.addRequest({'path': _requestPath});
    final stream = _sut.addRequest({
      'path': _channelPath,
    }, kind: _TestRecordKind.stream);
    final responses = _sut.waitForResponses();

    _sut.attachResponse(request, statusCode: HttpStatus.ok, body: {});

    final awaitingWithOneAnswer = _sut.requestsAwaitingResponse;

    _sut.attachResponse(stream, statusCode: HttpStatus.ok, body: {});

    await expectLater(responses, completes);

    final awaitingWithBothAnswers = _sut.requestsAwaitingResponse;

    expect(awaitingWithOneAnswer, [stream]);
    expect(awaitingWithBothAnswers, isEmpty);
  });
}

void _mockJournal_should_completeWaitForResponsesWithNoRequestAwaitingOne() {
  test('MockJournal should complete wait for responses '
      'with no request awaiting one', () async {
    _sut.add(_TestRecordKind.state, {'isLoading': true});

    await expectLater(_sut.waitForResponses(), completes);
  });
}

void _mockJournal_should_completeWaitForResponsesOnceEmptied() {
  test('MockJournal should complete wait for responses once emptied', () async {
    _sut.addRequest({'path': _requestPath});

    final responses = _sut.waitForResponses();

    _sut.clear();

    await expectLater(responses, completes);

    final awaitingOnceEmptied = _sut.requestsAwaitingResponse;

    expect(awaitingOnceEmptied, isEmpty);
  });
}

void _mockJournal_should_writeARequestRecordOfTheDefaultKind() {
  test('MockJournal should write a request record of the default kind', () {
    _sut.addRequest({'path': _requestPath});

    final record = _sut.readAndClear().single;

    expect(record, {'seq': 0, 'kind': 'request', 'path': _requestPath});
  });
}

void _mockJournal_should_writeARequestRecordOfTheGivenKind() {
  test('MockJournal should write a request record of the given kind', () {
    final record = _sut.addRequest({
      'path': _channelPath,
    }, kind: _TestRecordKind.stream);

    expect(record, containsPair('kind', 'stream'));
    expect(_sut.requestsAwaitingResponse, [record]);
  });
}

void _mockJournal_should_keepTheLaunchRecordApartFromTheRecordsARead() {
  test(
    'MockJournal should keep the launch record apart from the records a read',
    () {
      _sut.recordLaunch(_TestRecordKind.detail, {'language': 'en'});

      final records = _sut.readAndClear();

      expect(records, isEmpty);
      expect(_sut.launch, {'kind': 'detail', 'language': 'en'});
    },
  );
}

enum _TestRecordKind { request, stream, state, detail }
