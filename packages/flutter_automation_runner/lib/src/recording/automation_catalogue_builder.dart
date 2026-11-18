import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_mock/mock_section.dart';

import 'package:flutter_automation_runner/src/definition/automation_flow_group.dart';
import 'package:flutter_automation_runner/src/recording/automation_recording.dart';

/// {@category Utils}
///
/// Builds the catalogue of the panel out of the flows and the recordings of
/// their runs.
///
/// The catalogue holds the flows whose JSON carries `isInQaCatalogue: true`.
/// The recording of a variant counts only when its run passed. A step that
/// serves the run stays in and carries a mark.
///
/// The fork of a flow stands at the earlier of two places. The first is the
/// first step at which two variants differ in the action, finder or text. The
/// builder reads the step fork only where every variant kept the step JSON.
/// The second is the first request at which their answers differ in the code
/// or the body. A request is the n-th call of one method and path inside its
/// variant.
///
/// The catalogue lists the groups of [groupOrder] first, in its order, then the
/// other groups in the order of their first flow. It lists the areas of the
/// groups in the order they first stand.
///
/// A branch carries the title of its variant. The tester picks a branch before
/// the start when its scenario differs in a restart key of a section from the
/// scenario of another branch. An empty scenario counts as a scenario.
final class AutomationCatalogueBuilder {
  /// Key of the flow JSON that puts the flow in the catalogue.
  static const isInQaCatalogueKey = 'isInQaCatalogue';

  static const _equality = DeepCollectionEquality();

  final Map<String, Object?> _flows;
  final List<AutomationRecording> _recordings;
  final List<MockSection<Object?>> _sections;
  final Map<String, String> _dateFormats;
  final Map<String, String> _dateValueKeys;
  final List<AutomationFlowGroup> _groupOrder;

  /// Creates a builder.
  ///
  /// The [flows] parameter maps a flow name to its flow JSON.
  /// The [recordings] parameter holds the recordings of the runs.
  /// The [sections] parameter lists the sections of the mock, whose
  /// `restartKeys` decide which branch is chosen before the start.
  /// The [dateFormats] and [dateValueKeys] parameters are the date settings of
  /// the project. The catalogue carries them, so the player reads a date
  /// finder as the runner does. The [groupOrder] parameter lists the groups in
  /// the order the catalogue shows them.
  const AutomationCatalogueBuilder({
    required Map<String, Object?> flows,
    required List<AutomationRecording> recordings,
    List<MockSection<Object?>> sections = const [],
    Map<String, String> dateFormats = const {},
    Map<String, String> dateValueKeys = const {},
    List<AutomationFlowGroup> groupOrder = const [],
  }) : _flows = flows,
       _recordings = recordings,
       _sections = sections,
       _dateFormats = dateFormats,
       _dateValueKeys = dateValueKeys,
       _groupOrder = groupOrder;

  /// The catalogue of the flows a tester walks.
  AutomationCatalogue build() {
    final flows = <AutomationCatalogueFlow>[];
    final groups = <String, AutomationCatalogueGroup>{};
    final areas = <String, AutomationCatalogueArea>{};

    for (final MapEntry(:key, :value) in _flows.entries) {
      final json = CatalogueJson.asObject(value);

      if (json[isInQaCatalogueKey] == true) {
        flows.add(_buildFlow(key, json));
        _collectGroup(groups, areas, json);
      }
    }

    final ordered = _orderGroups(groups);

    return AutomationCatalogue(
      areas: _orderAreas(ordered, areas),
      groups: ordered,
      flows: flows,
      dateFormats: _dateFormats,
      dateValueKeys: _dateValueKeys,
    );
  }

  void _collectGroup(
    Map<String, AutomationCatalogueGroup> groups,
    Map<String, AutomationCatalogueArea> areas,
    Map<String, Object?> flow,
  ) {
    final json = CatalogueJson.asObject(flow['group']);
    final areaJson = CatalogueJson.asObject(json['area']);
    final area = AutomationCatalogueArea.fromJson(areaJson);
    final group = AutomationCatalogueGroup.fromJson({
      ...json,
      if (area.name.isNotEmpty) 'area': area.name,
    });

    if (area.name.isNotEmpty) {
      areas.putIfAbsent(area.name, () => area);
    }

    if (group.name.isNotEmpty) {
      groups.putIfAbsent(group.name, () => group);
    }
  }

