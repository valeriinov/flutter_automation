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

  /// The folder for what a command builds and a repository does not keep:
  /// the headless reports, the worktrees of a baseline walk and the cache of
  /// the encoded screenshots.
  final String build;

  /// The folder that holds one recording file per flow variant of the QA
  /// catalogue.
  final String recordings;

  /// The JSON file that names the variants of each flow the page shows.
  final String publishedVariants;

  const AtlasPaths({
    required this.runnerEntry,
    required this.output,
    required this.build,
    required this.recordings,
    required this.publishedVariants,
  });
}
