/// {@category Utils}
///
/// Counts the sign changes of the step between consecutive screen positions.
int resolveProbeSeriesSignChanges(Iterable<double> positions) {
  const deadBand = 0.01;
  double? previousPosition;
  int? previousDirection;
  int signChanges = 0;

  for (final position in positions) {
    final previous = previousPosition;

    previousPosition = position;

    if (previous == null) {
      continue;
    }

    final delta = position - previous;

    if (delta.abs() <= deadBand) {
      continue;
    }

    final direction = delta.isNegative ? -1 : 1;

    if (previousDirection != null && direction != previousDirection) {
      signChanges += 1;
    }

    previousDirection = direction;
  }

  return signChanges;
}
