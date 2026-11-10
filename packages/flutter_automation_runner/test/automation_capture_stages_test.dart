import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_capture_stages.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

const _shoot = AutomationCaptureStages.shootOption;
const _until = AutomationCaptureStages.untilOption;
const _captureArgs = ['order_flow', '--capture', 'capture'];
const _shotStages = {0, 3, 4};
const _shotStage = 3;
const _unshotStage = 1;
const _lastStage = 4;
const _laterStage = 7;

void main() {
  group('AutomationCaptureStages Tests', () {
    _automationCaptureStages_should_shootEveryStageWithoutOptions();
    _automationCaptureStages_should_readShotStages();
    _automationCaptureStages_should_readLastStage();
    _automationCaptureStages_should_stopOnlyBeforeStageAfterLastStage();
    _automationCaptureStages_should_rejectMissingValue();
    _automationCaptureStages_should_rejectNonIntegerValue();
    _automationCaptureStages_should_rejectNegativeValue();
  });
}

void _automationCaptureStages_should_shootEveryStageWithoutOptions() {
  test('AutomationCaptureStages should shoot every stage without options', () {
    final sut = AutomationCaptureStages.fromArgs(_captureArgs);

    expect(sut.isPartial, isFalse);
    expect(sut.shoots(0), isTrue);
    expect(sut.shoots(_laterStage), isTrue);
    expect(sut.stopsBefore(1), isFalse);
  });
}

void _automationCaptureStages_should_readShotStages() {
  test('AutomationCaptureStages should read shot stages', () {
    final sut = AutomationCaptureStages.fromArgs([
      ..._captureArgs,
      _shoot,
      '0,3,4',
    ]);

    expect(sut.isPartial, isTrue);
    expect(sut.shotStages, _shotStages);
    expect(sut.shoots(_shotStage), isTrue);
    expect(sut.shoots(_unshotStage), isFalse);
    expect(sut.lastStage, isNull);
  });
}

void _automationCaptureStages_should_readLastStage() {
  test('AutomationCaptureStages should read last stage', () {
    final sut = AutomationCaptureStages.fromArgs([
      ..._captureArgs,
      _until,
      '4',
    ]);

    expect(sut.isPartial, isTrue);
    expect(sut.lastStage, _lastStage);
    expect(sut.shotStages, isNull);
  });
}

void _automationCaptureStages_should_stopOnlyBeforeStageAfterLastStage() {
  test(
    'AutomationCaptureStages should stop only before stage after last stage',
    () {
      const sut = AutomationCaptureStages(lastStage: _lastStage);

      expect(sut.stopsBefore(_lastStage), isFalse);
      expect(sut.stopsBefore(_lastStage + 1), isTrue);
      expect(sut.stopsBefore(_laterStage), isFalse);
    },
  );
}

void _automationCaptureStages_should_rejectMissingValue() {
  test('AutomationCaptureStages should reject missing value', () {
    expect(
      () => AutomationCaptureStages.fromArgs([..._captureArgs, _until]),
      throwsA(isA<AutomationRunnerException>()),
    );
    expect(
      () => AutomationCaptureStages.fromArgs([
        ..._captureArgs,
        _shoot,
        '--system-keyboard',
      ]),
      throwsA(isA<AutomationRunnerException>()),
    );
  });
}

void _automationCaptureStages_should_rejectNonIntegerValue() {
  test('AutomationCaptureStages should reject non integer value', () {
    expect(
      () => AutomationCaptureStages.fromArgs([..._captureArgs, _shoot, '0,a']),
      throwsA(isA<AutomationRunnerException>()),
    );
    expect(
      () => AutomationCaptureStages.fromArgs([..._captureArgs, _until, '1.5']),
      throwsA(isA<AutomationRunnerException>()),
    );
  });
}

void _automationCaptureStages_should_rejectNegativeValue() {
  test('AutomationCaptureStages should reject negative value', () {
    expect(
      () => AutomationCaptureStages.fromArgs([..._captureArgs, _until, '-1']),
      throwsA(isA<AutomationRunnerException>()),
    );
    expect(
      () => AutomationCaptureStages.fromArgs([..._captureArgs, _shoot, '2,-3']),
      throwsA(isA<AutomationRunnerException>()),
    );
  });
}
