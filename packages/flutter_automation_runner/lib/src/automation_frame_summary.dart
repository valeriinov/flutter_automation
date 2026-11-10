import 'package:collection/collection.dart';
import 'package:flutter_driver/flutter_driver.dart';

/// One span of the timeline: a complete event, or a begin paired with its end.
typedef _Span = ({String name, int threadId, int start, int duration});

/// One raw timeline event with the fields a span needs already resolved.
typedef _Event = ({
  String name,
  int threadId,
  String phase,
  int start,
  int? duration,
});

/// {@category Utils}
///
/// What a traced window says about the frames in it.
///
/// The percentiles and the `missedBudget` counts come from the SDK's own
/// [TimelineSummary], so a number here means what it means in each other
/// Flutter timeline report. It also names what the widest build frame and the
/// widest raster frame of the window spent their time on. A round that works on
/// a slow frame then starts from the phase that owns it, not from a guess.
///
/// `budgetMs` is the SDK's [kBuildBudget], and `missedBudget` counts the
/// frames past it. `goalMs` is the frame time the project holds its frames to,
/// and `missedGoal` counts the frames past it.
final class AutomationFrameSummary {
  /// The frame time in milliseconds a summary holds frames to when the caller
  /// names none.
  static const defaultGoalMillis = 16;

  /// The percentiles at which the summary reports each frame series.
  static const _percentiles = {'p50': 50.0, 'p90': 90.0, 'p99': 99.0};
  static const _completePhase = 'X';
  static const _beginPhases = {'B', 'b'};
  static const _microsPerMilli = 1000;

  /// How many phase rows the summary reports for one frame.
  ///
  /// The engine alone opens seven of them inside a build frame: `BUILD`,
  /// `LAYOUT`, `UPDATING_COMPOSITING_BITS`, `PAINT`, `COMPOSITING`, `SEMANTICS`
  /// and `FINALIZE_TREE`. The app names spans of its own inside `BUILD`, so the
  /// list ends three rows past the engine's own.
  static const _phaseCount = 10;
  static const _sceneDisplayLagEventName = 'SceneDisplayLag';

  final Timeline _timeline;
  final int _goalMillis;

  /// Summarizes [_timeline] against the frame time of [goalMillis].
  const AutomationFrameSummary(
    this._timeline, {
    int goalMillis = defaultGoalMillis,
  }) : _goalMillis = goalMillis;

  int get _goalMicros => _goalMillis * _microsPerMilli;

  /// The `frames` object of the run report.
  Map<String, Object?> toReport() {
    final summary = TimelineSummary.summarize(_timeline);
    final frameCount = summary.countFrames();
    final spans = _readSpans();

    if (frameCount == 0) {
      return {
        'budgetMs': kBuildBudget.inMilliseconds,
        'goalMs': _goalMillis,
        'build': {'count': 0},
      };
    }

    final summaryJson = summary.summaryJson;

    return {
      'budgetMs': kBuildBudget.inMilliseconds,
      'goalMs': _goalMillis,
      'build': {
        'count': frameCount,
        'average': summary.computeAverageFrameBuildTimeMillis(),
        ..._percentileMillis(summary.computePercentileFrameBuildTimeMillis),
        'worst': summary.computeWorstFrameBuildTimeMillis(),
        'missedBudget': summary.computeMissedFrameBuildBudgetCount(),
        'missedGoal': _missedGoal(summaryJson['frame_build_times']),
      },
      'raster': {
        'count': summary.countRasterizations(),
        'average': summary.computeAverageFrameRasterizerTimeMillis(),
        ..._percentileMillis(
          summary.computePercentileFrameRasterizerTimeMillis,
        ),
        'worst': summary.computeWorstFrameRasterizerTimeMillis(),
        'missedBudget': summary.computeMissedFrameRasterizerBudgetCount(),
        'missedGoal': _missedGoal(summaryJson['frame_rasterizer_times']),
      },
      'vsyncTransitionsMissed': {
        'average': summaryJson['average_vsync_transitions_missed'],
        'p90': summaryJson['90th_percentile_vsync_transitions_missed'],
        'p99': summaryJson['99th_percentile_vsync_transitions_missed'],
      },
      'lateFrames': _lateFrames(),
      'slowestBuildFrame': ?_slowestFrame(spans, kBuildFrameEventName),
      'slowestRasterFrame': ?_slowestFrame(spans, kRasterizeFrameEventName),
    };
  }

  Map<String, double> _percentileMillis(double Function(double) compute) {
    return _percentiles.map(
      (name, percentile) => MapEntry(name, compute(percentile)),
    );
  }

  /// How many of the frame durations that the SDK reports lie past
  /// [_goalMicros].
  ///
  /// [TimelineSummary] counts against its own budget alone. This code counts
  /// the goal off the microsecond series that `summaryJson` already carries.
  int _missedGoal(Object? frameMicros) {
    if (frameMicros is! List) {
      return 0;
    }

    return frameMicros
        .whereType<int>()
        .where((micros) => micros > _goalMicros)
        .length;
  }

  /// How many frames the engine put on the display later than the time it
  /// targeted for them.
  ///
  /// The engine writes one `SceneDisplayLag` event per such frame, as an
  /// asynchronous begin and its end. The count therefore runs over the begins.
  ///
  /// The summary reports it, and no gate uses it. `vsyncTransitionsMissed`
  /// averages over the late frames alone, so it cannot tell one late frame from
  /// many. This count tells them apart. It becomes a gate the day a quiet
  /// window shows a 0 here.
  int _lateFrames() {
    final events = _timeline.events ?? const <TimelineEvent>[];

    return events.map(_readEvent).nonNulls.where(_isLateFrameBegin).length;
  }

