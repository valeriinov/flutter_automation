import 'package:collection/collection.dart';

import 'package:flutter_automation_atlas/src/atlas_mock_answer_comparison.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replay.dart';

/// {@category Utils}
///
/// Walks the recorded answers of [input] through a mock built from the
/// current code, seeded on [timing], and returns each answer with how the
/// replayed one differs.
typedef AtlasMockReplayRun =
    List<AtlasReplayedAnswer> Function(
      AtlasMockReplayInput input,
      AtlasReplayTiming timing,
    );

/// {@category Utils}
///
/// The anchor and the launch moment a replay seeds its mock on, and whether
/// it lets a timer the mock started fire only once the requests after it
/// have waited it out.
///
/// A replay whose [launchedAt] is known runs on the moments the stage was
/// captured on.
typedef AtlasReplayTiming = ({
  DateTime anchor,
  DateTime? launchedAt,
  bool isLazy,
});

/// {@category Utils}
///
/// One recorded answer the replay asked the mock again, and how the answer
/// differs.
final class AtlasReplayedAnswer {
  /// The stage the answer was recorded in.
  final int stage;

  /// What was asked, for the `stale` line.
  final String request;

  /// How the replayed answer differs from the recorded one.
  final AtlasMockAnswerDifference difference;

  const AtlasReplayedAnswer({
    required this.stage,
    required this.request,
    required this.difference,
  });

  /// The request and how its answer differs, for the `stale` line.
  String describe() => '$request ${difference.describe()}';
}

/// {@category Utils}
///
/// Replays the requests of one snapshot against a mock built from the current
/// code and finds the first stage it answers differently.
///
/// A stage is replayed on the anchor and the launch moment it was captured on.
/// A stage captured before stages held them is replayed starting on noon of
/// today, the anchor moved by the whole hours the recorded dates stand off the
/// replayed ones. A snapshot does not keep how long the walk waited between
/// two requests, so a timer the mock starts — a delayed reply — fires either
/// right after the request that started it or only once later requests have
/// waited it out; on the second timing every pending timer fires before a
/// value the app received by push. A stage passes when every answer it holds
/// is the recorded one on some timing tried, since a snapshot merged from
/// captures of other days holds stages read off other anchors.
final class AtlasMockReplayer {
  static const _maxRuns = 8;
  static const _anchorHour = 12;

  final AtlasMockReplayInput _input;
  final AtlasMockReplayRun _replayRun;
  final Map<AtlasReplayTiming, List<AtlasReplayedAnswer>> _runs = {};

  /// The [replayRun] parameter asks the mock of the project each recorded
  /// answer again, seeded on one timing.
  AtlasMockReplayer(this._input, this._replayRun);

  /// Where the current mock first answers the input differently.
  AtlasMockReplayOutcome replay() {
    AtlasReplayTiming? timing;
    final stages = {0, ..._input.answers.map((answer) => answer.stage)};

    for (final stage in stages.sorted((a, b) => a.compareTo(b))) {
      final capturedTiming = _tryReadCapturedTiming(stage);
      final resolvedTiming = timing ??= capturedTiming ?? _resolveStartTiming();
      final stageTiming = capturedTiming == null
          ? _tryFindStageTiming(stage, resolvedTiming)
          : _tryFindCapturedTiming(stage, capturedTiming);

      if (stageTiming == null) {
        return AtlasMockReplayOutcome(
          stage: stage,
          difference: _describeFirstDifference(
            stage,
            capturedTiming ?? resolvedTiming,
          ),
        );
      }

      timing = stageTiming;
    }

    return const AtlasMockReplayOutcome.same();
  }

  AtlasReplayTiming? _tryReadCapturedTiming(int stage) {
    final moments = _input.stageMoments.elementAtOrNull(stage);
    final anchor = _tryParseMoment(moments?.anchor);

    if (anchor == null) {
      return null;
    }

    return (
      anchor: anchor,
      launchedAt: _tryParseMoment(moments?.launchedAt),
      isLazy: false,
    );
  }

  AtlasReplayTiming _resolveStartTiming() {
    final now = DateTime.now();
    final noon = (
      anchor: DateTime(now.year, now.month, now.day, _anchorHour),
      launchedAt: null,
      isLazy: false,
    );
    final shift = AtlasMockAnswerDifference.findModalShift(
      _run(noon).expand((answer) => _readUnexplainedShifts(answer.difference)),
    );

    return shift == null ? noon : _shift(noon, shift);
  }

  AtlasReplayTiming? _tryFindStageTiming(int stage, AtlasReplayTiming timing) {
    final replayedTimings = [
      timing,
      ..._runs.keys.where((key) => key != timing),
    ];
    final sameTiming = replayedTimings.firstWhereOrNull(
      (tried) => _isStageSame(stage, tried),
    );

    if (sameTiming != null) {
      return sameTiming;
    }

    return _resolveCandidateTimings(stage, timing)
        .where((candidate) => !_runs.containsKey(candidate))
        .takeWhile((_) => _runs.length < _maxRuns)
        .firstWhereOrNull((candidate) => _isStageSame(stage, candidate));
  }

  AtlasReplayTiming? _tryFindCapturedTiming(
    int stage,
    AtlasReplayTiming timing,
  ) {
    final lazyTiming = (
      anchor: timing.anchor,
      launchedAt: timing.launchedAt,
      isLazy: true,
    );

    return [
      timing,
      lazyTiming,
    ].firstWhereOrNull((candidate) => _isStageSame(stage, candidate));
  }

  String? _describeFirstDifference(int stage, AtlasReplayTiming timing) {
    final answer = _readStageAnswers(
      stage,
      timing,
    ).firstWhereOrNull((answer) => !answer.difference.isSame);

    return answer?.describe();
  }

  DateTime? _tryParseMoment(String? moment) {
    return moment == null ? null : DateTime.tryParse(moment)?.toLocal();
  }

  List<AtlasReplayTiming> _resolveCandidateTimings(
    int stage,
    AtlasReplayTiming timing,
  ) {
    final shifts = _readStageAnswers(stage, timing)
        .expand((answer) => _readUnexplainedShifts(answer.difference))
        .groupFoldBy<Duration, int>(
          (shift) => shift,
          (count, _) => (count ?? 0) + 1,
        )
        .entries
        .sorted((a, b) => b.value.compareTo(a.value))
        .map((entry) => entry.key);
    final shiftedTimings = [for (final shift in shifts) _shift(timing, shift)];

    return [
      ...shiftedTimings,
      for (final shifted in [timing, ...shiftedTimings])
        (anchor: shifted.anchor, launchedAt: null, isLazy: !shifted.isLazy),
    ];
  }

  bool _isStageSame(int stage, AtlasReplayTiming timing) {
    return _readStageAnswers(
      stage,
      timing,
    ).every((answer) => answer.difference.isSame);
  }

  Iterable<Duration> _readUnexplainedShifts(
    AtlasMockAnswerDifference difference,
  ) {
    return difference.mismatch == null ? difference.anchorShifts : const [];
  }

  AtlasReplayTiming _shift(AtlasReplayTiming timing, Duration shift) {
    return (
      anchor: timing.anchor.add(shift),
      launchedAt: null,
      isLazy: timing.isLazy,
    );
  }

  Iterable<AtlasReplayedAnswer> _readStageAnswers(
    int stage,
    AtlasReplayTiming timing,
  ) {
    return _run(timing).where((answer) => answer.stage == stage);
  }

  List<AtlasReplayedAnswer> _run(AtlasReplayTiming timing) {
    return _runs.putIfAbsent(timing, () => _replayRun(_input, timing));
  }
}
