import 'package:flutter_automation_mock/flutter_automation_mock.dart';

// Test utility api that answers the endpoints a test declares, so routing and
// transport can be exercised without a real section api behind them.
final class TestMockApi implements MockApi {
  @override
  final List<MockApiEndpoint> endpoints;

  const TestMockApi({required this.endpoints});
}
