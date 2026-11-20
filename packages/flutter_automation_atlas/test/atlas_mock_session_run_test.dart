import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_mock_replay.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replayer.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_session.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_session_run.dart';

import 'test_utils/fake_atlas_project.dart';

const _delay = Duration(seconds: 1);
final _anchor = DateTime.utc(2026, 10, 6, 9);

const _input = AtlasMockReplayInput(
  id: 'shop_flow/shopFromSearch',
  scenario: {'mode': 'full'},
  locale: 'uk',
  answers: [
    AtlasRecordedAnswer(
      stage: 0,
      record: {
        'kind': 'request',
        'method': 'GET',
        'path': '/items',
        'status': 200,
        'response': {'count': 2},
      },
    ),
    AtlasRecordedAnswer(
      stage: 1,
      record: {'kind': 'push', 'call': 'value', 'count': 3},
    ),
  ],
);

void main() {
  group('AtlasMockSessionRun Tests', () {
    _atlasMockSessionRun_should_replayEveryAnswerInOrderAndCloseSession();
    _atlasMockSessionRun_should_handContextToFactory();
    _atlasMockSessionRun_should_replayImpliedAnswersFirstInStageZero();
    _atlasMockSessionRun_should_tellAnswerAsRecordedFromDifferentOne();
    _atlasMockSessionRun_should_reportAnswerThatThrew();
    _atlasMockSessionRun_should_waitOutLazyAnswerBeforeTakingJournal();
    _atlasMockSessionRun_should_fireTimersBeforePushedValueOnLazyTiming();
    _atlasMockSessionRun_should_leaveTimersAloneBeforeUnpushedValue();
    _atlasMockSessionRun_should_dropMomentsOfReplayedLaunchRecord();
    _atlasMockSessionRun_should_cleanImpliedAnswers();
    _atlasMockSessionRun_should_reportAnswerThatThrewSynchronously();
    _atlasMockSessionRun_should_runMicrotasksOfFactoryBeforeFirstAsk();
  });
}

void _atlasMockSessionRun_should_replayEveryAnswerInOrderAndCloseSession() {
  test('AtlasMockSessionRun should replay every answer in order and close '
      'the session', () {
    final session = _FakeSession();
    final answers = _run(session);

    expect(session.asked.map((record) => record['kind']), ['request', 'push']);
    expect(answers.map((answer) => answer.stage), [0, 1]);
    expect(answers.map((answer) => answer.request), ['GET /items', 'push']);
    expect(answers.every((answer) => answer.difference.isSame), isTrue);
    expect(session.isClosed, isTrue);
  });
}

void _atlasMockSessionRun_should_handContextToFactory() {
  test('AtlasMockSessionRun should hand context to factory', () {
    AtlasMockSessionContext? context;

    _run(
      _FakeSession(),
      isLazy: true,
      onContext: (created) => context = created,
    );
    expect(context?.scenario, {'mode': 'full'});
    expect(context?.locale, 'uk');
    expect(context?.recordedAnswers.map((record) => record['kind']), [
      'request',
      'push',
    ]);
    expect(context?.anchor, _anchor);
    expect(context?.launchedAt, isNull);
    expect(context?.isLazy, isTrue);
  });
}

void _atlasMockSessionRun_should_replayImpliedAnswersFirstInStageZero() {
  test('AtlasMockSessionRun should replay implied answers first in stage '
      'zero', () {
    final session = _FakeSession(
      implied: const [
        {'kind': 'launch'},
      ],
    );
    final answers = _run(session);

    expect(session.asked.map((record) => record['kind']), [
      'launch',
      'request',
      'push',
    ]);
    expect(answers.map((answer) => answer.stage), [0, 0, 1]);
    expect(answers.map((answer) => answer.request), [
      'launch',
      'GET /items',
      'push',
    ]);
  });
}

void _atlasMockSessionRun_should_tellAnswerAsRecordedFromDifferentOne() {
  test('AtlasMockSessionRun should tell answer as recorded from different '
      'one', () {
    final answers = _run(_FakeSession(status: 500));

    expect(answers.first.difference.isSame, isFalse);
    expect(answers.last.difference.isSame, isTrue);
  });
}

void _atlasMockSessionRun_should_reportAnswerThatThrew() {
  test('AtlasMockSessionRun should report answer that threw', () {
    final answers = _run(_FakeSession(failure: StateError('no stand-in')));

    expect(answers.first.difference.mismatch, contains('no stand-in'));
    expect(answers.first.difference.mismatch, startsWith('failed:'));
  });
}

void _atlasMockSessionRun_should_waitOutLazyAnswerBeforeTakingJournal() {
  test('AtlasMockSessionRun should wait out lazy answer before taking '
      'journal', () {
    final session = _FakeSession(answerAfter: _delay);

    _run(session, isLazy: true);
    expect(session.journalSizesAtTake, [1, 1]);
  });
}

void _atlasMockSessionRun_should_fireTimersBeforePushedValueOnLazyTiming() {
  test('AtlasMockSessionRun should fire timers before pushed value on lazy '
      'timing', () {
    final session = _FakeSession(isPushed: true);

    _run(session, isLazy: true);
    expect(session.firedAtAsk, [false, true]);
  });
}

void _atlasMockSessionRun_should_leaveTimersAloneBeforeUnpushedValue() {
  test('AtlasMockSessionRun should leave timers alone before unpushed '
      'value', () {
    final session = _FakeSession();

    _run(session, isLazy: true);
    expect(session.firedAtAsk, [false, false]);
  });
}

