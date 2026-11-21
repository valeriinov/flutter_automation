/// {@category Utils}
///
/// The places of the project the atlas reads and writes, each relative to
/// the root of the project.
final class AtlasPaths {
  /// The entry point of the automation runner, a Dart file that calls
  /// `runFlows`.
  final String runnerEntry;

  /// The folder that holds the atlas by default: the snapshots, the
  /// declarations, the screenshots and the page. The `--store` option
  /// replaces it.
  final String output;

  /// The folder for what a command builds and the repository does not keep.
  /// It holds the headless reports, the worktrees of a baseline walk and the
  /// cache of the encoded screenshots.
  final String build;

  /// The folder that holds one file of recorded answers per flow variant of
  /// the QA catalogue.
  final String recordings;

  /// The JSON file that names the variants of each flow the page shows.
  final String publishedVariants;

  /// The JSON file of the translations the app shows in one locale, with
  /// `{locale}` in place of the locale, such as `assets/{locale}.json`. The
  /// atlas reads it when [AtlasProject.translations] returns no values. It is
  /// `null` when the project gives no file.
  final String? translations;

  /// The JSON file that maps each design screen to its prose by locale. The
  /// atlas reads it when [AtlasProject.screenDescriptions] is empty. It is
  /// `null` when the project gives no file.
  final String? screenDescriptions;

  /// The JSON file that maps each translation key that no stage shows to the
  /// reason, relative to the store folder: each store keeps the list of its
  /// own snapshots. It is `null` when the project keeps no list; the key
  /// coverage check then skips.
  final String? uncoveredLocaleKeys;

  const AtlasPaths({
    required this.runnerEntry,
    required this.output,
    required this.build,
    required this.recordings,
    required this.publishedVariants,
    this.translations,
    this.screenDescriptions,
    this.uncoveredLocaleKeys,
  });
}
