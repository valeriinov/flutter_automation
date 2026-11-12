import 'package:flutter_driver/flutter_driver.dart';

import 'package:flutter_automation_runner/src/automation_block_library.dart';
import 'package:flutter_automation_runner/src/automation_finder_kind.dart';
import 'package:flutter_automation_runner/src/automation_finder_spec.dart';
import 'package:flutter_automation_runner/src/automation_flow_entry.dart';
import 'package:flutter_automation_runner/src/automation_host_finders.dart';
import 'package:flutter_automation_runner/src/automation_localized_text.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';
import 'package:flutter_automation_runner/src/automation_step_label.dart';

typedef _FinderResolver =
    AutomationFinderSpec Function(Object? json, String subject);

/// {@category Utils}
///
/// One way through a journey, read from `flows/<name>.json`.
///
/// A journey has many ways through it. Examples are an order placed from a
/// saved basket or from a fresh one, and a coupon applied or declined. They
/// share almost each step. The file holds them as variants over a shared
/// library of step blocks. An author edits a step that changes once for each
/// variant that walks through it.
///
/// A flow is data, not code, so that one run costs a single command. The runner
/// sends the steps to the app, which already runs, back to back. Two steps
/// decide anything. `probeSeries` cycles its probes until its own window of
/// time has elapsed. A run therefore measures a movement over a slice of the
/// clock, not over a count of round trips. `traceStop` holds the timeline open
/// for its own window before it downloads the timeline.
final class AutomationFlow {
  static const _titleKey = 'title';
  static const _subtitleKey = 'subtitle';
  static const _provesKey = 'proves';
  static const _stateOfKey = 'stateOf';

  /// Name of the flow, which matches its file name.
  final String name;

  /// Name of the variant this run walks.
  final String variant;

  /// Actions sent to the driver, in order.
  final List<AutomationStep> steps;

  /// The `items` list of the variant, one item per block and per inline step,
  /// in the order a run walks them.
  final List<AutomationItem> items;

  /// Scenario that a run of the variant uses, missing when neither
  /// the variant nor its flow names one.
  ///
  /// The scenario of the variant holds the whole scenario of the run. The one
  /// of the flow applies only to a variant that names none.
  final Map<String, Object?>? scenarioJson;

  /// What the journey is, in words for people, missing when the file names
  /// none.
  final AutomationLocalizedText? title;

  /// What the journey is about in one sentence, missing when the file names
  /// none.
  final AutomationLocalizedText? subtitle;

  /// What way through the journey the variant walks, missing when the file
  /// names none.
  final AutomationLocalizedText? variantTitle;

  /// What the variant proves when a run walks it, missing when the file names
  /// none.
  final AutomationLocalizedText? proves;

  /// Where the variant enters its journey, missing when it starts where the
  /// other variants of the file start.
  final AutomationFlowEntry? entry;

  /// The variant of the same file whose frame this variant shows in another
  /// state, missing for a variant that is a way of its own.
  final String? stateOf;

  const AutomationFlow({
    required this.name,
    required this.variant,
    required this.steps,
    required this.items,
    required this.scenarioJson,
    required this.title,
    required this.subtitle,
    required this.variantTitle,
    required this.proves,
    required this.entry,
    required this.stateOf,
  });

  /// Reads one variant out of the decoded contents of a flow file.
  ///
  /// The [name] parameter is the file name without its extension.
  /// The [variant] parameter is the variant asked for on the command line.
  /// The [json] parameter is the decoded file.
  /// The [blocks] parameter is the library that the variant draws its steps
  /// from.
  /// The [finders] parameter is the registry that parses its finders.
  /// The [locale] parameter is the locale of a per-locale finder value.
  /// The [anchorOf] parameter gives the moment from which a date finder counts
  /// days.
  factory AutomationFlow.fromJson({
    required String name,
    required String? variant,
    required Object? json,
    required AutomationBlockLibrary blocks,
    required AutomationFinderRegistry finders,
    required String locale,
    AutomationAnchorReader anchorOf =
        AutomationFinderRegistry.readCurrentMoment,
  }) {
    final flow = _readObject(json, 'Flow "$name"');
    final variants = _readVariants(name, flow);
    final resolvedName = _resolveVariantName(
      flow: name,
      requested: variant,
      declared: flow['defaultVariant'],
      variants: variants,
    );
    final variantSubject = 'Variant "$resolvedName" of "$name"';
    final entry = _readObject(variants[resolvedName], variantSubject);
    final items = _readItems(name, resolvedName, entry);

    return AutomationFlow(
      name: name,
      variant: resolvedName,
      steps: blocks
          .expand(items)
          .map(
            (expanded) => AutomationStep.fromJson(
              expanded.step,
              block: expanded.block,
              finders: finders,
              locale: locale,
              anchorOf: anchorOf,
            ),
          )
          .toList(growable: false),
      items: blocks.describe(items),
      scenarioJson: _readScenarioJson(flow['scenario'], entry['scenario']),
      title: AutomationLocalizedText.tryRead(flow, _titleKey, 'Flow "$name"'),
      subtitle: AutomationLocalizedText.tryRead(
        flow,
        _subtitleKey,
        'Flow "$name"',
      ),
      variantTitle: AutomationLocalizedText.tryRead(
        entry,
        _titleKey,
        variantSubject,
      ),
      proves: AutomationLocalizedText.tryRead(
        entry,
        _provesKey,
        variantSubject,
      ),
      entry: AutomationFlowEntry.tryRead(entry, variantSubject),
      stateOf: _tryReadStateOf(resolvedName, entry, variants, variantSubject),
    );
  }

