import 'package:flutter_automation_atlas/mock_replay.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/mock/catalog_mock_section.dart';
import 'package:example/mock/mock_catalog_api.dart';

import '../tool/example_atlas_project.dart';

/// The `flutter test` file of `AtlasProject.mockReplayEntry`: it asks the mock
/// of the app again for every answer a snapshot recorded.
void main() {
  test('Mock replay should write the outcome of each snapshot', () {
    return runAtlasMockReplay(
      sections: [catalogMockSection],
      apis: (mock) => [MockCatalogApi(mock)],
      schema: const ExampleAtlasProject().journalSchema,
    );
  }, skip: !isAtlasMockReplayRun);
}
