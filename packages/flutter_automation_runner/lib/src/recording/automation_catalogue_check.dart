import 'package:collection/collection.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';

import 'package:flutter_automation_runner/src/automation_block_library.dart';
import 'package:flutter_automation_runner/src/automation_finder_kind.dart';
import 'package:flutter_automation_runner/src/automation_flow.dart';
import 'package:flutter_automation_runner/src/definition/flow_action_names.dart';
import 'package:flutter_automation_runner/src/recording/automation_catalogue_builder.dart';
import 'package:flutter_automation_runner/src/recording/automation_recording.dart';

/// {@category Utils}
///
/// Finds the recordings that disagree with the flows of the catalogue.
///
/// A variant of a flow in the catalogue is a problem in three cases. It has no
/// recording. Its recording failed. The step labels of its recording differ
/// from the step labels of the variant. The check leaves a `probeSeries` step
/// out on both sides, because a recording keeps one entry per read for it. A
/// recording of a flow or a variant that no flow holds is a problem too. A
/// recording of a flow outside the catalogue is not.
final class AutomationCatalogueCheck {
  final Map<String, Object?> _flows;
  final AutomationBlockLibrary _blocks;
  final AutomationFinderRegistry _finders;
  final String _locale;
  final List<AutomationRecording> _recordings;

  /// Creates a check.
  ///
  /// The [flows] parameter maps a flow name to its flow JSON. The [blocks]
  /// parameter is the block library of the flows. The [finders] parameter is
  /// the registry that parses their finders. The [locale] parameter is the
  /// locale of a per-locale finder value. The [recordings] parameter holds the
  /// recordings of the runs.
  AutomationCatalogueCheck({
    required Map<String, Object?> flows,
    required Map<String, Object?> blocks,
    required AutomationFinderRegistry finders,
    required String locale,
    required List<AutomationRecording> recordings,
  }) : _flows = flows,
       _blocks = AutomationBlockLibrary.fromJson(blocks),
       _finders = finders,
       _locale = locale,
       _recordings = recordings;

  /// The problems of the recordings, one line each.
  ///
  /// An empty list means three things. Each variant of a flow in the catalogue
  /// has a recording. Each recording agrees with its flow. No recording lacks
  /// its flow or its variant.
  List<String> findProblems() {
    return [..._findVariantProblems(), ..._findStrayRecordings()];
  }

  List<String> _findVariantProblems() {
    final problems = <String>[];

    for (final MapEntry(:key, :value) in _flows.entries) {
      final json = CatalogueJson.asObject(value);

      if (json[AutomationCatalogueBuilder.isInQaCatalogueKey] != true) {
        continue;
      }

      for (final variant in CatalogueJson.asObject(json['variants']).keys) {
        final problem = _tryFindProblem(key, variant, json);

        if (problem != null) {
          problems.add(problem);
        }
      }
    }

    return problems;
  }

  String? _tryFindProblem(
    String flow,
    String variant,
    Map<String, Object?> json,
  ) {
    final recording = _recordings.firstWhereOrNull(
      (recording) => recording.flow == flow && recording.variant == variant,
    );

    if (recording == null) {
      return '$flow/$variant: no recording';
    }

    if (!recording.ok) {
      return '$flow/$variant: the recording is of a failed run';
    }

    final recordedLabels = [
      for (final step in recording.steps)
        if (_isWalked(step.action)) step.label,
    ];

    if (const ListEquality<String>().equals(
      recordedLabels,
      _readStepLabels(flow, variant, json),
    )) {
      return null;
    }

    return '$flow/$variant: the step labels differ from the flow';
  }

  List<String> _readStepLabels(
    String flow,
    String variant,
    Map<String, Object?> json,
  ) {
    final steps = AutomationFlow.fromJson(
      name: flow,
      variant: variant,
      json: json,
      blocks: _blocks,
      finders: _finders,
      locale: _locale,
    ).steps;

    return [
      for (final step in steps)
        if (_isWalked(step.action)) step.label,
    ];
  }

  List<String> _findStrayRecordings() {
    return [
      for (final recording in _recordings)
        if (!_hasVariant(recording))
          '${recording.flow}/${recording.variant}: no flow holds this recording',
    ];
  }

  static bool _isWalked(String action) => action != FlowActionNames.probeSeries;

  bool _hasVariant(AutomationRecording recording) {
    final variants = CatalogueJson.asObject(
      CatalogueJson.asObject(_flows[recording.flow])['variants'],
    );

    return variants.containsKey(recording.variant);
  }
}