  /// The run this flow file resolved to, the way a report names it.
  String get id => '$name $variant';

  /// The variant a run walks when it names none: the declared
  /// `defaultVariant`, else the only variant, else `null`.
  ///
  /// The [declared] parameter is the flow file's `defaultVariant` value and
  /// the [variants] parameter is its `variants` map.
  static String? resolveDefaultVariant(
    Object? declared,
    Map<String, Object?> variants,
  ) {
    if (declared is String) {
      return declared;
    }

    return variants.length == 1 ? variants.keys.firstOrNull : null;
  }

  static Map<String, Object?> _readObject(Object? json, String subject) {
    if (json is! Map<String, Object?>) {
      throw AutomationRunnerException('$subject is not a JSON object.');
    }

    return json;
  }

  static Map<String, Object?> _readVariants(
    String name,
    Map<String, Object?> flow,
  ) {
    final variants = flow['variants'];

    if (variants is! Map<String, Object?> || variants.isEmpty) {
      throw AutomationRunnerException(
        'Flow "$name" has no "variants" map. A flow holds one entry per way '
        'through it, each naming the blocks it walks in an "items" list.',
      );
    }

    return variants;
  }

  static String _resolveVariantName({
    required String flow,
    required String? requested,
    required Object? declared,
    required Map<String, Object?> variants,
  }) {
    final name = requested ?? resolveDefaultVariant(declared, variants);

    if (name == null) {
      throw AutomationRunnerException(
        'Flow "$flow" holds ${variants.keys.toList()} and names no '
        '"defaultVariant". Pass the variant after the flow.',
      );
    }

    if (!variants.containsKey(name)) {
      throw AutomationRunnerException(
        'Flow "$flow" has no variant "$name". It holds '
        '${variants.keys.toList()}.',
      );
    }

    return name;
  }

  static List<Object?> _readItems(
    String flow,
    String variant,
    Map<String, Object?> entry,
  ) {
    final items = entry['items'];

    if (items is! List<Object?>) {
      throw AutomationRunnerException(
        'Variant "$variant" of "$flow" has no "items" list.',
      );
    }

    return items;
  }

  static String? _tryReadStateOf(
    String variant,
    Map<String, Object?> entry,
    Map<String, Object?> variants,
    String subject,
  ) {
    final stateOf = entry[_stateOfKey];

    if (stateOf == null) {
      return null;
    }

    if (stateOf case final String name
        when _isOtherVariant(name, variant, variants)) {
      return name;
    }

    throw AutomationRunnerException(
      '$subject has a "$_stateOfKey" "$stateOf" naming no other variant of '
      'the file. It holds ${variants.keys.toList()}.',
    );
  }

  static bool _isOtherVariant(
    String name,
    String variant,
    Map<String, Object?> variants,
  ) {
    return name != variant && variants.containsKey(name);
  }

  static Map<String, Object?>? _readScenarioJson(
    Object? flow,
    Object? variant,
  ) {
    if (variant is Map<String, Object?>) {
      return variant;
    }

    return flow is Map<String, Object?> ? flow : null;
  }
}

/// {@category Utils}
///
/// One node that a `probeSeries` step reads on each cycle of its phase.
///
/// The reads of one probe make a series. They carry one label numbered by the
/// cycle, so whoever reads the report walks the numbers of one node over one
/// movement.
final class AutomationProbe {
  /// Name that extends the label of the phase to
  /// `<phase> <name> <cycle>`.
  final String name;

  /// How far into the phase this node joins the cycle.
  ///
  /// The movement itself brings a node on screen, so the node is not there when
  /// the phase opens. A probe that asks for it before it arrives fails the run.
  final Duration after;

  /// Element the probe reads the centre of.
  final SerializableFinder finder;