  bool _isLateFrameBegin(_Event event) {
    return event.name == _sceneDisplayLagEventName &&
        _beginPhases.contains(event.phase);
  }

  /// The widest frame of the window named [frameName], its place on the own
  /// microsecond clock of the timeline, and what stood inside it.
  ///
  /// [kBuildFrameEventName] reads the UI thread and [kRasterizeFrameEventName]
  /// the raster thread. The phases inside each are the spans that the engine
  /// opens on that thread alone.
  ///
  /// `startMicros` is that clock, not an offset into the window. It lines the
  /// frame up against the step of the flow that the run walks at that moment.
  Map<String, Object?>? _slowestFrame(List<_Span> spans, String frameName) {
    final frames = spans.where((span) => span.name == frameName);

    if (frames.isEmpty) {
      return null;
    }

    final slowest = frames.reduce(
      (widest, span) => span.duration > widest.duration ? span : widest,
    );

    return {
      'ms': slowest.duration / _microsPerMilli,
      'startMicros': slowest.start,
      'phases': _phasesWithin(spans, slowest),
    };
  }

  /// The spans [frame] contains, each with its own time alone, summed per name
  /// and widest first.
  ///
  /// A frame opens a phase more than once: a sliver that builds its children
  /// inside the layout pass opens a second `BUILD` under `LAYOUT`. A plain
  /// total per name therefore counts the same microseconds under two names and
  /// can stand past the frame it reads from. Here, each span gives up what the
  /// spans inside it took. The list then adds up to the frame, and a reader can
  /// subtract two of its rows from each other.
  List<Map<String, Object?>> _phasesWithin(List<_Span> spans, _Span frame) {
    final nested = spans
        .where((span) => _isNestedIn(span, frame))
        .sorted(_byContainment);
    final selfMicros = _selfMicros(nested);
    final phases = [
      for (int index = 0; index < nested.length; index++)
        (name: nested[index].name, micros: selfMicros[index]),
    ];

    return groupBy(phases, (phase) => phase.name).entries
        .map(
          (entry) => (
            name: entry.key,
            micros: entry.value.fold<int>(
              0,
              (total, phase) => total + phase.micros,
            ),
          ),
        )
        .sorted((first, second) => second.micros.compareTo(first.micros))
        .take(_phaseCount)
        .map(
          (phase) => {'name': phase.name, 'ms': phase.micros / _microsPerMilli},
        )
        .toList();
  }

  /// Orders spans so that a span that has another inside it comes first.
  int _byContainment(_Span first, _Span second) {
    final byStart = first.start.compareTo(second.start);

    return byStart != 0 ? byStart : second.duration.compareTo(first.duration);
  }

  /// What each of [spans] took with the time its own children took given up.
  List<int> _selfMicros(List<_Span> spans) {
    final self = spans.map((span) => span.duration).toList();
    final open = <int>[];

    for (int index = 0; index < spans.length; index++) {
      final span = spans[index];
      final parent = _closeSpansEndedBy(spans, open, span.start);

      if (parent != null) {
        self[parent] -= span.duration;
      }

      open.add(index);
    }

    return self;
  }

  /// Drops each open span that the span at [start] does not stand inside, and
  /// answers the innermost span still open.
  int? _closeSpansEndedBy(List<_Span> spans, List<int> open, int start) {
    while (open.isNotEmpty && _endOf(spans[open.last]) <= start) {
      open.removeLast();
    }

    return open.lastOrNull;
  }

  bool _isNestedIn(_Span span, _Span frame) {
    if (span.threadId != frame.threadId || span.name == frame.name) {
      return false;
    }

    return span.start >= frame.start && _endOf(span) <= _endOf(frame);
  }

  int _endOf(_Span span) => span.start + span.duration;

  /// Every span of the timeline.
  ///
  /// The timeline holds a frame as a begin and an end, not as one complete
  /// event. The code pairs the two per name and thread. It holds a begin until
  /// an event of that name that is not itself a begin arrives. It takes that
  /// event as the end without a check. That is how `TimelineSummary` itself
  /// reads its frame markers. It holds for the synchronous `B`/`E` phases and
  /// for the asynchronous `b`/`e` ones alike.
  List<_Span> _readSpans() {
    final events = (_timeline.events ?? const <TimelineEvent>[])
        .map(_readEvent)
        .nonNulls
        .sorted((first, second) => first.start.compareTo(second.start));
    final paired = groupBy(
      events.where((event) => event.phase != _completePhase),
      (_Event event) => (event.name, event.threadId),
    ).values.expand(_pairSpans);

    return [...events.map(_completeSpan).nonNulls, ...paired];
  }

  _Span? _completeSpan(_Event event) {
    final duration = event.duration;

    if (event.phase != _completePhase || duration == null) {
      return null;
    }

    return (
      name: event.name,
      threadId: event.threadId,
      start: event.start,
      duration: duration,
    );
  }

  /// Pairs the begins and ends of one name on one thread.
  Iterable<_Span> _pairSpans(List<_Event> events) sync* {
    _Event? begin;

    for (final event in events) {
      if (_beginPhases.contains(event.phase)) {
        begin = event;
        continue;
      }

      final opened = begin;

      if (opened == null) {
        continue;
      }

      final start = opened.start;

      begin = null;

      yield (
        name: opened.name,
        threadId: opened.threadId,
        start: start,
        duration: event.start - start,
      );
    }
  }

  _Event? _readEvent(TimelineEvent event) {
    final name = event.name;
    final threadId = event.threadId;

    if (name == null || threadId == null) {
      return null;
    }

    final phase = event.phase;
    final start = event.timestampMicros;

    if (phase == null || start == null) {
      return null;
    }

    return (
      name: name,
      threadId: threadId,
      phase: phase,
      start: start,
      duration: event.duration?.inMicroseconds,
    );
  }
}
