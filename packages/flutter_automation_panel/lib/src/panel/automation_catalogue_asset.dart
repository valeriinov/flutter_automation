import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';

/// {@category Utils}
///
/// Loads the catalogue of flows from an asset of the app. The `--qa-catalogue`
/// option of the runner writes that asset.
abstract final class AutomationCatalogueAsset {
  /// Reads the JSON at [path] in [bundle]. A separate isolate decodes it.
  ///
  /// Returns `null` when the asset is missing or does not hold a catalogue.
  /// The project then passes `catalogue ?? const AutomationCatalogue()` and
  /// keeps the panel.
  static Future<AutomationCatalogue?> load(
    AssetBundle bundle,
    String path,
  ) async {
    try {
      final text = await bundle.loadString(path);
      final json = await compute(jsonDecode, text);

      return AutomationCatalogue.fromJson(json as Map<String, Object?>);
    } on Object {
      return null;
    }
  }
}
