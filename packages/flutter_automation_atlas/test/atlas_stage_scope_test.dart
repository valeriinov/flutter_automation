import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_stage_scope.dart';

const _stageCount = 6;
const _lastShotStage = 3;

void main() {
  group('AtlasStageScope Tests', () {
    _atlasStageScope_should_passNoOptionsForEveryStage();
    _atlasStageScope_should_stopAfterTheLastShotStage();
    _atlasStageScope_should_walkToTheEndWhenTheLastStageIsShot();
  });
}

void _atlasStageScope_should_passNoOptionsForEveryStage() {
  test('AtlasStageScope should pass no options for every stage', () {
    const scope = AtlasStageScope.every();

    expect(scope.isEveryStage, isTrue);
    expect(scope.runnerArguments, isEmpty);
  });
}

void _atlasStageScope_should_stopAfterTheLastShotStage() {
  test('AtlasStageScope should stop after the last shot stage', () {
    final scope = AtlasStageScope.of([
      _lastShotStage,
      0,
      _lastShotStage,
    ], stageCount: _stageCount);

    expect(scope.stages, [0, _lastShotStage]);
    expect(scope.until, _lastShotStage);
    expect(scope.runnerArguments, ['--shoot', '0,3', '--until', '3']);
  });
}

void _atlasStageScope_should_walkToTheEndWhenTheLastStageIsShot() {
  test(
    'AtlasStageScope should walk to the end when the last stage is shot',
    () {
      final scope = AtlasStageScope.of([4, 5], stageCount: _stageCount);

      expect(scope.until, isNull);
      expect(scope.runnerArguments, ['--shoot', '4,5']);
    },
  );
}