  List<AutomationCatalogueGroup> _orderGroups(
    Map<String, AutomationCatalogueGroup> groups,
  ) {
    final named = _groupOrder
        .map((group) => groups[group.name])
        .nonNulls
        .toList(growable: false);

    return [
      ...named,
      ...groups.values.where((group) => !named.contains(group)),
    ];
  }

  List<AutomationCatalogueArea> _orderAreas(
    List<AutomationCatalogueGroup> groups,
    Map<String, AutomationCatalogueArea> areas,
  ) {
    final names = groups.map((group) => group.area).nonNulls.toSet();

    return [for (final name in names) ?areas[name]];
  }

  AutomationCatalogueFlow _buildFlow(String name, Map<String, Object?> json) {
    final variantsJson = CatalogueJson.asObject(json['variants']);
    final variants = [
      for (final MapEntry(:key, :value) in variantsJson.entries)
        _buildVariant(name, key, CatalogueJson.asObject(value)),
    ];
    final group = AutomationCatalogueGroup.fromJson(
      CatalogueJson.asObject(json['group']),
    );

    return AutomationCatalogueFlow(
      name: name,
      group: group.name.isEmpty ? null : group.name,
      title: CatalogueJson.tryText(json, 'title'),
      subtitle: CatalogueJson.tryText(json, 'subtitle'),
      defaultVariant: CatalogueJson.tryString(json, 'defaultVariant'),
      variants: variants,
      fork: _findFork(variants),
    );
  }

  AutomationCatalogueVariant _buildVariant(
    String flow,
    String name,
    Map<String, Object?> json,
  ) {
    final recording = _recordings.firstWhereOrNull(
      (recording) =>
          recording.ok && recording.flow == flow && recording.variant == name,
    );

    return AutomationCatalogueVariant(
      name: name,
      title: CatalogueJson.tryText(json, 'title'),
      proves: CatalogueJson.tryText(json, 'proves'),
      entry: CatalogueJson.tryText(
        CatalogueJson.asObject(json['entry']),
        'title',
      ),
      scenario: CatalogueJson.asObject(json['scenario']),
      items: CatalogueJson.asList(json['items']).map(_describeItem).toList(),
      steps: [
        for (final step in recording?.steps ?? const <AutomationRecordedStep>[])
          AutomationCatalogueStep.fromJson({
            ...?step.step,
            AutomationCatalogueStep.labelKey: step.label,
            AutomationCatalogueStep.isServiceKey: step.isService,
            AutomationCatalogueStep.requestsKey: [
              for (final request in step.requests) request.toJson(),
            ],
          }),
      ],
    );
  }

  String _describeItem(Object? item) {
    if (item is String) {
      return item;
    }

    final json = CatalogueJson.asObject(item);
    final name = json['block'] ?? json['label'] ?? json['action'];

    return '$name';
  }

  AutomationCatalogueFork? _findFork(
    List<AutomationCatalogueVariant> variants,
  ) {
    final walked = variants
        .where((variant) => variant.steps.isNotEmpty)
        .toList(growable: false);

    if (walked.length < 2) {
      return null;
    }

    final byStep = _tryBuildStepFork(walked);
    final byRequest = _tryBuildRequestFork(walked);

    if (byStep == null || byRequest == null) {
      return byStep ?? byRequest;
    }

    return byRequest.stepIndex < byStep.stepIndex ? byRequest : byStep;
  }

  AutomationCatalogueFork? _tryBuildStepFork(
    List<AutomationCatalogueVariant> walked,
  ) {
    final length = walked.map((variant) => variant.steps.length).min;

    for (int index = 0; index < length; index += 1) {
      if (_stepsPartAt(walked, index)) {
        return AutomationCatalogueFork(
          stepIndex: index,
          branches: [
            for (final variant in walked) _buildBranch(variant, walked),
          ],
        );
      }
    }

    return null;
  }

