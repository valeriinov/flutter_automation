/// {@category Utils}
///
/// The `action` names of the steps that the host and the runner both read.
abstract final class FlowActionNames {
  /// The `action` of `DriverCommand`.
  static const driverCommand = 'driverCommand';

  /// The `action` of `TraceStart`.
  static const traceStart = 'traceStart';

  /// The `action` of `TraceStop`.
  static const traceStop = 'traceStop';

  /// The `action` of `ProbeSeries`.
  static const probeSeries = 'probeSeries';

  /// The `action` of `ProbeCenter`.
  static const probeCenter = 'probeCenter';
}
