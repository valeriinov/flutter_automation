import 'package:flutter_automation_runner/src/automation_localized_text.dart';
import 'package:flutter_automation_runner/src/definition/flow_finder.dart';
import 'package:flutter_automation_runner/src/definition/flow_item.dart';
import 'package:flutter_automation_runner/src/definition/flow_json_value.dart';

/// {@category Utils}
///
/// One driver action of a flow, written inline in a variant or inside a block.
///
/// Each subclass answers to one `action` of the JSON form.
abstract class FlowStep implements FlowItem {
  /// Short words that name the step in a report, missing when the runner names
  /// it after the action and what it addresses.
  final String? label;

  /// What the person does in the step, in words for people, missing when the
  /// step has none.
  final AutomationLocalizedText? title;

  /// How long the driver waits for the step to succeed, missing for the
  /// runner's default.
  final Duration? timeout;

  const FlowStep({this.label, this.title, this.timeout});

  /// The `action` of the JSON form.
  String get action;

  @override
  Map<String, Object?> toJson() => {
    'action': action,
    'label': ?label,
    'title': ?title?.toJson(),
    'timeoutMs': ?timeout?.inMilliseconds,
  };
}

/// {@category Utils}
///
/// A step that acts on the element its [finder] finds.
abstract class FlowFinderStep extends FlowStep {
  /// Finder of the element the step acts on.
  final FlowFinder finder;

  const FlowFinderStep(this.finder, {super.label, super.title, super.timeout});

  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    'finder': finder.toJson(),
  };
}

/// {@category Utils}
///
/// Taps the element.
final class Tap extends FlowFinderStep {
  const Tap(super.finder, {super.label, super.title, super.timeout});

  @override
  String get action => 'tap';
}

/// {@category Utils}
///
/// Waits until the element is in the tree.
final class WaitFor extends FlowFinderStep {
  const WaitFor(super.finder, {super.label, super.title, super.timeout});

  @override
  String get action => 'waitFor';
}

/// {@category Utils}
///
/// Waits until the element leaves the tree.
final class WaitForAbsent extends FlowFinderStep {
  const WaitForAbsent(super.finder, {super.label, super.title, super.timeout});

  @override
  String get action => 'waitForAbsent';
}

/// {@category Utils}
///
/// Waits until the element is in the tree and a tap can reach it.
final class WaitForTappable extends FlowFinderStep {
  const WaitForTappable(
    super.finder, {
    super.label,
    super.title,
    super.timeout,
  });

  @override
  String get action => 'waitForTappable';
}

/// {@category Utils}
///
/// Scrolls the nearest scrollable until the element is on screen.
final class ScrollIntoView extends FlowFinderStep {
  const ScrollIntoView(super.finder, {super.label, super.title, super.timeout});

  @override
  String get action => 'scrollIntoView';
}

/// {@category Utils}
///
/// Reads the centre of the element and puts it into the report.
final class ProbeCenter extends FlowFinderStep {
  const ProbeCenter(super.finder, {super.label, super.title, super.timeout});

  @override
  String get action => 'probeCenter';
}

/// {@category Utils}
///
/// Drags on the element.
final class Scroll extends FlowFinderStep {
  /// Horizontal distance, in logical pixels, missing for none.
  final double? dx;

  /// Vertical distance, in logical pixels, missing for none.
  final double? dy;

  /// Time over which the pointer moves spread, missing for the runner's
  /// default.
  final Duration? duration;

  /// Pointer moves per second, missing for the runner's default.
  final int? frequency;

  const Scroll(
    super.finder, {
    this.dx,
    this.dy,
    this.duration,
    this.frequency,
    super.label,
    super.title,
    super.timeout,
  });

  @override
  String get action => 'scroll';

  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    'dx': ?dx,
    'dy': ?dy,
    'durationMs': ?duration?.inMilliseconds,
    'frequency': ?frequency,
  };
}

/// {@category Utils}
///
/// Types [text] into the focused element.
final class EnterText extends FlowStep {
  /// Text the step writes.
  final String text;

  const EnterText(this.text, {super.label, super.title, super.timeout});

  @override
  String get action => 'enterText';

  @override
  Map<String, Object?> toJson() => {...super.toJson(), 'text': text};
}

/// {@category Utils}
///
/// Sends the app a command by its wire name.
final class DriverCommand extends FlowStep {
  /// Wire name of the command.
  final String command;

  /// Arguments beside the name. The wire carries each of them as a string.
  final Map<String, Object?> arguments;

  const DriverCommand(
    this.command, {
    this.arguments = const {},
    super.label,
    super.title,
    super.timeout,
  });

  @override
  String get action => 'driverCommand';

  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    'command': command,
    if (arguments.isNotEmpty) 'arguments': writeFlowJsonValue(arguments),
  };
}

/// {@category Utils}
///
/// Opens the window over which the run reads frames.
final class TraceStart extends FlowStep {
  /// How long the screen stays still before the window opens, missing for no
  /// wait.
  final Duration? duration;

  const TraceStart({this.duration, super.label, super.title, super.timeout});

  @override
  String get action => 'traceStart';

  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    'durationMs': ?duration?.inMilliseconds,
  };
}

/// {@category Utils}
///
/// Keeps the window open for [duration], then downloads the timeline.
final class TraceStop extends FlowStep {
  /// How long the window stays open.
  final Duration duration;

  const TraceStop({
    required this.duration,
    super.label,
    super.title,
    super.timeout,
  });

  @override
  String get action => 'traceStop';

  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    'durationMs': duration.inMilliseconds,
  };
}

/// {@category Utils}
///
/// One node that a [ProbeSeries] reads on each cycle.
final class FlowProbe {
  /// Name that extends the label of the step to `<label> <name> <cycle>`.
  final String name;

  /// How far into the window this node joins the cycle, missing for the start.
  final Duration? after;

  /// Finder of the node whose centre the probe reads.
  final FlowFinder finder;

  const FlowProbe({required this.name, required this.finder, this.after});

  /// The probe as the flow JSON holds it.
  Map<String, Object?> toJson() => {
    'name': name,
    'afterMs': ?after?.inMilliseconds,
    'finder': finder.toJson(),
  };
}

/// {@category Utils}
///
/// Reads the centre of each probe on every cycle, for a window of [duration].
final class ProbeSeries extends FlowStep {
  /// Length of the window.
  final Duration duration;

  /// Nodes read on every cycle.
  final List<FlowProbe> probes;

  const ProbeSeries({
    required this.duration,
    required this.probes,
    super.label,
    super.title,
    super.timeout,
  });

  @override
  String get action => 'probeSeries';

  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    'durationMs': duration.inMilliseconds,
    'probes': probes.map((probe) => probe.toJson()).toList(),
  };
}
