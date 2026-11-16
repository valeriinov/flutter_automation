import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';

/// {@category Utils}
///
/// What a run did: the variant it walked, how long it took and the requests
/// the app sent. A manual walk and an autorun both end with it.
@immutable
final class AutomationRunSummary {
  /// Name of the flow the run walked.
  final String flow;

  /// Name of the variant the run walked.
  final String variant;

  /// Who moved the run.
  final AutomationWalkMode mode;

  /// Title of the outcome the run walked.
  final String outcome;

  /// How many actions the run did.
  final int stepCount;

  /// How long the run took.
  final Duration duration;

  /// Requests the app sent during the run, in order.
  final List<AutomationCatalogueRequest> requests;

  /// Whether the run drew a circle where it tapped.
  final bool shouldShowTouches;

  /// Whether the end of the run signaled.
  final bool shouldSignalEnd;

  /// The `report.json` file of the run, missing when the mock has no store.
  final File? report;

  const AutomationRunSummary({
    required this.flow,
    required this.variant,
    required this.mode,
    required this.outcome,
    required this.stepCount,
    required this.duration,
    required this.requests,
    required this.shouldShowTouches,
    required this.shouldSignalEnd,
    this.report,
  });

  /// The same summary with [report] as its report file.
  AutomationRunSummary withReport(File? report) {
    return AutomationRunSummary(
      flow: flow,
      variant: variant,
      mode: mode,
      outcome: outcome,
      stepCount: stepCount,
      duration: duration,
      requests: requests,
      shouldShowTouches: shouldShowTouches,
      shouldSignalEnd: shouldSignalEnd,
      report: report,
    );
  }

  /// The JSON of the `report.json` file of the run.
  Map<String, Object?> toReportJson() {
    return {
      'flow': flow,
      'variant': variant,
      'mode': mode.name,
      'outcome': outcome,
      'stepCount': stepCount,
      'durationMs': duration.inMilliseconds,
      'finishedAt': DateTime.now().toUtc().toIso8601String(),
      'requests': [
        for (final request in requests)
          {
            'method': request.method,
            'path': request.path,
            'statusCode': request.statusCode,
          },
      ],
    };
  }
}
