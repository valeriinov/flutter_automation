/// {@category Utils}
///
/// How the atlas walks a variant under `flutter test`, without a device.
final class AtlasHeadlessSettings {
  /// The files the walk never enters or runs wholly from a stand-in, by path
  /// or by directory prefix.
  final List<String> stubbedPaths;

  /// The files the walk runs only some declarations of, mapped to the
  /// declaration keys it runs.
  final Map<String, Set<String>> keptDeclarations;

  /// The files the walk runs but for some declarations, mapped to the
  /// declaration keys it stands in for.
  final Map<String, Set<String>> stubbedDeclarations;

  /// The `--dart-define` values of the walk, each as `NAME=value`.
  final List<String> defines;

  /// The folders a baseline worktree takes from the working tree, relative to
  /// the root of the project: the files of the app's hooks and the patched
  /// entry.
  final List<String> copiedDirectories;

  /// The Dart files the generated entry imports, relative to the root of the
  /// project: the files that hold the app's hooks for the package's walk.
  final List<String> entryImports;

  /// The `main` function of the generated entry, placed after the patched
  /// source of the app's `main` file.
  final String entryMain;

  /// The path of the app's `main` file, relative to the root of the project.
  final String mainPath;

  /// The text replacements that turn the app's `main` file into the body of
  /// the entry: each record is the text to find and the text to put in its
  /// place.
  final List<(String, String)> mainPatch;

  /// Reads the values a walk takes from the capture out of the journal
  /// records of a snapshot, such as the sizes of the files the capture device
  /// sent; absent when the walk takes none. The function returns `null` when
  /// the records hold no such value. The package passes the result to the app
  /// in [AtlasHeadlessLaunch.recordedValues].
  final Map<String, Object?>? Function(List<Object?> records)?
  tryReadRecordedValues;

  const AtlasHeadlessSettings({
    required this.copiedDirectories,
    required this.entryImports,
    required this.entryMain,
    required this.mainPath,
    required this.mainPatch,
    this.stubbedPaths = const [],
    this.keptDeclarations = const {},
    this.stubbedDeclarations = const {},
    this.defines = const [],
    this.tryReadRecordedValues,
  });

  /// Whether the walk stands in for or skips any declaration of [path].
  bool hasStubs(String path) {
    return stubbedPaths.any(path.startsWith) ||
        keptDeclarations.containsKey(path) ||
        stubbedDeclarations.containsKey(path);
  }

  /// Whether the walk stands in for or skips the declaration with [key] in
  /// the file at [path].
  bool isStubbedDeclaration(String path, String key) {
    final keptKeys = keptDeclarations[path];

    if (keptKeys != null) {
      return !keptKeys.contains(key);
    }

    return stubbedPaths.any(path.startsWith) ||
        (stubbedDeclarations[path]?.contains(key) ?? false);
  }
}
