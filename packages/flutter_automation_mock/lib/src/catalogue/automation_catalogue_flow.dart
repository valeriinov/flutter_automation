import 'package:flutter_automation_mock/src/catalogue/automation_catalogue_step.dart';
import 'package:flutter_automation_mock/src/catalogue/catalogue_json.dart';

/// {@category Utils}
///
/// One way through a flow, with the scenario it needs and the steps a run of it
/// walked.
final class AutomationCatalogueVariant {
  static const _nameKey = 'name';
  static const _titleKey = 'title';
  static const _provesKey = 'proves';
  static const _entryKey = 'entry';
  static const _scenarioKey = 'scenario';
  static const _itemsKey = 'items';
  static const _stepsKey = 'steps';

  /// Name the command line asks the variant by.
  final String name;

  /// What way through the journey the variant walks, by locale.
  final Map<String, String>? title;

  /// What the variant proves, by locale.
  final Map<String, String>? proves;

  /// Where the variant enters its journey, by locale.
  final Map<String, String>? entry;

  /// Scenario JSON of the variant: the overrides of its flow, then its own.
  final Map<String, Object?> scenario;

  /// Names of the blocks and steps the variant walks, in order.
  final List<String> items;

  /// Steps a run of the variant walked.
  final List<AutomationCatalogueStep> steps;

  const AutomationCatalogueVariant({
    required this.name,
    this.title,
    this.proves,
    this.entry,
    this.scenario = const {},
    this.items = const [],
    this.steps = const [],
  });

  /// Reads the variant out of [json].
  factory AutomationCatalogueVariant.fromJson(Map<String, Object?> json) {
    final items = json[_itemsKey];

    return AutomationCatalogueVariant(
      name: CatalogueJson.tryString(json, _nameKey) ?? '',
      title: CatalogueJson.tryText(json, _titleKey),
      proves: CatalogueJson.tryText(json, _provesKey),
      entry: CatalogueJson.tryText(json, _entryKey),
      scenario: CatalogueJson.tryObject(json, _scenarioKey) ?? const {},
      items: items is List<Object?> ? items.whereType<String>().toList() : [],
      steps: CatalogueJson.objects(
        json,
        _stepsKey,
      ).map(AutomationCatalogueStep.fromJson).toList(growable: false),
    );
  }

  /// The variant as JSON.
  Map<String, Object?> toJson() {
    return {
      _nameKey: name,
      _titleKey: ?title,
      _provesKey: ?proves,
      _entryKey: ?entry,
      _scenarioKey: scenario,
      _itemsKey: items,
      _stepsKey: steps.map((step) => step.toJson()).toList(),
    };
  }
}

/// {@category Utils}
///
/// One outcome of a fork: the variant, the answer it gets and what sets it
/// apart from the other variants.
final class AutomationCatalogueBranch {
  static const _variantKey = 'variant';
  static const _statusCodeKey = 'statusCode';
  static const _labelKey = 'label';
  static const _isChosenBeforeStartKey = 'isChosenBeforeStart';

  /// Name of the variant that takes the branch.
  final String variant;

  /// Status code the variant gets at the fork, missing when the run saw none.
  final int? statusCode;

  /// What names the branch for the tester: the title of the variant.
  final String label;

  /// Whether the tester picks the branch before the walk starts, because its
  /// scenario changes a setting that only a restart of the app applies.
  ///
  /// Every branch of a fork carries the same value: the tester picks the whole
  /// fork before the start or at the fork.
  final bool isChosenBeforeStart;

  const AutomationCatalogueBranch({
    required this.variant,
    required this.label,
    this.statusCode,
    this.isChosenBeforeStart = false,
  });

  /// Reads the branch out of [json].
  factory AutomationCatalogueBranch.fromJson(Map<String, Object?> json) {
    final statusCode = json[_statusCodeKey];

    return AutomationCatalogueBranch(
      variant: CatalogueJson.tryString(json, _variantKey) ?? '',
      label: CatalogueJson.tryString(json, _labelKey) ?? '',
      statusCode: statusCode is int ? statusCode : null,
      isChosenBeforeStart: json[_isChosenBeforeStartKey] == true,
    );
  }

