import 'package:collection/collection.dart';

import 'package:flutter_automation_atlas/src/atlas_journal_stages.dart';

/// {@category Utils}
///
/// A table of project data the page shows beside the flows, such as the
/// requests the app sends.
final class AtlasTable {
  /// The [id] of the table of the translation keys.
  static const localeKeysId = 'localeKeys';

  /// The name the page menu and the page data refer to the table by.
  ///
  /// The table named [localeKeysId] holds the translation keys. Its rows feed
  /// the keys of a stage, the search over them and the page of the keys. They
  /// belong to the `localeKeys` page part. All other tables belong to the
  /// `tables` part. A row may hold the `status` that the page filters by, the
  /// `usages` it lists and the `stages` it appears on, by variant.
  final String id;

  /// The caption of the table, by locale.
  final Map<String, String> title;

  /// The columns of the table, in order.
  final List<AtlasTableColumn> columns;

  /// The rows of the table, each a JSON object that maps a column key to its
  /// value.
  final List<Map<String, Object?>> rows;

  /// The journal kind that the rows come from, such as the kind of the
  /// records of a request. It is `null` when the rows come from no journal
  /// record. A row link opens the stage on that kind.
  final String? journalKind;

  const AtlasTable({
    required this.id,
    required this.title,
    required this.columns,
    required this.rows,
    this.journalKind,
  });

  /// The `stages` entry of a row that appears on [stages]: the stage indexes by
  /// `<flow>/<variant>`. It is empty when [stages] is empty.
  static Map<String, Object?> stagesData(List<AtlasJournalStage> stages) {
    if (stages.isEmpty) {
      return const {};
    }

    return {
      'stages': stages
          .groupListsBy((stage) => stage.variantId)
          .map(
            (variantId, variantStages) => MapEntry(
              variantId,
              variantStages.map((stage) => stage.index).toList(),
            ),
          ),
    };
  }
}

/// {@category Utils}
///
/// One column of an [AtlasTable].
final class AtlasTableColumn {
  /// The key that a row maps to the value of the column.
  final String key;

  /// The caption of the column, by locale.
  final Map<String, String> title;

  const AtlasTableColumn({required this.key, required this.title});
}