void _atlasMockSessionRun_should_dropMomentsOfReplayedLaunchRecord() {
  test('AtlasMockSessionRun should drop moments of a replayed launch '
      'record', () {
    final answers = _run(
      _FakeSession(),
      input: _launchInput,
      echoed: (record) => {
        ...record,
        'anchor': '2026-10-06T09:00:00.000Z',
        'launchedAt': '2026-10-06T13:00:44.058Z',
      },
    );

    expect(answers.single.difference.isSame, isTrue);
  });
}

void _atlasMockSessionRun_should_cleanImpliedAnswers() {
  test('AtlasMockSessionRun should clean implied answers', () {
    final answers = _run(
      _FakeSession(
        implied: const [
          {
            'kind': 'launch',
            'features': ['shop'],
            'anchor': '2026-10-06T09:00:00.000Z',
            'launchedAt': '2026-10-06T13:00:44.058Z',
            'session_id': 'abc',
          },
        ],
      ),
      input: _noAnswersInput,
      echoed: (record) => {
        'kind': record['kind'],
        'features': ['shop'],
      },
    );

    expect(answers.single.difference.isSame, isTrue);
  });
}

void _atlasMockSessionRun_should_reportAnswerThatThrewSynchronously() {
  test('AtlasMockSessionRun should report an answer that threw '
      'synchronously', () {
    final answers = _run(_SyncThrowSession());

    expect(answers.first.difference.mismatch, startsWith('failed:'));
    expect(answers.first.difference.mismatch, contains('sync'));
  });
}

void _atlasMockSessionRun_should_runMicrotasksOfFactoryBeforeFirstAsk() {
  test('AtlasMockSessionRun should run microtasks of the factory before the '
      'first ask', () {
    final session = _FakeSession();
    bool isReady = false;

    _run(
      session,
      onContext: (_) => scheduleMicrotask(() => isReady = true),
      onAsk: () => session.readyAtAsk.add(isReady),
    );
    expect(session.readyAtAsk, [true, true]);
  });
}

const _launchInput = AtlasMockReplayInput(
  id: 'shop_flow/shopFromSearch',
  scenario: {},
  locale: 'uk',
  answers: [
    AtlasRecordedAnswer(
      stage: 0,
      record: {
        'kind': 'launch',
        'features': ['shop'],
      },
    ),
  ],
);

const _noAnswersInput = AtlasMockReplayInput(
  id: 'shop_flow/shopFromSearch',
  scenario: {},
  locale: 'uk',
  answers: [],
);

List<AtlasReplayedAnswer> _run(
  AtlasMockSession session, {
  AtlasMockReplayInput input = _input,
  Map<String, Object?> Function(Map<String, Object?> record)? echoed,
  void Function()? onAsk,
  bool isLazy = false,
  void Function(AtlasMockSessionContext context)? onContext,
}) {
  if (session is _FakeSession) {
    session
      ..echoed = echoed
      ..onAsk = onAsk;
  }

  return AtlasMockSessionRun(
    input,
    (anchor: _anchor, launchedAt: null, isLazy: isLazy),
    (context) {
      onContext?.call(context);

      return session;
    },
    fakeAtlasJournalSchema,
  ).run();
}

final class _FakeSession extends AtlasMockSession {
  final List<Map<String, Object?>> implied;
  final int status;
  final Object? failure;
  final Duration? answerAfter;
  final bool isPushed;
  final List<Map<String, Object?>> asked = [];
  final List<int> journalSizesAtTake = [];
  final List<bool> firedAtAsk = [];
  final List<bool> readyAtAsk = [];
  final List<Map<String, Object?>> _journal = [];

  Map<String, Object?> Function(Map<String, Object?> record)? echoed;
  void Function()? onAsk;
  bool isClosed = false;
  bool _hasTimerFired = false;

  _FakeSession({
    this.implied = const [],
    this.status = 200,
    this.failure,
    this.answerAfter,
    this.isPushed = false,
  });

  @override
  Future<Object?> ask(Map<String, Object?> record) async {
    asked.add(record);
    onAsk?.call();
    firedAtAsk.add(_hasTimerFired);

    Timer(const Duration(hours: 1), () => _hasTimerFired = true);

    if (failure case final error?) {
      throw error;
    }

    if (answerAfter case final delay?) {
      await Future<void>.delayed(delay);
    }

    _journal.add({
      ...(echoed?.call(record) ?? record),
      if (record['kind'] == 'request') 'status': status,
    });

    return null;
  }

  @override
  List<Map<String, Object?>> takeJournal() {
    journalSizesAtTake.add(_journal.length);

    final taken = [..._journal];

    _journal.clear();

    return taken;
  }

  @override
  Map<String, Object?>? findReplayed(
    Map<String, Object?> record,
    List<Map<String, Object?>> journal,
  ) {
    return journal.isEmpty ? null : journal.last;
  }

  @override
  String describe(Map<String, Object?> record) {
    return switch (record['kind']) {
      'request' => 'GET /items',
      final kind => '$kind',
    };
  }

  @override
  Future<void> close() async => isClosed = true;

  @override
  List<Map<String, Object?>> impliedAnswers() => implied;

  @override
  bool isPushedValue(Map<String, Object?> record) {
    return isPushed && record['kind'] == 'push';
  }
}

final class _SyncThrowSession extends AtlasMockSession {
  @override
  Future<Object?> ask(Map<String, Object?> record) {
    throw StateError('sync failure');
  }

  @override
  List<Map<String, Object?>> takeJournal() => const [];

  @override
  Map<String, Object?>? findReplayed(
    Map<String, Object?> record,
    List<Map<String, Object?>> journal,
  ) {
    return null;
  }

  @override
  String describe(Map<String, Object?> record) => 'GET /items';

  @override
  Future<void> close() async {}
}