  const AutomationProbe({
    required this.name,
    required this.after,
    required this.finder,
  });
}

/// {@category Utils}
///
/// One driver action of an [AutomationFlow].
///
/// The parser reads each argument while it parses the flow, so a malformed step
/// fails before the run touches the app. A run therefore either walks the whole
/// flow or reports which step stopped it.
final class AutomationStep {
  static const _probeSeriesAction = 'probeSeries';
  static const _traceStartAction = 'traceStart';
  static const _traceStopAction = 'traceStop';
  static const _defaultTimeout = Duration(seconds: 10);
  static const _defaultScrollDuration = Duration(seconds: 6);
  static const _defaultScrollFrequency = 60;

  /// Driver call this step sends.
  final String action;

  /// Human-readable name of the step, used in the run report.
  final String label;

  /// Horizontal distance of a `scroll`, in logical pixels.
  final double dx;

  /// Vertical distance of a `scroll`, in logical pixels.
  final double dy;

  /// Time over which a `scroll` spreads its pointer moves. It is also the
  /// window for which a `probeSeries` cycles its probes, and the window for
  /// which a `traceStop` keeps the timeline open before it downloads it.
  final Duration duration;

  /// Pointer moves per second a `scroll` sends.
  final int frequency;

  /// How long the driver waits for the step to succeed.
  final Duration timeout;

  /// Arguments a `driverCommand` sends beside its name, empty for the rest.
  final Map<String, String> arguments;

  /// Nodes a `probeSeries` reads on every cycle, empty for the rest.
  final List<AutomationProbe> probes;

  /// What the person does in the step, in words for people, missing when the
  /// file names none.
  final AutomationLocalizedText? title;

  /// Element the step acts on, missing for actions that address the focused
  /// one.
  final AutomationFinderSpec? spec;

  /// Text an `enterText` writes into the focused element.
  final String? text;

  /// Wire name a `driverCommand` sends, missing for the named actions.
  final String? command;

  /// Finder JSON of the step as the flow file writes it, with each block
  /// parameter substituted, missing for a step without a finder.
  final Map<String, Object?>? target;

  /// Block that declared the step, missing for an inline step.
  final String? block;

  const AutomationStep({
    required this.action,
    required this.label,
    required this.dx,
    required this.dy,
    required this.duration,
    required this.frequency,
    required this.timeout,
    required this.arguments,
    required this.probes,
    required this.title,
    required this.spec,
    required this.text,
    required this.command,
    required this.target,
    required this.block,
  });

  /// Reads a step out of one expanded item of a variant's `items` list.
  ///
  /// The [json] parameter is the step object, with each block parameter already
  /// substituted.
  /// The [block] parameter is the block that declared it, `null` for an inline
  /// step.
  /// The [finders] parameter is the registry that parses its finder.
  /// The [locale] parameter is the locale of a per-locale finder value.
  /// The [anchorOf] parameter gives the moment from which a date finder counts
  /// days.
  factory AutomationStep.fromJson(
    Object? json, {
    required String? block,
    required AutomationFinderRegistry finders,
    required String locale,
    AutomationAnchorReader anchorOf =
        AutomationFinderRegistry.readCurrentMoment,
  }) {
    if (json is! Map<String, Object?>) {
      throw const AutomationRunnerException('Step is not a JSON object.');
    }

    final action = _readString(json, 'action');
    final target = _readTarget(json);
    final label = AutomationStepLabel.resolve(json, action);
    final text = json['text'];
    final command = json['command'];
    final subject = _describeStep(label, block);

    AutomationFinderSpec resolveFinder(Object? finder, String finderSubject) {
      return finders.resolve(
        finder,
        locale: locale,
        subject: finderSubject,
        anchorOf: anchorOf,
      );
    }

    return AutomationStep(
      action: action,
      label: label,
      dx: _readDouble(json, 'dx', 0),
      dy: _readDouble(json, 'dy', 0),
      duration: _readStepDuration(json, action),
      frequency: _readInt(json, 'frequency', _defaultScrollFrequency),
      timeout: _readDuration(json, 'timeoutMs', _defaultTimeout),
      arguments: _readArguments(json),
      probes: _readProbes(json, action, resolveFinder),
      title: AutomationLocalizedText.tryRead(json, 'title', subject),
      spec: target == null ? null : resolveFinder(target, subject),
      text: text is String ? text : null,
      command: command is String ? command : null,
      target: target,
      block: block,
    );
  }

  /// Whether the step is something a person does on screen: a tap, typed text
  /// or a drag. It is not a wait, a read or a hold.
  bool get isUserAction {
    switch (action) {
      case 'tap':
      case 'enterText':
        return true;
      case 'scroll':
        return dx != 0 || dy != 0;
      default:
        return false;
    }
  }

