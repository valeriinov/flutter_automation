import 'package:flutter/foundation.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';

/// {@category Utils}
///
/// What an autorun did: the variant it walked, how long it took and the
/// requests the app sent.
@immutable
final class AutomationRunSummary {
  /// Name of the flow the run walked.
  final String flow;

  /// Name of the variant the run walked.
  final String variant;

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

  const AutomationRunSummary({
    required this.flow,
    required this.variant,
    required this.outcome,
    required this.stepCount,
    required this.duration,
    required this.requests,
    required this.shouldShowTouches,
    required this.shouldSignalEnd,
  });
}
