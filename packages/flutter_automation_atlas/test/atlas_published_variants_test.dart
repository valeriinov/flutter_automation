import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_published_variants.dart';

import 'test_utils/test_atlas_root.dart';

const _tapStep = {
  'action': 'tap',
  'label': 'quote an item',
  'finder': {'by': 'valueKey', 'value': 'bottom_bar.button.primary'},
};

void main() {
  group('AtlasPublishedVariants Tests', () {
    _atlasPublishedVariants_should_keepListedVariantsInFlowOrder();
    _atlasPublishedVariants_should_rejectMissingList();
    _atlasPublishedVariants_should_rejectUnknownFlow();
    _atlasPublishedVariants_should_rejectUnknownVariant();
    _atlasPublishedVariants_should_rejectFlowWithoutVariantList();
  });
}

void _atlasPublishedVariants_should_keepListedVariantsInFlowOrder() {
  test(
    'AtlasPublishedVariants should keep listed variants in flow order',
    () async {
      await TestAtlasRoot.run((root) {
        _writeFlows(root);
        root.writePublishedVariants({
          'shop_flow': ['shopFromNewItem', 'shopFromExistingItem'],
        });

        final definitions = AtlasDefinitions.read(root.paths);
        final published = AtlasPublishedVariants.read(
          root.paths,
          definitions,
        ).filter(definitions.variants);

        expect(published.map((variant) => variant.id), [
          'shop_flow shopFromExistingItem',
          'shop_flow shopFromNewItem',
        ]);
      });
    },
  );
}

void _atlasPublishedVariants_should_rejectMissingList() {
  test('AtlasPublishedVariants should reject missing list', () async {
    await TestAtlasRoot.run((root) {
      _writeFlows(root);
      expect(
        () => _read(root),
        _throwsMessage(contains(root.paths.publishedVariantsPath)),
      );
    });
  });
}

void _atlasPublishedVariants_should_rejectUnknownFlow() {
  test('AtlasPublishedVariants should reject unknown flow', () async {
    await TestAtlasRoot.run((root) {
      _writeFlows(root);
      root.writePublishedVariants({
        'shop_flwo': ['shopFromNewItem'],
      });
      expect(() => _read(root), _throwsMessage(contains('shop_flwo')));
    });
  });
}

void _atlasPublishedVariants_should_rejectUnknownVariant() {
  test('AtlasPublishedVariants should reject unknown variant', () async {
    await TestAtlasRoot.run((root) {
      _writeFlows(root);
      root.writePublishedVariants({
        'shop_flow': ['shopFromNowhere'],
      });
      expect(() => _read(root), _throwsMessage(contains('shopFromNowhere')));
    });
  });
}

void _atlasPublishedVariants_should_rejectFlowWithoutVariantList() {
  test(
    'AtlasPublishedVariants should reject flow without variant list',
    () async {
      await TestAtlasRoot.run((root) {
        _writeFlows(root);
        root.writePublishedVariants({'shop_flow': 'shopFromNewItem'});
        expect(
          () => _read(root),
          _throwsMessage(
            allOf(
              contains(root.paths.publishedVariantsPath),
              contains('shop_flow'),
            ),
          ),
        );
      });
    },
  );
}

void _writeFlows(TestAtlasRoot root) {
  root
    ..writeFlow('shop_flow', {
      'variants': {
        'shopFromExistingItem': {
          'items': [_tapStep],
        },
        'shopFromNewItem': {
          'items': [_tapStep],
        },
        'shopFromHome': {
          'items': [_tapStep],
        },
      },
    })
    ..writeFlow('login', {
      'variants': {
        'signedIn': {
          'items': [_tapStep],
        },
      },
    });
}

AtlasPublishedVariants _read(TestAtlasRoot root) {
  return AtlasPublishedVariants.read(
    root.paths,
    AtlasDefinitions.read(root.paths),
  );
}

Matcher _throwsMessage(Matcher message) {
  return throwsA(
    isA<AtlasException>().having((error) => error.message, 'message', message),
  );
}
