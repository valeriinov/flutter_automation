import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';

import 'test_utils/fake_atlas_project.dart';
import 'test_utils/test_atlas_root.dart';

const _flowTitle = {'en': 'Quote an item', 'uk': 'Запропонувати товар'};
const _variantTitle = {'en': 'From a new item', 'uk': 'З нового товару'};
const _variantProves = {'en': 'A new item', 'uk': 'Новий товар'};
const _openBlock = {
  'steps': [
    {
      'action': 'tap',
      'label': 'quote an item',
      'finder': {'by': 'valueKey', 'value': 'bottom_bar.button.primary'},
    },
  ],
};

void main() {
  group('AtlasDefinitions Tests', () {
    _atlasDefinitions_should_skipProbeSeriesFlows();
    _atlasDefinitions_should_readProbeSeriesFlowsWhenAsked();
    _atlasDefinitions_should_keepVariantOrderTextsAndDefault();
    _atlasDefinitions_should_keepDefHashAcrossKeyOrder();
    _atlasDefinitions_should_changeDefHashWhenStepChanges();
    _atlasDefinitions_should_changeDefHashWhenScenarioChanges();
    _atlasDefinitions_should_rejectFlowTextMissingALocaleNamingFlow();
    _atlasDefinitions_should_rejectStepTitleMissingALocaleNamingStep();
    _atlasDefinitions_should_readDeclaredGroupName();
    _atlasDefinitions_should_rejectGroupWithoutStringName();
  });
}

void _atlasDefinitions_should_skipProbeSeriesFlows() {
  test('AtlasDefinitions should skip probe series flows', () async {
    await TestAtlasRoot.run((root) {
      _writeQuoteFlow(root);
      root.writeFlow('inbox_keyboard_probe_series', {
        'variants': {
          'rise': {'items': <Object?>[]},
        },
      });

      final definitions = AtlasDefinitions.read(root.paths);

      expect(definitions.flows.map((flow) => flow.name), ['shop_flow']);
    });
  });
}

void _atlasDefinitions_should_readProbeSeriesFlowsWhenAsked() {
  test('AtlasDefinitions should read probe series flows when asked', () async {
    await TestAtlasRoot.run((root) {
      _writeQuoteFlow(root);
      root.writeFlow('inbox_keyboard_probe_series', {
        'variants': {
          'rise': {'items': <Object?>[]},
        },
      });

      final definitions = AtlasDefinitions.read(
        root.paths,
        includeProbeSeries: true,
      );

      expect(definitions.flows.map((flow) => flow.name), [
        'inbox_keyboard_probe_series',
        'shop_flow',
      ]);
    });
  });
}

void _atlasDefinitions_should_keepVariantOrderTextsAndDefault() {
  test(
    'AtlasDefinitions should keep variant order texts and default',
    () async {
      await TestAtlasRoot.run((root) {
        _writeQuoteFlow(root);

        final flow = AtlasDefinitions.read(root.paths).findFlow('shop_flow');
        final newItem = flow.findVariant('shopFromNewItem');

        expect(flow.title?.toJson(), _flowTitle);
        expect(flow.variants.map((variant) => variant.name), [
          'shopFromNewItem',
          'shopFromExistingItem',
        ]);
        expect(flow.variants.map((variant) => variant.isDefault), [
          false,
          true,
        ]);
        expect(newItem.automationFlow.variantTitle?.toJson(), _variantTitle);
        expect(newItem.automationFlow.proves?.toJson(), _variantProves);
        expect(newItem.automationFlow.scenarioJson, {
          'login': {'isSignedInOnLaunch': true, 'hasProfile': false},
        });
      });
    },
  );
}

void _atlasDefinitions_should_keepDefHashAcrossKeyOrder() {
  test('AtlasDefinitions should keep def hash across key order', () async {
    await TestAtlasRoot.run((root) {
      _writeQuoteFlow(root);

      final before = _readDefHash(root);

      _writeQuoteFlow(
        root,
        scenario: {
          'login': {'hasProfile': false, 'isSignedInOnLaunch': true},
        },
      );
      expect(_readDefHash(root), before);
      expect(before, hasLength(12));
    });
  });
}

void _atlasDefinitions_should_changeDefHashWhenStepChanges() {
  test('AtlasDefinitions should change def hash when step changes', () async {
    await TestAtlasRoot.run((root) {
      _writeQuoteFlow(root);

      final before = _readDefHash(root);

      _writeQuoteFlow(root, label: 'quote another item');
      expect(_readDefHash(root), isNot(before));
    });
  });
}

