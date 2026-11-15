/// {@category Utils}
///
/// Who moves a walk of a flow variant.
enum AutomationWalkMode {
  /// The tester presses Next step and the player does one action.
  manual,

  /// The player does every step in a row, with no controls on screen.
  autorun,
}

/// {@category Utils}
///
/// Where a walk of a flow variant stands.
final class AutomationWalkProgress {
  static const _flowKey = 'flow';
  static const _variantKey = 'variant';
  static const _stepKey = 'step';
  static const _modeKey = 'mode';
  static const _shouldShowTouchesKey = 'shouldShowTouches';
  static const _shouldSignalEndKey = 'shouldSignalEnd';

  /// Name of the flow the walk follows.
  final String flow;

  /// Name of the variant the walk follows.
  final String variant;

  /// Index of the step the walk stands on, in the steps of the variant.
  final int stepIndex;

  /// Who moves the walk.
  final AutomationWalkMode mode;

  /// Whether the player draws a circle where it taps.
  final bool shouldShowTouches;

  /// Whether the end of an autorun vibrates and sounds.
  final bool shouldSignalEnd;

  const AutomationWalkProgress({
    required this.flow,
    required this.variant,
    this.stepIndex = 0,
    this.mode = AutomationWalkMode.manual,
    this.shouldShowTouches = true,
    this.shouldSignalEnd = true,
  });

  /// Reads the walk out of [json], `null` when [json] holds no walk. A walk
  /// saved without a mode is a manual walk.
  static AutomationWalkProgress? tryFromJson(Object? json) {
    if (json is! Map<Object?, Object?>) {
      return null;
    }

    final flow = json[_flowKey];
    final variant = json[_variantKey];
    final stepIndex = json[_stepKey];

    if (flow is! String || variant is! String || stepIndex is! int) {
      return null;
    }

    return AutomationWalkProgress(
      flow: flow,
      variant: variant,
      stepIndex: stepIndex,
      mode:
          AutomationWalkMode.values.asNameMap()[json[_modeKey]] ??
          AutomationWalkMode.manual,
      shouldShowTouches: json[_shouldShowTouchesKey] != false,
      shouldSignalEnd: json[_shouldSignalEndKey] != false,
    );
  }

  /// Walk on the step [stepIndex] of the same variant.
  AutomationWalkProgress atStep(int stepIndex) {
    return _copy(stepIndex: stepIndex);
  }

  /// Walk on the same step of the variant [variant].
  AutomationWalkProgress onVariant(String variant) {
    return _copy(variant: variant);
  }

  /// The walk as JSON.
  Map<String, Object?> toJson() {
    return {
      _flowKey: flow,
      _variantKey: variant,
      _stepKey: stepIndex,
      _modeKey: mode.name,
      _shouldShowTouchesKey: shouldShowTouches,
      _shouldSignalEndKey: shouldSignalEnd,
    };
  }

  AutomationWalkProgress _copy({String? variant, int? stepIndex}) {
    return AutomationWalkProgress(
      flow: flow,
      variant: variant ?? this.variant,
      stepIndex: stepIndex ?? this.stepIndex,
      mode: mode,
      shouldShowTouches: shouldShowTouches,
      shouldSignalEnd: shouldSignalEnd,
    );
  }
}
