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
final class AutomationCatalogueStep {
  static const _labelKey = 'label';
  static const _isServiceKey = 'isService';
  static const _requestsKey = 'requests';

  /// Short words that name the step.
  final String label;

  /// Whether the step serves the run (a trace, a probe, a driver command) and
  /// is no action of the tester.
  final bool isService;

  /// Requests the app sent while the step ran.
  final List<AutomationCatalogueRequest> requests;

  const AutomationCatalogueStep({
    required this.label,
    this.isService = false,
    this.requests = const [],
  });

  /// Reads the step out of [json].
  factory AutomationCatalogueStep.fromJson(Map<String, Object?> json) {
    return AutomationCatalogueStep(
      label: CatalogueJson.tryString(json, _labelKey) ?? '',
      isService: json[_isServiceKey] == true,
      requests: CatalogueJson.objects(
        json,
        _requestsKey,
      ).map(AutomationCatalogueRequest.fromJson).toList(growable: false),
    );
  }

  /// The step as JSON.
  Map<String, Object?> toJson() {
    return {
      _labelKey: label,
      if (isService) _isServiceKey: true,
      _requestsKey: requests.map((request) => request.toJson()).toList(),
    };
  }
}
