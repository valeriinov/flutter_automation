import 'package:flutter_automation_mock/mock_catalogue.dart';

import 'package:flutter_automation_runner/src/definition/flow_action_names.dart';

/// {@category Utils}
///
/// One request the mock answered while a run walked a step, as the recording
/// keeps it.
final class AutomationRecordingRequest {
  static const _methodKey = 'method';
  static const _pathKey = 'path';
  static const _statusCodeKey = 'statusCode';
  static const _responseKey = 'response';

  /// HTTP method of the request.
  final String method;

  /// Path of the request.
  final String path;

  /// Status code of the answer, missing when the run saw none.
  final int? statusCode;

  /// Body of the answer as JSON (an object or a list), missing when it carried
  /// no key.
  final Object? response;

  const AutomationRecordingRequest({
    required this.method,
    required this.path,
    this.statusCode,
    this.response,
  });

  /// Reads the request out of the recording JSON.
  factory AutomationRecordingRequest.fromJson(Map<String, Object?> json) {
    final statusCode = json[_statusCodeKey];

    return AutomationRecordingRequest(
      method: CatalogueJson.tryString(json, _methodKey) ?? '',
      path: CatalogueJson.tryString(json, _pathKey) ?? '',
      statusCode: statusCode is int ? statusCode : null,
      response: json[_responseKey],
    );
  }

  /// The request as the recording JSON.
  Map<String, Object?> toJson() {
    return {
      _methodKey: method,
      _pathKey: path,
      _statusCodeKey: ?statusCode,
      _responseKey: ?response,
    };
  }
}

/// {@category Utils}
///
/// One step of a run as the recording keeps it.
final class AutomationRecordedStep {
  static const _serviceActions = {
    FlowActionNames.driverCommand,
    FlowActionNames.traceStart,
    FlowActionNames.traceStop,
    FlowActionNames.probeSeries,
    FlowActionNames.probeCenter,
  };

  /// Short words that name the step.
  final String label;

  /// Driver action of the step.
  final String action;

  /// Target the step addresses, missing when it names none.
  final String? target;

  /// Block the step came from, missing for an inline step.
  final String? block;

  /// The step as the flow JSON holds it, with each block parameter
  /// substituted, missing when the run did not keep it.
  final Map<String, Object?>? step;

  /// How long the step took in milliseconds, missing when the run did not time
  /// it.
  final int? ms;

  /// Whether the step passed.
  final bool ok;

  /// Why the step failed, missing when it passed.
  final String? error;

  /// File name of the screenshot a capture run took before the step, missing
  /// when it took none.
  final String? screenshot;

  /// Requests the mock answered while the step ran, with the code and the body
  /// of each answer.
  final List<AutomationRecordingRequest> requests;

  const AutomationRecordedStep({
    required this.label,
    required this.action,
    required this.ok,
    this.target,
    this.block,
    this.step,
    this.ms,
    this.error,
    this.screenshot,
    this.requests = const [],
  });

  /// Reads the step out of the recording JSON.
  factory AutomationRecordedStep.fromJson(Map<String, Object?> json) {
    final ms = json['ms'];

    return AutomationRecordedStep(
      label: CatalogueJson.tryString(json, 'label') ?? '',
      action: CatalogueJson.tryString(json, 'action') ?? '',
      ok: json['ok'] != false,
      target: CatalogueJson.tryString(json, 'target'),
      block: CatalogueJson.tryString(json, 'block'),
      step: CatalogueJson.tryObject(json, 'step'),
      ms: ms is int ? ms : null,
      error: CatalogueJson.tryString(json, 'error'),
      screenshot: CatalogueJson.tryString(json, 'screenshot'),
      requests: CatalogueJson.objects(
        json,
        'requests',
      ).map(AutomationRecordingRequest.fromJson).toList(growable: false),
    );
  }

  /// Whether the step serves the run and is no action of a tester.
  bool get isService => _serviceActions.contains(action);

  /// The step as the recording JSON.
  Map<String, Object?> toJson() {
    return {
      'label': label,
      'action': action,
      'target': ?target,
      'block': ?block,
      'step': ?step,
      'ms': ?ms,
      'ok': ok,
      'error': ?error,
      'screenshot': ?screenshot,
      'requests': requests.map((request) => request.toJson()).toList(),
    };
  }
}

