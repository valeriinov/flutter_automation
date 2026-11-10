import 'package:collection/collection.dart';
import 'package:flutter_automation_mock/src/contract/mock_api.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_endpoint.dart';

/// {@category Utils}
///
/// Resolves a request path to the endpoint that answers it.
///
/// Holds every endpoint of the apis the scenario installed. A path no api
/// claimed resolves to null, which is what sends the request on to the remote
/// environment.
class MockApiEndpointResolver {
  final Map<String, MockApiEndpoint> _exactEndpoints = {};
  final List<MockApiEndpoint> _pathIdEndpoints = [];

  MockApiEndpointResolver(List<MockApi> apis) {
    apis.expand((api) => api.endpoints).forEach(_addEndpoint);
    _sortByLongestPath();
  }

  /// Returns the endpoint that answers [path], or null when no api owns it.
  ///
  /// A path extended with a trailing segment resolves to the longest endpoint
  /// that matches it, so `/records/update/stamp` wins over `/records/update`
  /// even though both claim the prefix.
  MockApiEndpoint? tryResolve(String path) {
    final exactEndpoint = _exactEndpoints[path];

    if (exactEndpoint != null) {
      return exactEndpoint;
    }

    return _pathIdEndpoints.firstWhereOrNull(
      (endpoint) => path.startsWith('${endpoint.path}/'),
    );
  }

  void _addEndpoint(MockApiEndpoint endpoint) {
    if (endpoint.hasPathId) {
      _pathIdEndpoints.add(endpoint);

      return;
    }

    _exactEndpoints[endpoint.path] = endpoint;
  }

  void _sortByLongestPath() {
    _pathIdEndpoints.sort((a, b) => b.path.length.compareTo(a.path.length));
  }
}
