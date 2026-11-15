/// {@category Utils}
///
/// Where a manual walk of a flow variant stands.
final class AutomationWalkProgress {
  static const _flowKey = 'flow';
  static const _variantKey = 'variant';
  static const _stepKey = 'step';

  /// Name of the flow the walk follows.
  final String flow;

  /// Name of the variant the walk follows.
  final String variant;

  /// Index of the step the tester stands on.
  final int stepIndex;

  const AutomationWalkProgress({
    required this.flow,
    required this.variant,
    this.stepIndex = 0,
  });

  /// Reads the walk out of [json], `null` when [json] holds no walk.
  static AutomationWalkProgress? tryFromJson(Object? json) {
    if (json case {
      _flowKey: final String flow,
      _variantKey: final String variant,
      _stepKey: final int stepIndex,
    }) {
      return AutomationWalkProgress(
        flow: flow,
        variant: variant,
        stepIndex: stepIndex,
      );
    }

    return null;
  }

  /// Walk on the step [stepIndex] of the same variant.
  AutomationWalkProgress atStep(int stepIndex) {
    return AutomationWalkProgress(
      flow: flow,
      variant: variant,
      stepIndex: stepIndex,
    );
  }

  /// The walk as JSON.
  Map<String, Object?> toJson() {
    return {_flowKey: flow, _variantKey: variant, _stepKey: stepIndex};
  }
}
