import 'package:flutter_automation_runner/automation_flow_definition.dart';

import 'package:example/automation/example_target.dart';
import 'package:example/mock/catalog_mock_section.dart';

const signIn = FlowBlock(name: 'signIn', build: _buildSignInSteps);

List<FlowStep> _buildSignInSteps(FlowParams params) => const [
  WaitFor(ByTarget(ExampleTarget.loginScreen)),
  Tap(ByTarget(ExampleTarget.loginButton)),
  WaitFor(ByTarget(ExampleTarget.catalogScreen)),
];

/// Signs in and reads the catalog: with items, and empty.
final catalogFlow = AutomationFlowDefinition(
  name: 'catalog',
  defaultVariant: 'items',
  variants: [
    FlowVariant(
      'items',
      items: [
        const Use(signIn),
        const WaitFor(ByTarget(ExampleTarget.catalogList)),
      ],
      scenario: [catalogMockSection.profile('fullShelf')],
    ),
    FlowVariant(
      'empty',
      items: [
        const Use(signIn),
        const WaitFor(ByTarget(ExampleTarget.catalogEmpty)),
      ],
      scenario: [catalogMockSection.profile('emptyShelf')],
    ),
  ],
);
