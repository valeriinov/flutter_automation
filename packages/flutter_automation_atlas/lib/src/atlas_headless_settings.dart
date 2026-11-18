import 'package:flutter_automation_atlas/src/atlas_headless_upload.dart';

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
  /// the root of the project: the files that run the walk.
  final List<String> copiedDirectories;

  /// The Dart files the generated entry imports, relative to the root of the
  /// project: the helpers that run the walk.
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

  /// The sizes of the images the capture device sent, read from the records
  /// of a journal; absent when the app sends none.
  final List<AtlasHeadlessUpload>? Function(List<Object?> records)?
  tryReadUploads;

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
    this.tryReadUploads,
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
