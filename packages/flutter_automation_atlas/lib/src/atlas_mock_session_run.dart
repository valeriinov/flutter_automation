import 'package:fake_async/fake_async.dart';

import 'package:flutter_automation_atlas/src/atlas_journal_cleaner.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_schema.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_answer_comparison.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replay.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replayer.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_session.dart';

/// {@category Utils}
///
/// One walk of a snapshot's recorded answers through an [AtlasMockSession],
/// seeded on one timing.
///
/// The walk runs in a `FakeAsync` zone. A timer that the mock starts fires
/// right after the request that started it. On a lazy timing, the run lets
/// fake time pass until the answer arrives or 30 s pass.
final class AtlasMockSessionRun {
  static const _kindKey = 'kind';
  static const _statusKey = 'status';
  static const _lazyStep = Duration(milliseconds: 10);
  static const _lazyTimeout = Duration(seconds: 30);

  final AtlasMockReplayInput _input;
  final AtlasReplayTiming _timing;
  final AtlasMockSessionFactory _sessionFactory;
  final AtlasJournalSchema _schema;
  final AtlasMockAnswerComparison _comparison;
  final AtlasJournalCleaner _cleaner;
  final Map<String, String> _issuedIds = {};

  /// The `sessionFactory` parameter builds the session of the walk; the
  /// `schema` parameter is the journal schema of the project.
  AtlasMockSessionRun(
    this._input,
    this._timing,
    this._sessionFactory,
    this._schema,
  ) : _comparison = AtlasMockAnswerComparison(_schema),
      _cleaner = AtlasJournalCleaner(_schema);

  /// Replays each recorded answer, in order.
  List<AtlasReplayedAnswer> run() {
    return FakeAsync().run((async) {
      final session = _sessionFactory(_createContext());

      async.flushMicrotasks();

      final answers = [
        for (final record in session.impliedAnswers())
          AtlasRecordedAnswer(stage: 0, record: _clean(record)),
        ..._input.answers,
      ];

      try {
        return [for (final answer in answers) _replay(answer, session, async)];
      } finally {
        _PendingAnswer().track(session.close());
        async.flushMicrotasks();
      }
    });
  }

  AtlasMockSessionContext _createContext() {
    return AtlasMockSessionContext(
      scenario: _input.scenario,
      locale: _input.locale,
      recordedAnswers: [for (final answer in _input.answers) answer.record],
      anchor: _timing.anchor,
      launchedAt: _timing.launchedAt,
      isLazy: _timing.isLazy,
    );
  }

  AtlasReplayedAnswer _replay(
    AtlasRecordedAnswer recordedAnswer,
    AtlasMockSession session,
    FakeAsync async,
  ) {
    final record = AtlasMockAnswerComparison.substituteIssuedIds(
      recordedAnswer.record,
      _issuedIds,
    );

    if (_timing.isLazy && session.isPushedValue(record)) {
      async.flushTimers(flushPeriodicTimers: false);
    }

    final answer = _PendingAnswer()
      ..track(Future.sync(() => session.ask(record)));

    _waitOut(async, isAnswered: () => answer.isAnswered);

    final replayedRecords = session.takeJournal();

    return AtlasReplayedAnswer(
      stage: recordedAnswer.stage,
      request: session.describe(record),
      difference: _compare(
        record,
        session.findReplayed(record, replayedRecords),
        answer.failure,
      ),
    );
  }

  void _waitOut(FakeAsync async, {required bool Function() isAnswered}) {
    if (!_timing.isLazy) {
      async.flushTimers(flushPeriodicTimers: false);

      return;
    }

    final start = async.elapsed;

    while (!isAnswered() && async.elapsed - start < _lazyTimeout) {
      async.elapse(_lazyStep);
    }
  }

  AtlasMockAnswerDifference _compare(
    Map<String, Object?> recorded,
    Map<String, Object?>? replayed,
    String? failure,
  ) {
    if (replayed == null || _isUnanswered(recorded, replayed, failure)) {
      return AtlasMockAnswerDifference.mismatch(
        failure == null ? 'answered nothing' : 'failed: $failure',
      );
    }

    final difference = _comparison.compare(
      recorded: recorded,
      replayed: _clean(replayed),
      hasKnownMoments: _timing.launchedAt != null,
    );

    _issuedIds.addAll(difference.issuedIds);

    return difference;
  }

  // The journal holds no status for a responder that threw and status 0 for a
  // configured connection error.
  bool _isUnanswered(
    Map<String, Object?> recorded,
    Map<String, Object?> replayed,
    String? failure,
  ) {
    if (!_schema.requestKinds.contains(recorded[_kindKey])) {
      return failure != null;
    }

    return failure != null && !replayed.containsKey(_statusKey);
  }

  Map<String, Object?> _clean(Map<String, Object?> record) {
    final withoutMoments = record[_kindKey] == _schema.launchKind
        ? AtlasJournalCleaner.withoutMoments(record)
        : record;
    final cleaned = _cleaner.clean([withoutMoments]).single;

    return cleaned is Map<String, Object?> ? cleaned : const {};
  }
}

final class _PendingAnswer {
  bool isAnswered = false;

  String? failure;

  Future<void> track(Future<Object?> answer) async {
    try {
      await answer;
    } on Object catch (error) {
      failure = '$error';
    } finally {
      isAnswered = true;
    }
  }
}
