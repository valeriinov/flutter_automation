import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_automation_mock/src/transport/mock_latency.dart';
import 'package:flutter_automation_mock/src/transport/mock_latency_profile.dart';

/// Shortest delay the realistic profile declares.
const _realisticMinDelay = Duration(milliseconds: 150);

/// Longest delay the realistic profile declares.
const _realisticMaxDelay = Duration(milliseconds: 400);

/// Span wider than the longest delay any profile draws.
const _beyondEveryDelay = Duration(seconds: 10);

/// Seed two subjects share when a test asserts one series twice.
const _sharedSeed = 7;

/// Seed that differs from [_sharedSeed], so its series has to differ too.
const _otherSeed = 8;

/// Draws read off one subject, enough for two series to differ.
const _drawCount = 12;

void main() {
  group('MockLatency Tests', () {
    _mockLatency_should_answerWithoutADelayOnTheFastProfile();
    _mockLatency_should_drawEveryDelayInsideTheRealisticRange();
    _mockLatency_should_drawTheSameSeriesForTheSameSeed();
    _mockLatency_should_drawADifferentSeriesForADifferentSeed();
  });
}

void _mockLatency_should_answerWithoutADelayOnTheFastProfile() {
  test('MockLatency should answer without a delay on the fast profile', () {
    fakeAsync((async) {
      final sut = MockLatency(
        profile: MockLatencyProfile.fast,
        seed: _sharedSeed,
      );
      bool hasAnswered = false;

      unawaited(_awaitAnswer(sut, () => hasAnswered = true));
      async.flushMicrotasks();
      expect(hasAnswered, isTrue);
    });
  });
}

void _mockLatency_should_drawEveryDelayInsideTheRealisticRange() {
  test('MockLatency should draw every delay inside the realistic range', () {
    final delays = _drawDelays(
      MockLatency(profile: MockLatencyProfile.realistic, seed: _sharedSeed),
    );

    expect(delays, hasLength(_drawCount));
    expect(
      delays,
      everyElement(
        allOf(
          greaterThanOrEqualTo(_realisticMinDelay),
          lessThanOrEqualTo(_realisticMaxDelay),
        ),
      ),
    );
  });
}

void _mockLatency_should_drawTheSameSeriesForTheSameSeed() {
  test('MockLatency should draw the same series for the same seed', () {
    final delays = _drawDelays(
      MockLatency(profile: MockLatencyProfile.realistic, seed: _sharedSeed),
    );
    final sameSeedDelays = _drawDelays(
      MockLatency(profile: MockLatencyProfile.realistic, seed: _sharedSeed),
    );

    expect(sameSeedDelays, delays);
  });
}

void _mockLatency_should_drawADifferentSeriesForADifferentSeed() {
  test('MockLatency should draw a different series for a different seed', () {
    final delays = _drawDelays(
      MockLatency(profile: MockLatencyProfile.realistic, seed: _sharedSeed),
    );
    final otherSeedDelays = _drawDelays(
      MockLatency(profile: MockLatencyProfile.realistic, seed: _otherSeed),
    );

    expect(otherSeedDelays, isNot(delays));
  });
}

/// The [_drawCount] delays that [latency] waits out, read off a fake clock.
///
/// A draw is the point where the answer arrives. A test therefore compares a
/// series by its values, not by the wall clock that a run would spend on it.
List<Duration> _drawDelays(MockLatency latency) {
  final delays = <Duration>[];

  fakeAsync((async) {
    for (int draw = 0; draw < _drawCount; draw++) {
      final start = async.elapsed;

      unawaited(_awaitAnswer(latency, () => delays.add(async.elapsed - start)));
      async.elapse(_beyondEveryDelay);
    }
  });

  return delays;
}

/// Waits out [latency] and calls [onAnswered] the moment the answer arrives.
Future<void> _awaitAnswer(
  MockLatency latency,
  void Function() onAnswered,
) async {
  await latency.waitOut();

  onAnswered();
}
