import 'package:flutter_automation_atlas/src/atlas_headless_hashes.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_check.dart';

/// {@category Utils}
///
/// Picks the variants whose frames `stale` has not compared yet: stale for
/// [AtlasStaleReason.code] or [AtlasStaleReason.stageCode] with no
/// changed localization key and no mock difference, in the default locale,
/// whose snapshot holds the headless hashes of the renderer a walk runs on
/// now on every stage and the end
/// ([AtlasHeadlessHashes.hasEveryHeadlessHash]), while the current
/// headless report of the variant is absent or walked other code than the
/// manifest files of its snapshot hold now. A current headless walk of such a
/// variant may show its frames alike; a variant whose snapshot holds no such
/// hashes has nothing to compare a walk with and is captured on the device,
/// which writes them.
final class AtlasHeadlessSelection {
  static const _codeReasons = {
    AtlasStaleReason.code,
    AtlasStaleReason.stageCode,
  };

  final AtlasLocations _paths;
  final String _locale;
  final AtlasHeadlessHashes _hashes;

  AtlasHeadlessSelection(this._paths, this._locale)
    : _hashes = AtlasHeadlessHashes(_paths);

  /// The variants of [stalenesses] whose frames are not compared, in order.
  List<AtlasVariantDefinition> select(List<AtlasStaleness> stalenesses) {
    return [
      for (final staleness in stalenesses)
        if (isUncompared(staleness)) staleness.variant,
    ];
  }

  /// Whether the frames of the variant of [staleness] are not compared.
  bool isUncompared(AtlasStaleness staleness) {
    if (!_isStaleForCodeAlone(staleness)) {
      return false;
    }

    final variant = staleness.variant;
    final snapshot = AtlasSnapshotStore(
      _paths,
    ).tryRead(flow: variant.flow, variant: variant.name, locale: _locale);

    if (snapshot == null) {
      return false;
    }

    return _hashes.hasEveryHeadlessHash(snapshot) &&
        _hashes.tryReadCurrentReport(snapshot) == null;
  }

  bool _isStaleForCodeAlone(AtlasStaleness staleness) {
    return _locale == _paths.defaultLocale &&
        _codeReasons.contains(staleness.reason) &&
        staleness.changedTranslationKeys.isEmpty &&
        staleness.mockDifference == null;
  }
}
