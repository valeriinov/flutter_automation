import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_journal_stages.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_project.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';

/// {@category Utils}
///
/// Reads the atlas stored in a store folder: the snapshots the captures wrote.
///
/// The atlas gives a reader to [AtlasProject.tables] and
/// [AtlasProject.writeReports]. A check outside `runAtlas` opens one with
/// [AtlasStoreReader.open].
abstract interface class AtlasStoreReader {
  /// Opens the store of [project] under [rootPath]. The default [rootPath] is
  /// the current directory. The [store] parameter replaces the output folder
  /// of the project.
  factory AtlasStoreReader.open(
    AtlasProject project, {
    String rootPath = '.',
    String? store,
  }) {
    return AtlasLocationsStore(AtlasLocations(rootPath, project, store: store));
  }

  /// The directory that the paths of the repository files start from.
  String get rootPath;

  /// The folder of the store: the output folder of the project, or the one a
  /// `--store` option names.
  String get storePath;

  /// Whether the store is the output folder of the project, not one a
  /// `--store` option names.
  bool get isDefaultStore;

  /// Each record of [kind] that the published variants logged, in the default
  /// locale. Each record comes with the stage that the page shows it on. That
  /// is the `<flow>/<variant>` it belongs to and the zero-based index among
  /// the stages of that snapshot. The end of the snapshot takes the index
  /// after its last stage.
  List<AtlasJournalRecord> recordsOf(String kind);

  /// The `<flow> <variant>` of each snapshot in the default locale that
  /// walks a screen, by screen name.
  Map<String, List<String>> walkersByScreen();

  /// Each snapshot of the store folder, in every locale. The order is by
  /// flow, then by variant, then by locale.
  List<AtlasSnapshot> snapshots();
}

/// {@category Utils}
///
/// The [AtlasStoreReader] of the store folder of [AtlasLocations].
final class AtlasLocationsStore implements AtlasStoreReader {
  final AtlasLocations _paths;

  const AtlasLocationsStore(this._paths);

  @override
  String get rootPath => _paths.rootPath;

  @override
  String get storePath => _paths.storePath;

  @override
  bool get isDefaultStore {
    return p.equals(
      _paths.storePath,
      AtlasLocations(_paths.rootPath, _paths.project).storePath,
    );
  }

  @override
  List<AtlasJournalRecord> recordsOf(String kind) {
    return AtlasJournalStages(_paths).readRecords(kind);
  }

  @override
  Map<String, List<String>> walkersByScreen() {
    final walkersByScreen = <String, List<String>>{};

    for (final snapshot in AtlasSnapshotStore(
      _paths,
    ).readAll(locale: _paths.defaultLocale)) {
      for (final screen in _readWalkedScreens(snapshot)) {
        walkersByScreen.putIfAbsent(screen, () => []).add(snapshot.id);
      }
    }

    return walkersByScreen;
  }

  @override
  List<AtlasSnapshot> snapshots() {
    return AtlasSnapshotStore(_paths).readEveryLocale().sorted(_compare);
  }

  Iterable<String> _readWalkedScreens(AtlasSnapshot snapshot) {
    return <String?>{
      ...snapshot.stages.map((stage) => stage.screen),
      snapshot.end.screen,
    }.nonNulls;
  }

  int _compare(AtlasSnapshot first, AtlasSnapshot second) {
    final keys = [
      (first.flow, second.flow),
      (first.variant, second.variant),
      (first.locale, second.locale),
    ];

    return keys
        .map((key) => key.$1.compareTo(key.$2))
        .firstWhere((order) => order != 0, orElse: () => 0);
  }
}