  bool _stepsPartAt(List<AutomationCatalogueVariant> walked, int index) {
    if (walked.any((variant) => variant.steps[index].action == null)) {
      return false;
    }

    final keys = walked.map((variant) => _stepKeyAt(variant, index)).toSet();

    return keys.length > 1;
  }

  String _stepKeyAt(AutomationCatalogueVariant variant, int index) {
    final step = variant.steps[index];

    return '${step.action}|${jsonEncode(step.finder)}|${step.text}';
  }

  AutomationCatalogueFork? _tryBuildRequestFork(
    List<AutomationCatalogueVariant> walked,
  ) {
    final calls = {for (final variant in walked) variant: _indexCalls(variant)};
    final keys = _orderKeys(calls.values);

    for (final key in keys) {
      final fork = _tryBuildFork(calls, key);

      if (fork != null) {
        return fork;
      }
    }

    return null;
  }

  Map<_CallKey, _Call> _indexCalls(AutomationCatalogueVariant variant) {
    final calls = <_CallKey, _Call>{};
    final counts = <(String, String), int>{};

    for (int stepIndex = 0; stepIndex < variant.steps.length; stepIndex += 1) {
      for (final request in variant.steps[stepIndex].requests) {
        final route = (request.method, request.path);
        final occurrence = counts[route] ?? 0;

        counts[route] = occurrence + 1;
        calls[(request.method, request.path, occurrence)] = (
          stepIndex: stepIndex,
          request: request,
        );
      }
    }

    return calls;
  }

  List<_CallKey> _orderKeys(Iterable<Map<_CallKey, _Call>> calls) {
    final firstStep = <_CallKey, int>{};

    for (final variantCalls in calls) {
      for (final MapEntry(:key, :value) in variantCalls.entries) {
        final known = firstStep[key];

        firstStep[key] = known == null || value.stepIndex < known
            ? value.stepIndex
            : known;
      }
    }

    return firstStep.keys.sortedBy<num>((key) => firstStep[key] ?? 0);
  }

  AutomationCatalogueFork? _tryBuildFork(
    Map<AutomationCatalogueVariant, Map<_CallKey, _Call>> calls,
    _CallKey callKey,
  ) {
    final answers = <AutomationCatalogueVariant, _Call>{
      for (final MapEntry(:key, :value) in calls.entries)
        if (value[callKey] != null) key: ?value[callKey],
    };

    if (answers.length < 2 || !_differ(answers.values)) {
      return null;
    }

    return AutomationCatalogueFork(
      stepIndex: answers.values.map((call) => call.stepIndex).min,
      method: callKey.$1,
      path: callKey.$2,
      branches: [
        for (final MapEntry(:key, :value) in answers.entries)
          _buildBranch(key, answers.keys, statusCode: value.request.statusCode),
      ],
    );
  }

  bool _differ(Iterable<_Call> answers) {
    final first = answers.first.request;

    return answers.any(
      (answer) =>
          answer.request.statusCode != first.statusCode ||
          !_equality.equals(answer.request.response, first.response),
    );
  }

  AutomationCatalogueBranch _buildBranch(
    AutomationCatalogueVariant variant,
    Iterable<AutomationCatalogueVariant> all, {
    int? statusCode,
  }) {
    return AutomationCatalogueBranch(
      variant: variant.name,
      statusCode: statusCode,
      label: _describeVariant(variant),
      isChosenBeforeStart: all.any(
        (other) => _needsRestartBetween(other, variant),
      ),
    );
  }

  String _describeVariant(AutomationCatalogueVariant variant) {
    final title = variant.title;

    if (title == null || title.isEmpty) {
      return variant.name;
    }

    return title['en'] ?? title.values.first;
  }

  bool _needsRestartBetween(
    AutomationCatalogueVariant first,
    AutomationCatalogueVariant second,
  ) {
    return _sections.any(
      (section) => section.changesRestartKey(first.scenario, second.scenario),
    );
  }
}

typedef _CallKey = (String, String, int);
typedef _Call = ({int stepIndex, AutomationCatalogueRequest request});
