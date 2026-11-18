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
  ///
  /// Throws an [AutomationCatalogueVersionException] when the catalogue has no
  /// `version` or one this build does not read. The project regenerates the
  /// catalogue then.
  static Future<AutomationCatalogue?> load(
    AssetBundle bundle,
    String path,
  ) async {
    try {
      final text = await bundle.loadString(path);
      final json = await compute(jsonDecode, text);

      if (json is! Map<String, Object?>) {
        return null;
      }

      return AutomationCatalogue.fromJson(json);
    } on AutomationCatalogueVersionException {
      rethrow;
    } on Object {
      return null;
    }
  }
}
