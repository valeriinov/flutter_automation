import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_endpoint.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_request.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_response.dart';
import 'package:flutter_automation_mock/src/transport/mock_api_endpoint_resolver.dart';
import '../test_utils/test_mock_api.dart';

const _exactPath = '/items/list/by-owner';
const _pathIdPath = '/items/details';
const _otherExactPath = '/records/list/by-viewer';
const _unknownPath = '/reports/create';
const _prefixPath = '/records/update';
const _extendedPath = '/records/update/stamp';
const _itemId = 42;
const _recordId = 7;

final _sut = MockApiEndpointResolver([
  TestMockApi(
    feature: TestSection.alpha,
    endpoints: [
      MockApiEndpoint(path: _exactPath, respond: _respondEmpty),
      MockApiEndpoint(
        path: _pathIdPath,
        respond: _respondEmpty,
        hasPathId: true,
      ),
    ],
  ),
  TestMockApi(
    feature: TestSection.beta,
    endpoints: [MockApiEndpoint(path: _otherExactPath, respond: _respondEmpty)],
  ),
]);

final _prefixFirstRouter = _createOverlappingRouter([
  _prefixPath,
  _extendedPath,
]);

final _extendedFirstRouter = _createOverlappingRouter([
  _extendedPath,
  _prefixPath,
]);

void main() {
  group('MockApiEndpointResolver Tests', () {
    _mockApiRouter_should_resolveAnExactPath();
    _mockApiRouter_should_resolveAPathCarryingAnId();
    _mockApiRouter_should_collectRoutesOfEveryApi();
    _mockApiRouter_should_returnNullForAnUnownedPath();
    _mockApiRouter_should_returnNullForAnIdPathWithoutAnId();
    _mockApiRouter_should_resolveTheLongestPathWhenThePrefixComesFirst();
    _mockApiRouter_should_resolveTheLongestPathWhenThePrefixComesLast();
    _mockApiRouter_should_resolveThePrefixPathItself();
  });
}

void _mockApiRouter_should_resolveAnExactPath() {
  test('MockApiEndpointResolver should resolve an exact path', () {
    final endpoint = _sut.tryResolve(_exactPath);

    expect(endpoint?.path, _exactPath);
  });
}

void _mockApiRouter_should_resolveAPathCarryingAnId() {
  test('MockApiEndpointResolver should resolve a path carrying an id', () {
    final endpoint = _sut.tryResolve('$_pathIdPath/$_itemId');

    expect(endpoint?.path, _pathIdPath);
  });
}

void _mockApiRouter_should_collectRoutesOfEveryApi() {
  test('MockApiEndpointResolver should collect endpoints of every api', () {
    final endpoint = _sut.tryResolve(_otherExactPath);

    expect(endpoint?.path, _otherExactPath);
  });
}

void _mockApiRouter_should_returnNullForAnUnownedPath() {
  test('MockApiEndpointResolver should return null for an unowned path', () {
    final endpoint = _sut.tryResolve(_unknownPath);

    expect(endpoint, isNull);
  });
}

void _mockApiRouter_should_returnNullForAnIdPathWithoutAnId() {
  test(
    'MockApiEndpointResolver should return null for an id path without an id',
    () {
      final endpoint = _sut.tryResolve(_pathIdPath);

      expect(endpoint, isNull);
    },
  );
}

void _mockApiRouter_should_resolveTheLongestPathWhenThePrefixComesFirst() {
  test('MockApiEndpointResolver should resolve the longest path '
      'when the prefix comes first', () {
    final endpoint = _prefixFirstRouter.tryResolve('$_extendedPath/$_recordId');

    expect(endpoint?.path, _extendedPath);
  });
}

void _mockApiRouter_should_resolveTheLongestPathWhenThePrefixComesLast() {
  test('MockApiEndpointResolver should resolve the longest path '
      'when the prefix comes last', () {
    final endpoint = _extendedFirstRouter.tryResolve(
      '$_extendedPath/$_recordId',
    );

    expect(endpoint?.path, _extendedPath);
  });
}

void _mockApiRouter_should_resolveThePrefixPathItself() {
  test('MockApiEndpointResolver should resolve the prefix path itself', () {
    final endpoint = _prefixFirstRouter.tryResolve('$_prefixPath/$_recordId');

    expect(endpoint?.path, _prefixPath);
  });
}

MockApiEndpointResolver _createOverlappingRouter(List<String> paths) {
  return MockApiEndpointResolver([
    TestMockApi(
      feature: TestSection.beta,
      endpoints: paths
          .map(
            (path) => MockApiEndpoint(
              path: path,
              respond: _respondEmpty,
              hasPathId: true,
            ),
          )
          .toList(),
    ),
  ]);
}

MockApiResponse _respondEmpty(MockApiRequest _) =>
    const MockApiResponse(body: {});
