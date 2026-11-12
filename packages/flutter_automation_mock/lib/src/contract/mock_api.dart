import 'package:flutter_automation_mock/src/contract/mock_api_endpoint.dart';

/// {@category Utils}
///
/// Section of the backend answered from memory.
///
/// Implemented once per section, so one file declares the endpoints of a
/// section, next to the state they read. An api owns endpoint declaration and
/// serialization only.
abstract interface class MockApi {
  /// Endpoints the api owns; everything else reaches the network.
  List<MockApiEndpoint> get endpoints;
}
