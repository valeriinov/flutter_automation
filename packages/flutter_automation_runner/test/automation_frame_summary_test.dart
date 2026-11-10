import 'package:flutter_driver/flutter_driver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_frame_summary.dart';

const _uiThreadId = 1;
const _rasterThreadId = 2;
const _budgetMs = 16;
const _frameCount = 2;
const _slowBuildMs = 20.0;
const _slowBuildSelfMs = 15.0;
const _nestedLayoutMs = 2.0;
const _emptyTimeline = <String, Object?>{'traceEvents': <Object?>[]};
const _windowTimeline = <String, Object?>{
  'traceEvents': [
    {'name': 'Frame', 'ph': 'B', 'ts': 0, 'tid': _uiThreadId, 'pid': 1},
    {
      'name': 'BUILD',
      'ph': 'X',
      'ts': 1000,
      'dur': 17000,
      'tid': _uiThreadId,
      'pid': 1,
    },
    {
      'name': 'LAYOUT',
      'ph': 'X',
      'ts': 10000,
      'dur': 2000,
      'tid': _uiThreadId,
      'pid': 1,
    },
    {'name': 'Frame', 'ph': 'E', 'ts': 20000, 'tid': _uiThreadId, 'pid': 1},
    {'name': 'Frame', 'ph': 'B', 'ts': 30000, 'tid': _uiThreadId, 'pid': 1},
    {'name': 'Frame', 'ph': 'E', 'ts': 35000, 'tid': _uiThreadId, 'pid': 1},
    {
      'name': 'GPURasterizer::Draw',
      'ph': 'B',
      'ts': 20000,
      'tid': _rasterThreadId,
      'pid': 1,
    },
    {
      'name': 'GPURasterizer::Draw',
      'ph': 'E',
      'ts': 24000,
      'tid': _rasterThreadId,
      'pid': 1,
    },
    {
      'name': 'GPURasterizer::Draw',
      'ph': 'B',
      'ts': 35000,
      'tid': _rasterThreadId,
      'pid': 1,
    },
    {
      'name': 'GPURasterizer::Draw',
      'ph': 'E',
      'ts': 53000,
      'tid': _rasterThreadId,
      'pid': 1,
    },
    {
      'name': 'SceneDisplayLag',
      'ph': 'b',
      'ts': 53000,
      'tid': _rasterThreadId,
      'pid': 1,
      'args': {'vsync_transitions_missed': '1'},
    },
    {
      'name': 'SceneDisplayLag',
      'ph': 'e',
      'ts': 60000,
      'tid': _rasterThreadId,
      'pid': 1,
      'args': {'vsync_transitions_missed': '1'},
    },
  ],
};

void main() {
  group('AutomationFrameSummary Tests', () {
    _automationFrameSummary_should_reportAnEmptyWindowWithItsBudgets();
    _automationFrameSummary_should_countTheFramesPastTheBudget();
    _automationFrameSummary_should_countTheLateFrames();
    _automationFrameSummary_should_giveEachPhaseItsOwnTime();
  });
}

void _automationFrameSummary_should_reportAnEmptyWindowWithItsBudgets() {
  test(
    'AutomationFrameSummary should report an empty window with its budgets',
    () {
      final sut = AutomationFrameSummary(Timeline.fromJson(_emptyTimeline));
      final report = sut.toReport();

      expect(report, {
        'budgetMs': _budgetMs,
        'goalMs': _budgetMs,
        'build': {'count': 0},
      });
    },
  );
}

void _automationFrameSummary_should_countTheFramesPastTheBudget() {
  test('AutomationFrameSummary should count the frames past the budget', () {
    final sut = AutomationFrameSummary(Timeline.fromJson(_windowTimeline));
    final report = sut.toReport();
    final build = report['build'] as Map<String, Object?>?;
    final raster = report['raster'] as Map<String, Object?>?;

    expect(build?['count'], _frameCount);
    expect(build?['worst'], _slowBuildMs);
    expect(build?['missedBudget'], 1);
    expect(build?['missedGoal'], 1);
    expect(raster?['missedBudget'], 1);
    expect(raster?['missedGoal'], 1);
  });
}

void _automationFrameSummary_should_countTheLateFrames() {
  test('AutomationFrameSummary should count the late frames', () {
    final sut = AutomationFrameSummary(Timeline.fromJson(_windowTimeline));
    final report = sut.toReport();

    expect(report['lateFrames'], 1);
  });
}

void _automationFrameSummary_should_giveEachPhaseItsOwnTime() {
  test('AutomationFrameSummary should give each phase its own time', () {
    final sut = AutomationFrameSummary(Timeline.fromJson(_windowTimeline));
    final report = sut.toReport();
    final slowest = report['slowestBuildFrame'] as Map<String, Object?>?;

    expect(slowest?['ms'], _slowBuildMs);
    expect(slowest?['phases'], [
      {'name': 'BUILD', 'ms': _slowBuildSelfMs},
      {'name': 'LAYOUT', 'ms': _nestedLayoutMs},
    ]);
  });
}