void _atlasDefinitions_should_changeDefHashWhenScenarioChanges() {
  test(
    'AtlasDefinitions should change def hash when scenario changes',
    () async {
      await TestAtlasRoot.run((root) {
        _writeQuoteFlow(root);

        final before = _readDefHash(root);

        _writeQuoteFlow(
          root,
          scenario: {
            'login': {'isSignedInOnLaunch': false, 'hasProfile': false},
          },
        );
        expect(_readDefHash(root), isNot(before));
      });
    },
  );
}

void _atlasDefinitions_should_rejectFlowTextMissingALocaleNamingFlow() {
  test(
    'AtlasDefinitions should reject flow text missing A locale naming flow',
    () async {
      await TestAtlasRoot.run((root) {
        root.writeFlow('shop_flow', {
          'title': {'en': 'Quote an item'},
          'variants': {
            'shopFromNewItem': {'items': <Object?>[]},
          },
        });
        expect(
          () => AtlasDefinitions.read(root.paths),
          throwsA(
            isA<AtlasException>().having(
              (error) => error.message,
              'message',
              allOf(
                contains('shop_flow'),
                contains('shopFromNewItem'),
                contains('title'),
                contains('uk'),
              ),
            ),
          ),
        );
      });
    },
  );
}

void _atlasDefinitions_should_rejectStepTitleMissingALocaleNamingStep() {
  test(
    'AtlasDefinitions should reject step title missing a locale naming step',
    () async {
      await TestAtlasRoot.run((root) {
        root.writeFlow('shop_flow', {
          'variants': {
            'shopFromNewItem': {
              'items': [
                {
                  'action': 'waitFor',
                  'label': 'wait for items',
                  'title': {'uk': 'Чекати'},
                  'finder': {'by': 'valueKey', 'value': 'shop_flow.screen'},
                },
              ],
            },
          },
        });
        expect(
          () => AtlasDefinitions.read(root.paths),
          throwsA(
            isA<AtlasException>().having(
              (error) => error.message,
              'message',
              allOf(contains('wait for items'), contains('en')),
            ),
          ),
        );
      });
    },
  );
}

void _atlasDefinitions_should_readDeclaredGroupName() {
  test('AtlasDefinitions should read declared group name', () async {
    await TestAtlasRoot.run((root) {
      _writeQuoteFlow(root);
      root.writeFlowGroup('shop_flow', fakeAtlasGroups.last.toJson());

      final definitions = AtlasDefinitions.read(root.paths);

      expect(
        definitions.findFlow('shop_flow').groupName,
        fakeAtlasGroups.last.name,
      );
    });
  });
}

void _atlasDefinitions_should_rejectGroupWithoutStringName() {
  test('AtlasDefinitions should reject group without string name', () async {
    await TestAtlasRoot.run((root) {
      _writeQuoteFlow(root);
      root.writeFlowGroup('shop_flow', {'name': 42});
      expect(
        () => AtlasDefinitions.read(root.paths),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            allOf(contains('shop_flow'), contains('group')),
          ),
        ),
      );
    });
  });
}

void _writeQuoteFlow(
  TestAtlasRoot root, {
  String label = 'wait for items',
  Map<String, Object?> scenario = const {
    'login': {'isSignedInOnLaunch': true, 'hasProfile': false},
  },
}) {
  root
    ..writeBlock('quote_open', _openBlock)
    ..writeFlow('shop_flow', {
      'title': _flowTitle,
      'defaultVariant': 'shopFromExistingItem',
      'scenario': {
        'login': {'isSignedInOnLaunch': true},
      },
      'variants': {
        'shopFromNewItem': {
          'title': _variantTitle,
          'proves': _variantProves,
          'scenario': scenario,
          'items': [
            'quote_open',
            {
              'action': 'waitFor',
              'label': label,
              'finder': {'by': 'valueKey', 'value': 'shop_flow.screen'},
            },
          ],
        },
        'shopFromExistingItem': {
          'scenario': {
            'login': {'isSignedInOnLaunch': true},
          },
          'items': ['quote_open'],
        },
      },
    });
}

String _readDefHash(TestAtlasRoot root) {
  return AtlasDefinitions.read(
    root.paths,
  ).findFlow('shop_flow').findVariant('shopFromNewItem').defHash;
}
