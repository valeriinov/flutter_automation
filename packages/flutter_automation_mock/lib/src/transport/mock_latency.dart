import 'dart:math';

import 'package:flutter_automation_mock/src/transport/mock_latency_profile.dart';

/// {@category Utils}
///
/// Delay the mock waits out before it answers a request.
///
/// The jitter comes from a seeded generator. One flow therefore spends the same
/// wall clock on each run, and a run that got slower got slower because of the
/// app.
class MockLatency {
  /// Range of the delays.
  final MockLatencyProfile profile;

  final Random _random;

  MockLatency({required this.profile, required int seed})
    : _random = Random(seed);

  /// Waits out the delay of the next answer.
  ///
  /// The [override] parameter is the profile of a single path that replaces
  /// [profile]. The delay still comes from the seeded generator.
  Future<void> waitOut([MockLatencyProfile? override]) {
    final delay = _resolveDelay(override ?? profile);

    if (delay == Duration.zero) {
      return Future<void>.value();
    }

    return Future<void>.delayed(delay);
  }

  Duration _resolveDelay(MockLatencyProfile profile) {
    final minMs = profile.minDelay.inMilliseconds;
    final spreadMs = profile.maxDelay.inMilliseconds - minMs;

    if (spreadMs <= 0) {
      return profile.minDelay;
    }

    return Duration(milliseconds: minMs + _random.nextInt(spreadMs + 1));
  }
}
