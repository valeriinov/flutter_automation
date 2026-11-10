import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

/// {@category Utils}
///
/// The stages of a capture run the runner shoots and the stage it stops at.
///
/// A stage is a user action of the walk. The count starts at zero in the order
/// that the variant runs the stages. It is the index of the stage in the
/// capture report.
/// `--shoot <i,j>` names the stages that get a screenshot, a target rect and
/// their journal; without it every stage does. `--until <k>` ends the walk
/// before the action of stage `k + 1`.
final class AutomationCaptureStages {
  static const shootOption = '--shoot';
  static const untilOption = '--until';

  /// The stage indexes `--shoot` names, or `null` when every stage is shot.
  final Set<int>? shotStages;

  /// The last stage `--until` lets the walk run, or `null` for a whole walk.
  final int? lastStage;

  const AutomationCaptureStages({this.shotStages, this.lastStage});

  /// Reads `--shoot` and `--until` from the runner [args].
  ///
  /// Throws an [AutomationRunnerException] when either option has no value,
  /// or a value that is not a non-negative integer.
  factory AutomationCaptureStages.fromArgs(List<String> args) {
    final shootValue = _tryReadValue(args, shootOption);
    final untilValue = _tryReadValue(args, untilOption);

    return AutomationCaptureStages(
      shotStages: shootValue?.split(',').map(_parseStage).toSet(),
      lastStage: untilValue == null ? null : _parseStage(untilValue),
    );
  }

  /// Whether either option narrows the capture run.
  bool get isPartial => shotStages != null || lastStage != null;

  /// Whether the stage at [stage] gets its screenshot, target rect and
  /// journal.
  bool shoots(int stage) => shotStages?.contains(stage) ?? true;

  /// Whether the walk ends before the action of the stage at [stage].
  bool stopsBefore(int stage) {
    final resolvedLastStage = lastStage;

    return resolvedLastStage != null && stage == resolvedLastStage + 1;
  }

  static String? _tryReadValue(List<String> args, String option) {
    final index = args.indexOf(option);

    if (index < 0) {
      return null;
    }

    final value = index + 1 < args.length ? args[index + 1] : null;

    if (value == null || value.startsWith('-')) {
      throw AutomationRunnerException(
        'The $option option needs a stage index.',
      );
    }

    return value;
  }

  static int _parseStage(String value) {
    final stage = int.tryParse(value.trim());

    if (stage == null || stage < 0) {
      throw AutomationRunnerException(
        '"$value" is not a stage index: a stage index is an integer from 0.',
      );
    }

    return stage;
  }
}
