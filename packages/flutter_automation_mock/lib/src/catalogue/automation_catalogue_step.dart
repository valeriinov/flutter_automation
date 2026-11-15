import 'package:flutter_automation_mock/src/catalogue/catalogue_json.dart';

/// {@category Utils}
///
/// One request the mock answered while a run walked a step.
final class AutomationCatalogueRequest {
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

  const AutomationCatalogueRequest({
    required this.method,
    required this.path,
    this.statusCode,
    this.response,
  });

  /// Reads the request out of [json].
  factory AutomationCatalogueRequest.fromJson(Map<String, Object?> json) {
    final statusCode = json[_statusCodeKey];

    return AutomationCatalogueRequest(
      method: CatalogueJson.tryString(json, _methodKey) ?? '',
      path: CatalogueJson.tryString(json, _pathKey) ?? '',
      statusCode: statusCode is int ? statusCode : null,
      response: json[_responseKey],
    );
  }

  /// The request as JSON.
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
/// One step of a variant with the requests the app sent in it.
///
/// A step that carries an [action] is one a player can do: the [finder], the
/// [text] and the drag distance say on what and how.
final class AutomationCatalogueStep {
  /// Keys of the step JSON, which the runner writes and the player reads.
  static const labelKey = 'label';
  static const isServiceKey = 'isService';
  static const actionKey = 'action';
  static const finderKey = 'finder';
  static const textKey = 'text';
  static const titleKey = 'title';
  static const timeoutMsKey = 'timeoutMs';
  static const dxKey = 'dx';
  static const dyKey = 'dy';
  static const durationMsKey = 'durationMs';
  static const frequencyKey = 'frequency';
  static const requestsKey = 'requests';

  /// Short words that name the step.
  final String label;

  /// Whether the step serves the run (a trace, a probe, a driver command) and
  /// is no action of the tester.
  final bool isService;

  /// Driver action of the step, missing when the catalogue holds none.
  final String? action;

  /// Finder JSON of the element the step acts on, missing for a step that
  /// addresses none.
  final Map<String, Object?>? finder;

  /// Text an `enterText` step writes, missing for the rest.
  final String? text;

  /// What the person does in the step, by locale, missing when the flow names
  /// none.
  final Map<String, String>? title;

  /// How long a player waits for the step in milliseconds, missing for the
  /// default.
  final int? timeoutMs;

  /// Horizontal distance of a `scroll` in logical pixels, missing for none.
  final double? dx;

  /// Vertical distance of a `scroll` in logical pixels, missing for none.
  final double? dy;

  /// How long a `scroll` spreads its pointer moves in milliseconds, missing
  /// for none.
  final int? durationMs;

  /// Pointer moves per second of a `scroll`, missing for none.
  final int? frequency;

  /// Requests the app sent while the step ran.
  final List<AutomationCatalogueRequest> requests;

  const AutomationCatalogueStep({
    required this.label,
    this.isService = false,
    this.action,
    this.finder,
    this.text,
    this.title,
    this.timeoutMs,
    this.dx,
    this.dy,
    this.durationMs,
    this.frequency,
    this.requests = const [],
  });

  /// Reads the step out of [json].
  factory AutomationCatalogueStep.fromJson(Map<String, Object?> json) {
    final timeoutMs = json[timeoutMsKey];
    final dx = json[dxKey];
    final dy = json[dyKey];
    final durationMs = json[durationMsKey];
    final frequency = json[frequencyKey];

    return AutomationCatalogueStep(
      label: CatalogueJson.tryString(json, labelKey) ?? '',
      isService: json[isServiceKey] == true,
      action: CatalogueJson.tryString(json, actionKey),
      finder: CatalogueJson.tryObject(json, finderKey),
      text: CatalogueJson.tryString(json, textKey),
      title: CatalogueJson.tryText(json, titleKey),
      timeoutMs: timeoutMs is int ? timeoutMs : null,
      dx: dx is num ? dx.toDouble() : null,
      dy: dy is num ? dy.toDouble() : null,
      durationMs: durationMs is int ? durationMs : null,
      frequency: frequency is int ? frequency : null,
      requests: CatalogueJson.objects(
        json,
        requestsKey,
      ).map(AutomationCatalogueRequest.fromJson).toList(growable: false),
    );
  }

  /// The step as JSON.
  Map<String, Object?> toJson() {
    return {
      labelKey: label,
      if (isService) isServiceKey: true,
      actionKey: ?action,
      finderKey: ?finder,
      textKey: ?text,
      titleKey: ?title,
      timeoutMsKey: ?timeoutMs,
      dxKey: ?dx,
      dyKey: ?dy,
      durationMsKey: ?durationMs,
      frequencyKey: ?frequency,
      requestsKey: requests.map((request) => request.toJson()).toList(),
    };
  }
}
