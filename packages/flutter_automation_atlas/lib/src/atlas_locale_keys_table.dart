import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_journal_stages.dart';
import 'package:flutter_automation_atlas/src/atlas_locale_key_coverage.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_table.dart';
import 'package:flutter_automation_atlas/src/atlas_translations.dart';

typedef _LocaleKeyUsage = ({String key, String location});

typedef _ShownLocaleKey = ({String key, AtlasJournalStage stage});

/// {@category Utils}
///
/// The table [AtlasTable.localeKeysId] the atlas builds when the project
/// gives none: one row per key of the default locale translations, in their
/// order.
///
/// A row names where `lib/` references the key. It names which stages of the
/// stored snapshots of the default locale show the key. It also gives the
/// `status` of the key. The `status` is `onFrames` when a published variant
/// shows the key. Else it is the reason that the uncovered keys list gives.
/// Else it is `pending`. A key whose reason is `unused` takes the `place` and
/// the `widget` that its list line names.
final class AtlasLocaleKeysTable {
  static const _dartExtension = '.dart';
  static const _onFramesStatus = 'onFrames';

  final AtlasLocations _paths;

  const AtlasLocaleKeysTable(this._paths);

  /// Whether the default locale translations hold a key to list.
  bool get hasKeys {
    return AtlasTranslations.read(
      _paths,
      _paths.defaultLocale,
    ).values.isNotEmpty;
  }

  /// The table of each key.
  AtlasTable build() {
    final coverage = AtlasLocaleKeyCoverageReport(_paths).reconcile();
    final usagesByKey = _readUsagesByKey();
    final stagesByKey = _readStagesByKey();

    return AtlasTable(
      id: AtlasTable.localeKeysId,
      title: const {'en': 'Localization keys', 'uk': 'Ключі локалізації'},
      columns: const [
        AtlasTableColumn(key: 'key', title: {'en': 'Key', 'uk': 'Ключ'}),
      ],
      rows: [
        for (final key in coverage.keys)
          _buildRow(
            key,
            coverage,
            usagesByKey[key] ?? const [],
            stagesByKey[key] ?? const [],
          ),
      ],
    );
  }

  Map<String, Object?> _buildRow(
    String key,
    AtlasLocaleKeyCoverage coverage,
    List<String> usages,
    List<AtlasJournalStage> stages,
  ) {
    final place = coverage.isOnFrames(key) ? null : coverage.placesByKey[key];

    return {
      'key': key,
      'status': _resolveStatus(key, coverage),
      'place': ?place?.place,
      'widget': ?place?.widget,
      'usages': usages,
      ...AtlasTable.stagesData(stages),
    };
  }

  String _resolveStatus(String key, AtlasLocaleKeyCoverage coverage) {
    if (coverage.isOnFrames(key)) {
      return _onFramesStatus;
    }

    return coverage.reasonsByKey[key] ?? AtlasLocaleKeyReason.pending.name;
  }

  Map<String, List<String>> _readUsagesByKey() {
    final pattern = _paths.project.localeKeyUsagePattern;

    if (pattern == null) {
      return const {};
    }

    return _readSourceFiles()
        .expand((file) => _readFileUsages(file, pattern))
        .groupListsBy((usage) => usage.key)
        .map(
          (key, usages) =>
              MapEntry(key, [for (final usage in usages) usage.location]),
        );
  }

  Map<String, List<AtlasJournalStage>> _readStagesByKey() {
    return AtlasSnapshotStore(_paths)
        .readAll(locale: _paths.defaultLocale)
        .expand(_readShownKeys)
        .groupListsBy((shownKey) => shownKey.key)
        .map(
          (key, shownKeys) =>
              MapEntry(key, [for (final shownKey in shownKeys) shownKey.stage]),
        );
  }

  List<File> _readSourceFiles() {
    final directory = Directory(
      _paths.resolve(AutomationCoverageManifest.appSourceDirectory),
    );

    if (!directory.existsSync()) {
      return const [];
    }

    return directory
        .listSync(recursive: true)
        .whereType<File>()
        .where(_isHandWrittenSource)
        .sorted((first, second) => first.path.compareTo(second.path));
  }

  List<_LocaleKeyUsage> _readFileUsages(File file, RegExp pattern) {
    final content = file.readAsStringSync();
    final path = p.relative(file.path, from: _paths.rootPath);

    return [
      for (final match in pattern.allMatches(content))
        (
          key: match[1] ?? '',
          location:
              '$path:${content.substring(0, match.end).split('\n').length}',
        ),
    ];
  }

  List<_ShownLocaleKey> _readShownKeys(AtlasSnapshot snapshot) {
    return [
      for (final (index, stage) in snapshot.stages.indexed)
        for (final key in stage.localeKeys.keys)
          (key: key, stage: AtlasJournalStages.stageOf(snapshot, index)),
      for (final key in snapshot.end.localeKeys.keys)
        (
          key: key,
          stage: AtlasJournalStages.stageOf(snapshot, snapshot.stages.length),
        ),
    ];
  }

  bool _isHandWrittenSource(File file) {
    return p.extension(file.path) == _dartExtension &&
        !AutomationCoverageManifest.generatedSuffixes.any(file.path.endsWith);
  }
}
