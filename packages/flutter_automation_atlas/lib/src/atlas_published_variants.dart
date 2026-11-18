import 'dart:io';

import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_paths.dart';

/// {@category Utils}
///
/// The variants the page shows, as
/// [AtlasPaths.publishedVariants] names them: a flow
/// name mapped to its variant names.
final class AtlasPublishedVariants {
  /// The [AtlasVariantDefinition.id] of every listed variant.
  final Set<String> ids;

  const AtlasPublishedVariants._(this.ids);

  /// Reads the list of [paths], resolving every name against [definitions].
  ///
  /// Throws a [AtlasException] when the list is missing or malformed, or
  /// names a flow or a variant no flow file holds.
  factory AtlasPublishedVariants.read(
    AtlasLocations paths,
    AtlasDefinitions definitions,
  ) {
    final file = File(paths.publishedVariantsPath);

    if (!file.existsSync()) {
      throw AtlasException('No published variants list at ${file.path}.');
    }

    final json = AtlasJson.decodeObject(
      file.readAsStringSync(),
      'The published variants list ${file.path}',
    );

    return AtlasPublishedVariants._({
      for (final MapEntry(key: flowName, value: variantNames) in json.entries)
        ..._resolveVariantIds(
          definitions.findFlow(flowName),
          _readVariantNames(file.path, flowName, variantNames),
        ),
    });
  }

  /// The [variants] the list names, in their order.
  List<AtlasVariantDefinition> filter(
    Iterable<AtlasVariantDefinition> variants,
  ) {
    return variants.where((variant) => ids.contains(variant.id)).toList();
  }

  static Iterable<String> _resolveVariantIds(
    AtlasDefinition flow,
    List<String> variantNames,
  ) {
    return variantNames.map((name) => flow.findVariant(name).id);
  }

  static List<String> _readVariantNames(
    String listPath,
    String flowName,
    Object? variantNames,
  ) {
    if (variantNames case final List<Object?> names
        when names.every((name) => name is String)) {
      return names.whereType<String>().toList();
    }

    throw AtlasException(
      'The published variants list $listPath maps "$flowName" to '
      '$variantNames; a flow takes a list of variant names.',
    );
  }
}
