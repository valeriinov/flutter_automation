import 'dart:convert';

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
/// The [onRestartRequired] parameter shows the restart screen of the app.
Future<AutomationPanelController> buildExamplePanel({
  required AutomationMock mock,
  required void Function() onRestartRequired,
}) async {
  final json = jsonDecode(await rootBundle.loadString(catalogueAsset));
  final catalogue = AutomationCatalogue.fromJson(json as Map<String, Object?>);

  return AutomationPanelController(
    AutomationPanelDefinition(
      mock: mock,
      catalogue: catalogue,
      onRestartRequired: onRestartRequired,
      pages: [
        AutomationPanelPage(
          label: 'Flows',
          builder: (_) => const AutomationFlowsPage(),
        ),
        AutomationPanelPage(
          label: 'Autorun',
          builder: (_) => const AutomationAutorunPage(),
        ),
        AutomationPanelPage(
          label: 'Sections',
          builder: (_) => AutomationSectionsPage(
            sections: [
              AutomationSectionPanel(
                title: 'Catalog',
                section: catalogMockSection,
                api: MockCatalogApi(mock),
                profileTitles: const {
                  'emptyShelf': 'Empty shelf',
                  'fullShelf': 'Full shelf',
                },
              ),
            ],
          ),
        ),
        AutomationPanelPage(
          label: 'Log',
          builder: (_) => const AutomationJournalPage(),
        ),
      ],
    ),
  );
}