  /// The branch as JSON.
  Map<String, Object?> toJson() {
    return {
      _variantKey: variant,
      _statusCodeKey: ?statusCode,
      _labelKey: label,
      if (isChosenBeforeStart) _isChosenBeforeStartKey: true,
    };
  }
}

/// {@category Utils}
///
/// The place where the variants of a flow part: the earlier of the first step
/// at which they differ and the first request at which they get different
/// answers.
final class AutomationCatalogueFork {
  static const _stepIndexKey = 'stepIndex';
  static const _methodKey = 'method';
  static const _pathKey = 'path';
  static const _branchesKey = 'branches';

  /// Index of the step at which the variants part.
  final int stepIndex;

  /// HTTP method of the request that parts the variants, missing when their
  /// steps part them.
  final String? method;

  /// Path of the request that parts the variants, missing when their steps
  /// part them.
  final String? path;

  /// One branch per variant.
  final List<AutomationCatalogueBranch> branches;

  const AutomationCatalogueFork({
    required this.stepIndex,
    required this.branches,
    this.method,
    this.path,
  });

  /// Reads the fork out of [json].
  factory AutomationCatalogueFork.fromJson(Map<String, Object?> json) {
    final stepIndex = json[_stepIndexKey];

    return AutomationCatalogueFork(
      stepIndex: stepIndex is int ? stepIndex : 0,
      method: CatalogueJson.tryString(json, _methodKey),
      path: CatalogueJson.tryString(json, _pathKey),
      branches: CatalogueJson.objects(
        json,
        _branchesKey,
      ).map(AutomationCatalogueBranch.fromJson).toList(growable: false),
    );
  }

  /// The fork as JSON.
  Map<String, Object?> toJson() {
    return {
      _stepIndexKey: stepIndex,
      _methodKey: ?method,
      _pathKey: ?path,
      _branchesKey: branches.map((branch) => branch.toJson()).toList(),
    };
  }
}

/// {@category Utils}
///
/// One flow of the catalogue: its variants and the fork between them.
final class AutomationCatalogueFlow {
  static const _nameKey = 'name';
  static const _groupKey = 'group';
  static const _titleKey = 'title';
  static const _subtitleKey = 'subtitle';
  static const _defaultVariantKey = 'defaultVariant';
  static const _variantsKey = 'variants';
  static const _forkKey = 'fork';

  /// Name the command line asks the flow by.
  final String name;

  /// Name of the group the flow belongs to, missing when it has none.
  final String? group;

  /// What the journey is, by locale.
  final Map<String, String>? title;

  /// What the journey is about in one sentence, by locale.
  final Map<String, String>? subtitle;

  /// Variant a run walks when it names none.
  final String? defaultVariant;

  /// One variant per way through the flow.
  final List<AutomationCatalogueVariant> variants;

  /// The first request where the answers of the variants differ, missing when
  /// they never do.
  final AutomationCatalogueFork? fork;

  const AutomationCatalogueFlow({
    required this.name,
    required this.variants,
    this.group,
    this.title,
    this.subtitle,
    this.defaultVariant,
    this.fork,
  });

  /// Reads the flow out of [json].
  factory AutomationCatalogueFlow.fromJson(Map<String, Object?> json) {
    final fork = CatalogueJson.tryObject(json, _forkKey);

    return AutomationCatalogueFlow(
      name: CatalogueJson.tryString(json, _nameKey) ?? '',
      group: CatalogueJson.tryString(json, _groupKey),
      title: CatalogueJson.tryText(json, _titleKey),
      subtitle: CatalogueJson.tryText(json, _subtitleKey),
      defaultVariant: CatalogueJson.tryString(json, _defaultVariantKey),
      variants: CatalogueJson.objects(
        json,
        _variantsKey,
      ).map(AutomationCatalogueVariant.fromJson).toList(growable: false),
      fork: fork == null ? null : AutomationCatalogueFork.fromJson(fork),
    );
  }

  /// The flow as JSON.
  Map<String, Object?> toJson() {
    return {
      _nameKey: name,
      _groupKey: ?group,
      _titleKey: ?title,
      _subtitleKey: ?subtitle,
      _defaultVariantKey: ?defaultVariant,
      _variantsKey: variants.map((variant) => variant.toJson()).toList(),
      _forkKey: ?fork?.toJson(),
    };
  }
}
