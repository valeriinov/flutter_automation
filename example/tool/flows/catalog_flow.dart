import 'package:flutter_automation/automation_target.dart';
import 'package:flutter_automation_runner/automation_flow_definition.dart';

import 'package:example/automation/example_target.dart';
import 'package:example/mock/catalog_mock_section.dart';

const signIn = FlowBlock(name: 'signIn', build: _buildSignInSteps);

List<FlowStep> _buildSignInSteps(FlowParams params) => const [
  WaitFor(ByTarget(ExampleTarget.loginScreen)),
  Tap(ByTarget(ExampleTarget.loginButton)),
  WaitFor(ByTarget(ExampleTarget.catalogScreen)),
];

const catalogGroup = AutomationFlowGroup(
  name: 'catalog',
  title: AutomationLocalizedText({'en': 'Catalog', 'uk': 'Каталог'}),
  area: AutomationFlowArea(
    name: 'shop',
    title: AutomationLocalizedText({'en': 'Shop', 'uk': 'Магазин'}),
  ),
);

const catalogGroupOrder = [catalogGroup];

/// Signs in and reads the catalog: with items, and empty.
final catalogFlow = AutomationFlowDefinition(
  name: 'catalog',
  group: catalogGroup,
  title: const AutomationLocalizedText({
    'en': 'Sign in and read the catalog',
    'uk': 'Вхід і перегляд каталогу',
  }),
  defaultVariant: 'items',
  isInQaCatalogue: true,
  variants: [
    FlowVariant(
      'items',
      title: const AutomationLocalizedText({
        'en': 'Catalog with items',
        'uk': 'Каталог з товарами',
      }),
      items: [
        const Use(signIn),
        const WaitFor(ByTarget(ExampleTarget.catalogList)),
        WaitFor(ByTarget(ExampleTarget.catalogItem.withKey(5))),
      ],
      scenario: [catalogMockSection.profile('fullShelf')],
    ),
    FlowVariant(
      'empty',
      title: const AutomationLocalizedText({
        'en': 'Empty catalog',
        'uk': 'Порожній каталог',
      }),
      items: [
        const Use(signIn),
        const WaitFor(ByTarget(ExampleTarget.catalogEmpty)),
      ],
      scenario: [catalogMockSection.profile('emptyShelf')],
    ),
  ],
);
