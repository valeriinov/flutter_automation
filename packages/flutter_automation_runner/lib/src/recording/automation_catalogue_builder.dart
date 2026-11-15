import 'package:collection/collection.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';

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
/// The fork of a flow is the first request at which the answers of two
/// variants differ in their code or their body. A request is the n-th call of
/// one method and path inside its variant. Each branch carries the difference
/// of the scenario of its variant.
final class AutomationCatalogueBuilder {
  static const _isInQaCatalogueKey = 'isInQaCatalogue';
  static const _maxLabelParts = 3;
  static const _equality = DeepCollectionEquality();

  final Map<String, Object?> _flows;
  final List<AutomationRecording> _recordings;

  /// Creates a builder.
  ///
  /// The [flows] parameter maps a flow name to its flow JSON.
  /// The [recordings] parameter holds the recordings of the runs.
  const AutomationCatalogueBuilder({
    required Map<String, Object?> flows,
    required List<AutomationRecording> recordings,
  }) : _flows = flows,
       _recordings = recordings;

  /// The catalogue of the flows a tester walks.
  AutomationCatalogue build() {
    final flows = <AutomationCatalogueFlow>[];
    final groups = <String, AutomationCatalogueGroup>{};

    for (final MapEntry(:key, :value) in _flows.entries) {
      final json = CatalogueJson.asObject(value);

      if (json[_isInQaCatalogueKey] == true) {
        flows.add(_buildFlow(key, json));
        _collectGroup(groups, json);
      }
    }

    return AutomationCatalogue(
      groups: groups.values.toList(growable: false),
      flows: flows,
    );
  }

  void _collectGroup(
    Map<String, AutomationCatalogueGroup> groups,
    Map<String, Object?> flow,
  ) {
    final group = AutomationCatalogueGroup.fromJson(
      CatalogueJson.asObject(flow['group']),
    );

    if (group.name.isNotEmpty) {
      groups.putIfAbsent(group.name, () => group);
    }
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
          AutomationCatalogueStep(
            label: step.label,
            isService: step.isService,
            requests: step.requests.map(_describeRequest).toList(),
          ),
      ],
    );
  }

  AutomationCatalogueRequest _describeRequest(
    AutomationRecordingRequest request,
  ) {
    return AutomationCatalogueRequest(
      method: request.method,
      path: request.path,
      statusCode: request.statusCode,
      response: request.response,
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
    final walked = variants.where((variant) => variant.steps.isNotEmpty);

    if (walked.length < 2) {
      return null;
    }

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
          AutomationCatalogueBranch(
            variant: key.name,
            statusCode: value.request.statusCode,
            label: _describeDifference(key, answers.keys),
          ),
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

  String _describeDifference(
    AutomationCatalogueVariant variant,
    Iterable<AutomationCatalogueVariant> all,
  ) {
    final leaves = {
      for (final other in all) other.name: _flatten(other.scenario),
    };
    final own = leaves[variant.name] ?? const {};
    final differing = own.entries
        .where(
          (leaf) => leaves.values.any(
            (other) => !_equality.equals(other[leaf.key], leaf.value),
          ),
        )
        .map((leaf) => '${leaf.key}=${leaf.value}')
        .take(_maxLabelParts)
        .toList();

    return differing.isEmpty ? variant.name : differing.join(', ');
  }

  Map<String, Object?> _flatten(
    Map<String, Object?> json, [
    String prefix = '',
  ]) {
    final leaves = <String, Object?>{};

    for (final MapEntry(:key, :value) in json.entries) {
      final path = prefix.isEmpty ? key : '$prefix.$key';

      if (value is Map<String, Object?> && value.isNotEmpty) {
        leaves.addAll(_flatten(value, path));
      } else {
        leaves[path] = value;
      }
    }

    return leaves;
  }
}

typedef _CallKey = (String, String, int);
typedef _Call = ({int stepIndex, AutomationCatalogueRequest request});
