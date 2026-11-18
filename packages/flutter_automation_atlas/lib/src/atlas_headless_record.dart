import 'dart:io';

import 'package:flutter_automation_atlas/src/atlas_headless_hashes.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_check.dart';

/// {@category Utils}
///
/// Writes, without a device, the frame and journal hashes the current
/// headless report holds onto every stage and the end of the `uk` snapshot of
/// each fresh variant, with the renderer of the walk
/// ([AtlasHeadless.readRenderer]): a fresh snapshot describes the
/// current code, so the current walk shows what its capture showed.
///
/// A stale variant, or a fresh one whose current report is absent, walked
/// other code than its manifest files hold now, or holds no frame hash or
/// journal of a stage or no end frame hash, is left as it is and named.
final class AtlasHeadlessRecord {
  final AtlasLocations _paths;

  const AtlasHeadlessRecord(this._paths);

  /// Writes the hashes of the fresh variants of [stalenesses] and prints
  /// every variant it leaves.
  void run(List<AtlasStaleness> stalenesses) {
    final store = AtlasSnapshotStore(_paths);
    final hashes = AtlasHeadlessHashes(_paths);

    for (final staleness in stalenesses) {
      _record(staleness, store, hashes);
    }
  }

  /// Prints that the variant [id] keeps its headless hashes for [reason].
  static void printLeft(String id, String reason) {
    stdout.writeln('$id headless hashes left: $reason');
  }

  void _record(
    AtlasStaleness staleness,
    AtlasSnapshotStore store,
    AtlasHeadlessHashes hashes,
  ) {
    final variant = staleness.variant;

    if (staleness.isStale) {
      printLeft(variant.id, staleness.reason.label);

      return;
    }

    final snapshot = store.tryRead(
      flow: variant.flow,
      variant: variant.name,
      locale: _paths.defaultLocale,
    );

    if (snapshot == null) {
      printLeft(variant.id, 'no snapshot');

      return;
    }

    final report = hashes.tryReadCurrentReport(snapshot);
    final missingHashes = AtlasHeadlessHashes.tryDescribeMissingHashes(
      report,
      snapshot,
    );

    if (missingHashes != null) {
      printLeft(variant.id, missingHashes);

      return;
    }

    store.write(
      hashes.apply(
        snapshot,
        report,
        shotStages: Iterable<int>.generate(snapshot.stages.length).toSet(),
        isEndShot: true,
      ),
    );
    stdout.writeln('${variant.id} headless hashes written');
  }
}
