import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';

/// {@category Utils}
///
/// The snapshots one locale shows, by variant id.
///
/// A variant captured in the locale shows its own snapshot; a variant
/// captured only in the default locale shows that snapshot,
/// marked with the locale it falls back to, so a locale shows every variant
/// before its own capture.
abstract final class AtlasSeries {
  /// The snapshot of each variant [snapshots] hold in [locale] or in
  /// [defaultLocale], by variant id, in the order of [snapshots].
  static Map<String, AtlasSeriesSnapshot> resolve(
    List<AtlasSnapshot> snapshots, {
    required String locale,
    required String defaultLocale,
  }) {
    final ownIds = {
      for (final snapshot in snapshots)
        if (snapshot.locale == locale) snapshot.id,
    };

    return {
      for (final snapshot in snapshots)
        if (snapshot.locale == locale)
          snapshot.id: AtlasSeriesSnapshot(snapshot)
        else if (_isFallback(snapshot, ownIds, defaultLocale))
          snapshot.id: AtlasSeriesSnapshot(
            snapshot,
            fallbackLocale: snapshot.locale,
          ),
    };
  }

  static bool _isFallback(
    AtlasSnapshot snapshot,
    Set<String> ownIds,
    String defaultLocale,
  ) {
    return snapshot.locale == defaultLocale && !ownIds.contains(snapshot.id);
  }
}

/// {@category Utils}
///
/// The snapshot a locale shows for one variant.
final class AtlasSeriesSnapshot {
  /// The snapshot shown.
  final AtlasSnapshot snapshot;

  /// The locale [snapshot] was captured in when the variant has no capture
  /// in the shown locale, `null` when it is the shown locale's own.
  final String? fallbackLocale;

  const AtlasSeriesSnapshot(this.snapshot, {this.fallbackLocale});
}
