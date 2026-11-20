import 'package:collection/collection.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';

import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';

/// {@category Utils}
///
/// Each flow of the automation runner, read in the order of their names.
///
/// A flow that holds a `probeSeries` step measures motion and walks no
/// journey ([AtlasDefinition.holdsProbeSeries]). The definitions leave it
/// out.
final class AtlasDefinitions {
  /// Flows sorted by name.
  final List<AtlasDefinition> flows;

  /// The names of the flows in the order the entry point of the runner lists
  /// them.
  final List<String> declarationOrder;

  const AtlasDefinitions(this.flows, {required this.declarationOrder});

  /// Reads the flows of the runner catalogue of [paths] but the probe
  /// series, in the order of their names.
  factory AtlasDefinitions.read(AtlasLocations paths) {
    final catalogue = AutomationFlowCatalogue.read(
      paths.rootPath,
      paths.runnerEntryPath,
      commandPrefix: paths.project.launchSettings.commandPrefix,
    );
    final names = catalogue.flows.keys.sorted(
      (first, second) => first.compareTo(second),
    );
    final flows = [
      for (final name in names)
        AtlasDefinition.fromCatalogue(name, catalogue, paths),
    ];

    return AtlasDefinitions(
      flows.whereNot((flow) => flow.holdsProbeSeries).toList(),
      declarationOrder: catalogue.flows.keys.toList(),
    );
  }

  /// Each variant of each flow, in catalogue order.
  List<AtlasVariantDefinition> get variants {
    return flows.expand((flow) => flow.variants).toList();
  }

  /// The flow named [name], or fails naming the flows there are.
  AtlasDefinition findFlow(String name) {
    final flow = flows.firstWhereOrNull((flow) => flow.name == name);

    if (flow == null) {
      throw AtlasException(
        'No flow "$name". The catalogue holds '
        '${flows.map((flow) => flow.name).toList()}.',
      );
    }

    return flow;
  }
}

/// {@category Utils}
///
/// One flow: its variants in the order the flow lists them.
final class AtlasDefinition {
  /// Name of the flow, equal to its key in the runner catalogue.
  final String name;

  /// Variants in declaration order.
  final List<AtlasVariantDefinition> variants;

  /// The name of the group the flow declares in Dart, null when it declares
  /// none.
  final String? groupName;

  const AtlasDefinition({
    required this.name,
    required this.variants,
    this.groupName,
  });

  /// Reads the flow [name] out of the [catalogue]. It resolves each variant
  /// in the default locale of [paths].
  ///
  /// Throws a [AtlasException] when the flow declares a `group` without
  /// a string `name`, or when a flow without a probe series lacks a text in
  /// a page locale.
  factory AtlasDefinition.fromCatalogue(
    String name,
    AutomationFlowCatalogue catalogue,
    AtlasLocations paths,
  ) {
    final json = AtlasJson.readObject(
      catalogue.flows[name],
      'The flow "$name"',
    );
    final variants = AtlasJson.tryReadObject(json, 'variants') ?? {};
    final definition = AtlasDefinition(
      name: name,
      groupName: _readGroupName(name, json['group']),
      variants: [
        for (final variant in variants.keys)
          AtlasVariantDefinition(
            isDefault: catalogue.isDefaultVariant(name, variant),
            isInQaCatalogue: json['isInQaCatalogue'] == true,
            automationFlow: catalogue.resolveFlow(
              name,
              variant,
              locale: paths.defaultLocale,
            ),
          ),
      ],
    );

    if (!definition.holdsProbeSeries) {
      definition._requireEveryPageLocale(paths.pageLocales);
    }

    return definition;
  }

  /// What the journey is, in words for people, null when the flow names
  /// none.
  AutomationLocalizedText? get title {
    return variants.firstOrNull?.automationFlow.title;
  }

  /// Whether the flow holds a probe series rather than a journey: a variant
  /// has a `probeSeries` step, the one step that reads probes.
  bool get holdsProbeSeries {
    return variants.any((variant) => variant.automationFlow.holdsProbeSeries);
  }

  /// What the journey is about in one sentence, null when the flow names
  /// none.
  AutomationLocalizedText? get subtitle {
    return variants.firstOrNull?.automationFlow.subtitle;
  }

  /// The variant named [name], or fails naming the variants there are.
  AtlasVariantDefinition findVariant(String name) {
    final variant = variants.firstWhereOrNull(
      (variant) => variant.name == name,
    );

    if (variant == null) {
      throw AtlasException(
        'Flow "${this.name}" has no variant "$name". It holds '
        '${variants.map((variant) => variant.name).toList()}.',
      );
    }

    return variant;
  }

