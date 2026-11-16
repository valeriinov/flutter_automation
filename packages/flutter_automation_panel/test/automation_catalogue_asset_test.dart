import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils/sample_panel.dart';

void main() {
  group('Automation Catalogue Asset Tests', () {
    _load_should_decodeTheCatalogueAsset();
    _load_should_returnNullForABrokenAsset();
    _load_should_returnNullForAMissingAsset();
  });
}

class _StringBundle extends CachingAssetBundle {
  final Map<String, String> assets;

  _StringBundle(this.assets);

  @override
  Future<ByteData> load(String key) async {
    final text = assets[key];

    if (text == null) {
      throw FlutterError('Unable to load asset: $key');
    }

    return ByteData.sublistView(utf8.encode(text));
  }
}

void _load_should_decodeTheCatalogueAsset() {
  testWidgets('load should decode the catalogue asset', (tester) async {
    final json = jsonEncode(sampleCatalogue.toJson());

    final catalogue = await tester.runAsync(
      () => AutomationCatalogueAsset.load(
        _StringBundle({'catalogue.json': json}),
        'catalogue.json',
      ),
    );

    expect(
      catalogue?.flows.map((flow) => flow.name),
      sampleCatalogue.flows.map((flow) => flow.name),
    );
  });
}

void _load_should_returnNullForABrokenAsset() {
  testWidgets('load should return null for a broken asset', (tester) async {
    final catalogue = await tester.runAsync(
      () => AutomationCatalogueAsset.load(
        _StringBundle({'catalogue.json': '{not json'}),
        'catalogue.json',
      ),
    );

    expect(catalogue, isNull);
  });
}

void _load_should_returnNullForAMissingAsset() {
  testWidgets('load should return null for a missing asset', (tester) async {
    final catalogue = await tester.runAsync(
      () => AutomationCatalogueAsset.load(_StringBundle({}), 'catalogue.json'),
    );

    expect(catalogue, isNull);
  });
}
