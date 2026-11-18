import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils/sample_panel.dart';

void main() {
  group('AutomationFlowsPage Widget Tests', () {
    _automationFlowsPage_should_drawAreasAndTheirGroupsInCatalogueOrder();
    _automationFlowsPage_should_drawGroupsWithoutAreasAsAFlatList();
    _automationFlowsPage_should_keepCatalogueOrderForMixedGroups();
  });
}

AutomationCatalogueFlow _flowIn(String group) {
  return AutomationCatalogueFlow(
    name: '${group}Flow',
    group: group,
    title: {'en': '$group flow'},
    variants: const [AutomationCatalogueVariant(name: 'main')],
  );
}

AutomationCatalogueGroup _group(String name, [String? area]) {
  return AutomationCatalogueGroup(name: name, title: {'en': name}, area: area);
}

Future<void> _pumpFlowsPage(
  WidgetTester tester,
  AutomationCatalogue catalogue,
) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(780, 1688);

  addTearDown(tester.view.reset);

  final sample = await createSamplePanel(tester, catalogue: catalogue);

  await tester.pumpWidget(
    hostApp(child: panelHost(sample, const AutomationFlowsPage())),
  );
}

List<String> _textsByPosition(WidgetTester tester, List<String> texts) {
  final sorted = [...texts]
    ..sort(
      (first, second) => tester
          .getTopLeft(find.text(first))
          .dy
          .compareTo(tester.getTopLeft(find.text(second)).dy),
    );

  return sorted;
}

void _automationFlowsPage_should_drawAreasAndTheirGroupsInCatalogueOrder() {
  testWidgets(
    'AutomationFlowsPage should draw areas and their groups in catalogue order',
    (tester) async {
      await _pumpFlowsPage(
        tester,
        AutomationCatalogue(
          areas: const [
            AutomationCatalogueArea(
              name: 'shopping',
              title: {'en': 'Shopping'},
            ),
            AutomationCatalogueArea(name: 'browse', title: {'en': 'Browse'}),
          ],
          groups: [
            _group('basket', 'shopping'),
            _group('items', 'browse'),
            _group('catalog', 'browse'),
          ],
          flows: [_flowIn('catalog'), _flowIn('items'), _flowIn('basket')],
        ),
      );

      const expected = [
        'Shopping',
        'BASKET',
        'basket flow',
        'Browse',
        'ITEMS',
        'items flow',
        'CATALOG',
        'catalog flow',
      ];

      expect(
        _textsByPosition(tester, [...expected].reversed.toList()),
        expected,
      );
    },
  );
}

void _automationFlowsPage_should_drawGroupsWithoutAreasAsAFlatList() {
  testWidgets(
    'AutomationFlowsPage should draw groups without areas as a flat list',
    (tester) async {
      await _pumpFlowsPage(
        tester,
        AutomationCatalogue(
          groups: [_group('items'), _group('catalog')],
          flows: [_flowIn('catalog'), _flowIn('items')],
        ),
      );

      const expected = ['ITEMS', 'items flow', 'CATALOG', 'catalog flow'];

      expect(
        _textsByPosition(tester, [...expected].reversed.toList()),
        expected,
      );
      expect(find.text('Shopping'), findsNothing);
    },
  );
}

void _automationFlowsPage_should_keepCatalogueOrderForMixedGroups() {
  testWidgets(
    'AutomationFlowsPage should keep catalogue order for mixed groups',
    (tester) async {
      await _pumpFlowsPage(
        tester,
        AutomationCatalogue(
          areas: const [
            AutomationCatalogueArea(
              name: 'shopping',
              title: {'en': 'Shopping'},
            ),
          ],
          groups: [_group('help'), _group('basket', 'shopping')],
          flows: [_flowIn('basket'), _flowIn('help')],
        ),
      );

      const expected = [
        'HELP',
        'help flow',
        'Shopping',
        'BASKET',
        'basket flow',
      ];

      expect(
        _textsByPosition(tester, [...expected].reversed.toList()),
        expected,
      );
    },
  );
}
