import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_probe_series.dart';

const _stablePositions = [100.0, 100.0, 100.0];
const _deadBandPositions = [100.0, 99.995, 100.004];
const _singleReversalPositions = [100.0, 99.0, 98.0, 98.5, 99.0];
const _alternatingPositions = [100.0, 99.0, 100.0, 99.0, 100.0];
const _alternatingSignChanges = 3;

void main() {
  group('resolveProbeSeriesSignChanges Tests', () {
    _resolveProbeSeriesSignChanges_should_ignoreStablePosition();
    _resolveProbeSeriesSignChanges_should_ignoreMovementInsideDeadBand();
    _resolveProbeSeriesSignChanges_should_countSignChangeOnce();
    _resolveProbeSeriesSignChanges_should_countEverySignChange();
  });
}

void _resolveProbeSeriesSignChanges_should_ignoreStablePosition() {
  test('resolveProbeSeriesSignChanges should ignore stable position', () {
    expect(resolveProbeSeriesSignChanges(_stablePositions), 0);
  });
}

void _resolveProbeSeriesSignChanges_should_ignoreMovementInsideDeadBand() {
  test(
    'resolveProbeSeriesSignChanges should ignore movement inside dead band',
    () {
      expect(resolveProbeSeriesSignChanges(_deadBandPositions), 0);
    },
  );
}

void _resolveProbeSeriesSignChanges_should_countSignChangeOnce() {
  test('resolveProbeSeriesSignChanges should count sign change once', () {
    expect(resolveProbeSeriesSignChanges(_singleReversalPositions), 1);
  });
}

void _resolveProbeSeriesSignChanges_should_countEverySignChange() {
  test('resolveProbeSeriesSignChanges should count every sign change', () {
    expect(
      resolveProbeSeriesSignChanges(_alternatingPositions),
      _alternatingSignChanges,
    );
  });
}
