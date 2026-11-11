import 'package:flutter_automation_mock/flutter_automation_mock.dart';

import 'package:example/mock/catalog_mock_feature.dart';

/// Sections of the mock backend.
enum ExampleMockSection { catalog }

/// Answers the catalog endpoint from the settings of the scenario.
final class MockCatalogApi implements MockApi {
  final AutomationMock _mock;

  const MockCatalogApi(this._mock);

  @override
  Enum get feature => ExampleMockSection.catalog;

  @override
  List<MockApiEndpoint> get endpoints => [
    MockApiEndpoint(path: '/catalog/items', respond: _respondItems),
  ];

  MockApiResponse _respondItems(MockApiRequest request) {
    final settings = _mock.settingsOf(catalogMockFeature);

    return MockApiResponse(
      body: {
        'items': [
          for (int id = 1; id <= settings.itemCount; id++)
            {'id': id, 'title': 'Item $id'},
        ],
      },
    );
  }
}
