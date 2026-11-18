import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';

/// {@category Utils}
///
/// Reads and writes the snapshot files of the catalogue.
///
/// A snapshot is written with a two-space indent and a trailing newline, keys
/// in a fixed order, so the same capture writes the same bytes.
final class AtlasSnapshotStore {
  static const _encoder = JsonEncoder.withIndent('  ');
  static const _jsonExtension = '.json';

  final AtlasLocations _paths;

  const AtlasSnapshotStore(this._paths);

  /// The snapshot of one variant in [locale], `null` when it was never
  /// captured in it.
  AtlasSnapshot? tryRead({
    required String flow,
    required String variant,
    required String locale,
  }) {
    final file = File(
      _paths.resolveSnapshotPath(flow: flow, variant: variant, locale: locale),
    );

    if (!file.existsSync()) {
      return null;
    }

    return _read(file);
  }

  /// Every snapshot captured in [locale], in the order of their paths.
  List<AtlasSnapshot> readAll({required String locale}) {
    return readEveryLocale()
        .where((snapshot) => snapshot.locale == locale)
        .toList();
  }

  /// Every snapshot under the data directory, of every locale, in the order
  /// of their paths.
  List<AtlasSnapshot> readEveryLocale() {
    final directory = Directory(_paths.dataPath);

    if (!directory.existsSync()) {
      return const [];
    }

    final files =
        directory
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => p.extension(file.path) == _jsonExtension)
            .toList()
          ..sort((first, second) => first.path.compareTo(second.path));

    return files.map(_read).toList();
  }

  /// Writes [snapshot] over the file of its variant and locale.
  void write(AtlasSnapshot snapshot) {
    final path = _paths.resolveSnapshotPath(
      flow: snapshot.flow,
      variant: snapshot.variant,
      locale: snapshot.locale,
    );

    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('${_encoder.convert(snapshot.toJson())}\n');
  }

  AtlasSnapshot _read(File file) {
    try {
      return AtlasSnapshot.fromJson(
        jsonDecode(file.readAsStringSync()),
        fileLocale: _paths.resolveSnapshotLocale(file.path),
      );
    } on Exception catch (error) {
      throw AtlasException('Snapshot ${file.path} is unreadable: $error');
    }
  }
}
