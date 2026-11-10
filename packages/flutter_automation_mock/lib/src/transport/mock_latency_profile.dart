/// {@category Utils}
///
/// Range of the delay of a mocked answer.
///
/// A real backend answers over a network, so a mock that answers instantly
/// hides each loader, each disabled button and each race of the app. The
/// profile is where a run chooses between honesty and speed.
enum MockLatencyProfile {
  /// No delay at all, for a run that measures something other than the network.
  fast(Duration.zero, Duration.zero),

  /// What a healthy backend answers in over a mobile connection.
  realistic(Duration(milliseconds: 150), Duration(milliseconds: 400)),

  /// What a loaded backend answers in, long enough to read a loader.
  slow(Duration(seconds: 1), Duration(seconds: 3));

  /// Shortest delay the profile answers after.
  final Duration minDelay;

  /// Longest delay the profile answers after.
  final Duration maxDelay;

  const MockLatencyProfile(this.minDelay, this.maxDelay);
}