/// {@category Utils}
///
/// What a run of one flow variant did: its steps, timings and the requests the
/// mock answered in each step.
///
/// A capture run and a plain run with `--record` write the same schema. The
/// capture run adds the names of its screenshots. The atlas and the catalogue
/// of the panel read it.
final class AutomationRecording {
  /// Name of the flow.
  final String flow;

  /// Name of the variant.
  final String variant;

  /// Whether every step passed.
  final bool ok;

  /// How long the steps took in milliseconds.
  final int totalMs;

  /// Record of the launch that the app keeps, missing when it keeps none.
  final Map<String, Object?>? launch;

  /// File name of the screenshot a capture run took at the end, missing when it
  /// took none.
  final String? endScreenshot;

  /// Steps in the order the run walked them.
  final List<AutomationRecordedStep> steps;

  const AutomationRecording({
    required this.flow,
    required this.variant,
    required this.ok,
    required this.totalMs,
    required this.steps,
    this.launch,
    this.endScreenshot,
  });

  /// Reads the recording out of its JSON.
  factory AutomationRecording.fromJson(Map<String, Object?> json) {
    final totalMs = json['totalMs'];
    final launch = json['launch'];
    final endScreenshot = json['endScreenshot'];

    return AutomationRecording(
      flow: '${json['flow']}',
      variant: '${json['variant']}',
      ok: json['ok'] != false,
      totalMs: totalMs is int ? totalMs : 0,
      launch: launch is Map<String, Object?> ? launch : null,
      endScreenshot: endScreenshot is String ? endScreenshot : null,
      steps: CatalogueJson.objects(
        json,
        'steps',
      ).map(AutomationRecordedStep.fromJson).toList(growable: false),
    );
  }

  /// Builds the recording out of the report of a run.
  ///
  /// A step holds the requests of its own `journal`. The `journalBeforeAction`
  /// of a step holds requests that answered after the step before it, so they
  /// join that step. The `endJournal` joins the last step.
  ///
  /// The [report] parameter is the report that the runner prints.
  factory AutomationRecording.fromReport(Map<String, Object?> report) {
    final reportSteps = CatalogueJson.objects(report, 'steps');
    final requests = [
      for (final _ in reportSteps) <AutomationRecordingRequest>[],
    ];

    for (int index = 0; index < reportSteps.length; index += 1) {
      final step = reportSteps[index];

      requests[index].addAll(_readRequests(step['journal']));

      if (index > 0) {
        requests[index - 1].addAll(_readRequests(step['journalBeforeAction']));
      }
    }

    if (requests.isNotEmpty) {
      requests.last.addAll(_readRequests(report['endJournal']));
    }

    final totalMs = report['totalMs'];
    final launch = report['launch'];
    final endScreenshot = report['endScreenshot'];

    return AutomationRecording(
      flow: '${report['flow']}',
      variant: '${report['variant']}',
      ok: report['ok'] == true,
      totalMs: totalMs is int ? totalMs : 0,
      launch: launch is Map<String, Object?> ? launch : null,
      endScreenshot: endScreenshot is String ? endScreenshot : null,
      steps: [
        for (int index = 0; index < reportSteps.length; index += 1)
          AutomationRecordedStep.fromJson({
            ...reportSteps[index],
            'requests': requests[index].map((r) => r.toJson()).toList(),
          }),
      ],
    );
  }

  /// The recording as JSON.
  Map<String, Object?> toJson() {
    return {
      'flow': flow,
      'variant': variant,
      'ok': ok,
      'totalMs': totalMs,
      'launch': ?launch,
      'endScreenshot': ?endScreenshot,
      'steps': steps.map((step) => step.toJson()).toList(),
    };
  }

  static List<AutomationRecordingRequest> _readRequests(Object? journal) {
    return CatalogueJson.asList(journal)
        .whereType<Map<String, Object?>>()
        .where((record) => record['path'] is String)
        .map(
          (record) => AutomationRecordingRequest.fromJson({
            'method': record['method'],
            'path': record['path'],
            'statusCode': record['status'],
            'response': record['response'],
          }),
        )
        .toList(growable: false);
  }
}
