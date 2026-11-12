import 'package:flutter_automation_mock/src/contract/mock_api.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_failure.dart';
import 'package:flutter_automation_mock/src/scenario/mock_scenario.dart';
import 'package:flutter_automation_mock/src/scenario/mock_scenario_reader.dart';
import 'package:flutter_automation_mock/src/transport/mock_api_endpoint_resolver.dart';
import 'package:flutter_automation_mock/src/transport/mock_latency.dart';
import 'package:flutter_automation_mock/src/transport/mock_backend.dart';

/// {@category Utils}
///
/// What the transport reads while it answers a request, taken from the
/// scenario of the run.
///
/// The backend reads the failures from the scenario on each request. It holds
/// the endpoints and one [MockLatency] between two [rebuild] calls. One
/// latency object spends its seeded jitter across the requests, so two requests
/// in a row wait for different delays.
///
/// The project calls [rebuild] when the scenario changes, from the hook it
/// passes to the mock for that moment.
final class MockScenarioBackend implements MockBackend {
  final MockScenario Function() _readScenario;
  final List<MockApi> Function() _buildApis;
  final Map<String, Object?> Function(MockApiFailure failure) _buildFailureBody;

  late MockApiEndpointResolver _endpointResolver;
  late MockLatency _latency;

  /// Creates a backend and builds its endpoints and latency.
  ///
  /// The [readScenario] parameter gives the scenario of the run.
  /// The [buildApis] parameter builds the apis that answer the requests.
  /// The [buildFailureBody] parameter builds the body of an answer that carries
  /// a failure.
  MockScenarioBackend({
    required MockScenario Function() readScenario,
    required List<MockApi> Function() buildApis,
    required Map<String, Object?> Function(MockApiFailure failure)
    buildFailureBody,
  }) : _readScenario = readScenario,
       _buildApis = buildApis,
       _buildFailureBody = buildFailureBody {
    rebuild();
  }

  @override
  MockApiEndpointResolver get endpointResolver => _endpointResolver;

  @override
  MockLatency get latency => _latency;

  @override
  Map<String, MockApiFailure> get failures {
    return MockScenarioReader.readFailures(_readScenario());
  }

  @override
  Map<String, Object?> buildFailureBody(MockApiFailure failure) {
    return _buildFailureBody(failure);
  }

  /// Builds the endpoints and the latency again from the current scenario.
  void rebuild() {
    _endpointResolver = MockApiEndpointResolver(_buildApis());
    _latency = MockScenarioReader.readLatency(_readScenario());
  }
}
