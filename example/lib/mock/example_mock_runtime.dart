import 'package:flutter_automation_mock/flutter_automation_mock.dart';

import 'package:example/mock/mock_catalog_api.dart';

/// What the mock transport reads on each request, taken from the scenario.
final class ExampleMockRuntime implements MockTransportRuntime {
  final AutomationMock _mock;

  @override
  final MockApiEndpointResolver endpointResolver;

  ExampleMockRuntime(AutomationMock mock)
    : _mock = mock,
      endpointResolver = MockApiEndpointResolver([MockCatalogApi(mock)]);

  @override
  MockLatency get latency => _mock.latency;

  @override
  Map<String, MockApiFailure> get failures => _mock.failures;

  @override
  Map<String, Object?> buildFailureBody(MockApiFailure failure) {
    return {'code': failure.errorCode, 'message': failure.message};
  }
}
