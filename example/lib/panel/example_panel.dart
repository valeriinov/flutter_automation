import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';

import 'package:example/mock/catalog_mock_section.dart';
import 'package:example/mock/mock_catalog_api.dart';

/// Path of the catalogue that `tool/run_flows.dart --qa-catalogue` writes.
const catalogueAsset = 'assets/qa_catalogue.json';

/// Builds the QA panel of the example from the catalogue asset and the mock
/// section of the catalog.
///
/// The [mock] parameter is the mock of the app.
/// The [isRestartRequired] parameter is the flag the restart screen of the app
/// listens to.
Future<AutomationPanelController> buildExamplePanel({
  required AutomationMock mock,
  required ValueNotifier<bool> isRestartRequired,
}) async {
  final catalogue = await AutomationCatalogueAsset.load(
    rootBundle,
    catalogueAsset,
  );

  return AutomationPanelController(
    AutomationPanelDefinition.standard(
      mock: mock,
      catalogue: catalogue ?? const AutomationCatalogue(),
      isRestartRequired: isRestartRequired,
      sections: [
        AutomationSectionPanel.fromSection(
          catalogMockSection,
          api: MockCatalogApi(mock),
        ),
      ],
    ),
  );
}
