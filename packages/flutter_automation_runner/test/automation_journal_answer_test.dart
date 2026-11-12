import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_journal_answer.dart';

const _records = [
  {'seq': 0, 'kind': 'request', 'method': 'GET', 'path': '/baskets/1'},
  {'seq': 1, 'kind': 'state', 'cubit': 'BasketDetailsCubit'},
];

void main() {
  group('AutomationJournalAnswer Tests', () {
    _automationJournalAnswer_should_readRecords();
    _automationJournalAnswer_should_rejectMalformedAnswers();
    _automationJournalAnswer_should_readLaunchKeptBesideRecords();
  });
}

void _automationJournalAnswer_should_readRecords() {
  test('AutomationJournalAnswer should read records', () {
    final answer = AutomationJournalAnswer.fromJson({'records': _records});

    expect(answer.records, _records);
  });
}

void _automationJournalAnswer_should_rejectMalformedAnswers() {
  test('AutomationJournalAnswer should reject malformed answers', () {
    const malformedAnswers = [
      null,
      _records,
      {'screen': 'settings-route'},
      {
        'records': [
          {'seq': 0},
          'request',
        ],
      },
    ];

    for (final malformed in malformedAnswers) {
      expect(
        () => AutomationJournalAnswer.fromJson(malformed),
        throwsA(isA<StateError>()),
      );
    }
  });
}

void _automationJournalAnswer_should_readLaunchKeptBesideRecords() {
  test('AutomationJournalAnswer should read launch kept beside records', () {
    const launch = {
      'kind': 'launch',
      'features': ['auth'],
    };
    final answer = AutomationJournalAnswer.fromJson({
      'records': _records,
      'launch': launch,
    });
    final answerWithoutLaunch = AutomationJournalAnswer.fromJson({
      'records': _records,
      'launch': null,
    });

    expect(answer.launch, launch);
    expect(answerWithoutLaunch.launch, isNull);
  });
}
