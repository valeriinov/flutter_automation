import 'package:flutter_automation_mock/src/contract/mock_api_failure.dart';
import 'package:flutter_automation_mock/src/transport/mock_api_endpoint_resolver.dart';
import 'package:flutter_automation_mock/src/transport/mock_latency.dart';

/// {@category Utils}
///
/// What the transport reads while it answers a request.
///
/// A project implements it over its own mock state. The transport reads through
/// it on each request. The project can therefore replace what it answers with,
/// without a rebuild of the HTTP clients that hold the transport.
abstract interface class MockBackend {
  /// Endpoints that the transport answers a path through.
  MockApiEndpointResolver get endpointResolver;

  /// Delay an answer waits out before it reaches the app.
  MockLatency get latency;

  /// Failures answered in place of the payload, keyed by path.
  Map<String, MockApiFailure> get failures;

  /// Builds the body of the answer that carries [failure].
  Map<String, Object?> buildFailureBody(MockApiFailure failure);
}