  /// The driver finder of [spec], missing when the step has none.
  SerializableFinder? get finder {
    final spec = this.spec;

    return spec == null ? null : AutomationHostFinders.build(spec);
  }

  /// The step as the resolved JSON a dry run prints.
  Map<String, Object?> toReport() {
    return {
      'action': action,
      'label': label,
      'block': ?block,
      'target': ?target,
      'timeoutMs': timeout.inMilliseconds,
      if (text != null) 'text': text,
      if (dx != 0 || dy != 0) 'dx': dx,
      if (dx != 0 || dy != 0) 'dy': dy,
    };
  }

  static Map<String, Object?>? _readTarget(Map<String, Object?> json) {
    final value = json['finder'];

    if (value is Map<String, Object?>?) {
      return value;
    }

    throw const AutomationRunnerException('Finder is not a JSON object.');
  }

  static String _describeStep(String label, String? block) {
    return block == null ? 'Step "$label"' : 'Step "$label" of block "$block"';
  }

  static Duration _readStepDuration(Map<String, Object?> json, String action) {
    if (_needsDeclaredDuration(action) && json['durationMs'] is! num) {
      throw AutomationRunnerException(
        'A "$action" step needs a "durationMs". Its window is bounded by '
        'elapsed time rather than by a count of round trips, so that a faster '
        'machine covers the same slice of the movement, and the scroll default '
        'this field otherwise falls back to would name a window nobody asked '
        'for.',
      );
    }

    return _readDuration(json, 'durationMs', _resolveDurationFallback(action));
  }

  /// The duration of a step when it declares none.
  ///
  /// A `traceStart` opens its window the moment the step before it ended,
  /// unless it declares how long the screen stays still first. A scroll takes
  /// the default that each scroll takes.
  static Duration _resolveDurationFallback(String action) {
    return action == _traceStartAction ? Duration.zero : _defaultScrollDuration;
  }

  /// Whether the step's window is time and has no honest default.
  static bool _needsDeclaredDuration(String action) {
    return action == _probeSeriesAction || action == _traceStopAction;
  }

  static List<AutomationProbe> _readProbes(
    Map<String, Object?> json,
    String action,
    _FinderResolver resolveFinder,
  ) {
    if (action != _probeSeriesAction) {
      return const [];
    }

    final value = json['probes'];

    if (value is! List<Object?> || value.isEmpty) {
      throw const AutomationRunnerException(
        'A "probeSeries" step needs a non-empty "probes" list.',
      );
    }

    final probes = value
        .map((probe) => _readProbe(probe, resolveFinder))
        .toList(growable: false);

    _validateProbes(probes);

    return probes;
  }

  static AutomationProbe _readProbe(
    Object? json,
    _FinderResolver resolveFinder,
  ) {
    if (json is! Map<String, Object?>) {
      throw const AutomationRunnerException('Probe is not a JSON object.');
    }

    final name = _readString(json, 'name');

    return AutomationProbe(
      name: name,
      after: _readDuration(json, 'afterMs', Duration.zero),
      finder: AutomationHostFinders.build(
        resolveFinder(json['finder'], 'Probe "$name"'),
      ),
    );
  }

  static void _validateProbes(List<AutomationProbe> probes) {
    final names = <String>{};

    for (final probe in probes) {
      if (!names.add(probe.name)) {
        throw AutomationRunnerException(
          'A "probeSeries" step repeats probe "${probe.name}".',
        );
      }
    }
  }

  static String _readString(Map<String, Object?> json, String key) {
    final value = json[key];

    if (value is String) {
      return value;
    }

    throw AutomationRunnerException('Step has no string "$key".');
  }

  static double _readDouble(
    Map<String, Object?> json,
    String key,
    double fallback,
  ) {
    final value = json[key];

    return value is num ? value.toDouble() : fallback;
  }

  static int _readInt(Map<String, Object?> json, String key, int fallback) {
    final value = json[key];

    return value is num ? value.toInt() : fallback;
  }

  static Duration _readDuration(
    Map<String, Object?> json,
    String key,
    Duration fallback,
  ) {
    final value = json[key];

    return value is num ? Duration(milliseconds: value.toInt()) : fallback;
  }

  static Map<String, String> _readArguments(Map<String, Object?> json) {
    final value = json['arguments'];

    if (value == null) {
      return const {};
    }

    if (value is! Map<String, Object?>) {
      throw const AutomationRunnerException(
        'Step "arguments" is not a JSON object.',
      );
    }

    // The wire carries every argument as a string, so a JSON `false` and a
    // JSON `"false"` reach the app as the same command.
    return value.map((key, argument) => MapEntry(key, '$argument'));
  }
}
