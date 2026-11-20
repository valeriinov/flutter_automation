# Backlog

Next id: TD-002

### TD-001 — Store the source hashes of a snapshot once instead of per stage

- **Status:** deferred
- **Opened:** 2026-11-20
- **Source:** session
- **Locations:** `packages/flutter_automation_atlas/lib/src/atlas_snapshot.dart:115`, `packages/flutter_automation_atlas/lib/src/atlas_snapshot.dart:365`, `packages/flutter_automation_atlas/lib/src/atlas_manifest_normalization.dart:68`
- **Why deferred:** the snapshot format change touches every stored snapshot and the staleness check, and the current atlas work does not need it.
- **Unblocked by:** a store of a project grows past the size its owners accept, or the snapshot format changes for another reason.
- **What to do:** A snapshot repeats the `path → hash` map in `manifest` and in the `sources` of each stage, and each locale repeats it again. In a store of 398 snapshots these maps take about 43 MB of 84 MB. Keep one hash table per snapshot (or per store) and let each stage list only the paths it touched; write the JSON without indentation. Read the old format too, so the stores in use stay valid, and prove `stale` gives the same verdicts before and after.