  static String? _readGroupName(String flowName, Object? group) {
    if (group == null) {
      return null;
    }

    if (group case {'name': final String groupName}) {
      return groupName;
    }

    throw AtlasException(
      'The group of flow "$flowName" has no string name: $group.',
    );
  }

  void _requireEveryPageLocale(List<String> pageLocales) {
    for (final variant in variants) {
      final flow = variant.automationFlow;
      final subject = 'Variant "${flow.variant}" of flow "$name"';

      _requireLocales(pageLocales, flow.title, subject, 'title');
      _requireLocales(pageLocales, flow.subtitle, subject, 'subtitle');
      _requireLocales(pageLocales, flow.variantTitle, subject, 'variant title');
      _requireLocales(pageLocales, flow.proves, subject, 'proves');
      _requireLocales(pageLocales, flow.entry?.title, subject, 'entry title');

      for (final item in flow.items) {
        _requireLocales(pageLocales, item.title, subject, _describeItem(item));
      }

      for (final step in flow.steps) {
        _requireLocales(
          pageLocales,
          step.title,
          subject,
          'title of step "${step.label}"',
        );
      }
    }
  }

  static String _describeItem(AutomationItem item) {
    return switch (item) {
      AutomationBlockItem(:final name) => 'title of block "$name"',
      AutomationStepItem(:final label) => 'title of step "$label"',
    };
  }

  static void _requireLocales(
    List<String> pageLocales,
    AutomationLocalizedText? text,
    String subject,
    String what,
  ) {
    if (text == null) {
      return;
    }

    final missing = pageLocales.where(
      (locale) => !text.locales.contains(locale),
    );

    if (missing.isNotEmpty) {
      throw AtlasException(
        '$subject: the $what has no ${missing.join(', ')} text. The page '
        'shows ${pageLocales.join(', ')}.',
      );
    }
  }
}

/// {@category Utils}
///
/// One variant of a flow, assembled into the steps the runner walks.
final class AtlasVariantDefinition {
  /// Whether a run naming no variant walks this one.
  final bool isDefault;

  /// The variant as the runner walks it: resolved steps, scenario and texts.
  final AutomationFlow automationFlow;

  /// Whether the flow of the variant is in the QA catalogue, so a full walk
  /// in the default locale also writes its recording.
  final bool isInQaCatalogue;

  const AtlasVariantDefinition({
    required this.isDefault,
    required this.automationFlow,
    this.isInQaCatalogue = false,
  });

  /// Name of the flow the variant belongs to.
  String get flow => automationFlow.name;

  /// Name of the variant.
  String get name => automationFlow.variant;

  /// The overrides the variant applies to the mock, empty when it has none.
  Map<String, Object?> get scenario => automationFlow.scenarioJson ?? const {};

  /// Hash of what a capture of the variant walks: each resolved step and the
  /// scenario.
  String get defHash => _hashSteps(automationFlow.steps);

  /// Hash of what a capture walks up to the end of each stage, one per user
  /// action: the resolved steps before the next user action and the scenario.
  List<String> get stageStepHashes => _hashStages(_hashSteps);

  /// Hash of the resolved steps a capture walks up to the end of each stage,
  /// one per user action. It does not include the scenario.
  List<String> get stageStepOnlyHashes => _hashStages(_hashStepsOnly);

  /// The run this variant names, the way a report and a stale line name it.
  String get id => automationFlow.id;

  String _hashSteps(Iterable<AutomationStep> steps) {
    return AtlasContentHash.hashJson({
      'steps': steps.map((step) => step.toReport()).toList(),
      'scenario': automationFlow.scenarioJson,
    });
  }

  List<String> _hashStages(
    String Function(Iterable<AutomationStep> steps) hashSteps,
  ) {
    final steps = automationFlow.steps;
    final actionIndexes = [
      for (final (index, step) in steps.indexed)
        if (step.isUserAction) index,
    ];

    return List.generate(
      actionIndexes.length,
      (position) => hashSteps(
        steps.take(actionIndexes.elementAtOrNull(position + 1) ?? steps.length),
      ),
    );
  }

  String _hashStepsOnly(Iterable<AutomationStep> steps) {
    return AtlasContentHash.hashJson({
      'steps': steps.map((step) => step.toReport()).toList(),
    });
  }
}
