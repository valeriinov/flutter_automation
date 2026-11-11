import 'package:flutter_automation_runner/automation_flow_definition.dart';

import 'package:example/automation/example_target.dart';
import 'package:example/mock/catalog_mock_feature.dart';

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
      use: [
        const Use(signIn),
        const WaitFor(ByTarget(ExampleTarget.catalogList)),
      ],
      scenario: [catalogMockFeature.profile('fullShelf')],
    ),
    FlowVariant(
      'empty',
      use: [
        const Use(signIn),
        const WaitFor(ByTarget(ExampleTarget.catalogEmpty)),
      ],
      scenario: [catalogMockFeature.profile('emptyShelf')],
    ),
  ],
);
