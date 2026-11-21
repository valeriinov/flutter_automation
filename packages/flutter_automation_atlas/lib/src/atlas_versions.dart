import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_page_renderer.dart';

/// {@category Utils}
///
/// The versions of the atlas that a site folder holds.
///
/// A site folder holds these files:
///
/// - `<version>/index.html`, the page without data, and
///   `<version>/data.json.gz`, the data that the page reads;
/// - `versions.json`, one row per version in the order of the positions;
/// - `atlas-config.json`, the settings that each version page reads, with
///   the link template of the shot storage in `shotUrlTemplate`;
/// - `index.html`, a page that sends the reader to the version with the
///   largest position.
///
/// A version folder that the branch `origin/main` of the repository holds
/// does not change. [publish] refuses such a folder. It first fetches the
/// branch when the repository has a remote `origin` with a branch `main`.
/// Each other member reads the branch as the repository has it.
final class AtlasVersions {
  /// The settings file of a site folder, by its name.
  static const configFileName = 'atlas-config.json';

  /// The data file of a version folder, by its name.
  static const dataFileName = 'data.json.gz';

  static const _versionsFileName = 'versions.json';
  static const _pageFileName = 'index.html';
  static const _shotUrlTemplateKey = 'shotUrlTemplate';
  static const _gitDirectory = '.git';
  static const _remote = 'origin';
  static const _mainBranchHead = 'refs/heads/main';
  static const _mainBranchRef = 'refs/remotes/$_remote/main';
  static const _missingRefExitCode = 1;
  static const _noMatchingRefExitCode = 2;
  static const _encoder = JsonEncoder.withIndent('  ');
  static final _labelPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+-]*$');

  /// The site folder, as an absolute path.
  final String sitePath;

  /// The [sitePath] parameter names the site folder, absolute or relative to
  /// the current directory.
  AtlasVersions(String sitePath) : sitePath = p.normalize(p.absolute(sitePath));

  /// Whether the repository of the site folder holds the branch
  /// `origin/main`. It is `false` outside a git repository.
  ///
  /// Throws an [AtlasException] when git fails for another reason than a
  /// missing branch.
  bool get hasMainBranch {
    final directory = _findExistingDirectory();

    if (!_isInsideRepository(directory)) {
      return false;
    }

    final result = _runGit(directory, [
      'rev-parse',
      '--verify',
      '--quiet',
      '$_mainBranchRef^{commit}',
    ]);

    return switch (result.exitCode) {
      0 => true,
      _missingRefExitCode => false,
      _ => throw _createGitFailure(
        directory,
        'rev-parse $_mainBranchRef',
        result,
      ),
    };
  }

  /// The rows of `versions.json` in the order of the positions. The list is
  /// empty when the site folder holds no such file.
  ///
  /// Throws an [AtlasException] when the file is malformed.
  List<AtlasVersion> read() {
    final file = File(p.join(sitePath, _versionsFileName));

    if (!file.existsSync()) {
      return const [];
    }

    final rows = _decodeRows(file);

    return _sort([
      for (final row in rows)
        AtlasVersion.fromJson(
          AtlasJson.readObject(row, 'A row of ${file.path}'),
        ),
    ]);
  }

  /// The fields of `atlas-config.json`. The map is empty when the site folder
  /// holds no such file.
  ///
  /// Throws an [AtlasException] when the file is malformed.
  Map<String, Object?> readConfig() {
    final file = File(p.join(sitePath, configFileName));

    if (!file.existsSync()) {
      return const {};
    }

    return AtlasJson.decodeObject(file.readAsStringSync(), file.path);
  }

  /// Whether [label] can name a version folder: one path segment of
  /// letters, digits, `.`, `_`, `+` and `-`.
  static bool isLabel(String label) => _labelPattern.hasMatch(label);

  /// The folder of the version with the [label].
  String resolveVersionPath(String label) => p.join(sitePath, label);

  /// Whether the branch `origin/main` holds a file of the folder of the
  /// version with the [label].
  bool isOnMainBranch(String label) {
    if (!hasMainBranch) {
      return false;
    }

    final directory = _findExistingDirectory();
    final files = _tryRunGit([
      'ls-tree',
      '-r',
      '--name-only',
      _mainBranchRef,
      '--',
      p.relative(resolveVersionPath(label), from: directory),
    ], workingDirectory: directory);

    if (files == null) {
      throw AtlasException('git ls-tree $_mainBranchRef failed in $directory.');
    }

    return files.isNotEmpty;
  }

  /// Whether a commit of the branch `origin/main` changed a file of the
  /// folder of the version with the [label]. It is `true` for a folder that
  /// the branch held once and holds no more.
  bool wasOnMainBranch(String label) {
    if (!hasMainBranch) {
      return false;
    }

    final directory = _findExistingDirectory();
    final commit = _tryRunGit([
      'log',
      '-1',
      '--format=%H',
      _mainBranchRef,
      '--',
      p.relative(resolveVersionPath(label), from: directory),
    ], workingDirectory: directory);

    if (commit == null) {
      throw AtlasException('git log $_mainBranchRef failed in $directory.');
    }

    return commit.isNotEmpty;
  }

  /// Writes the folder of [version] with the files of [rendering]. It then
  /// writes the row of the version into `versions.json` and the link template
  /// of [rendering] into `atlas-config.json`. It keeps each other field of
  /// the settings file. It points the `index.html` of the site folder at the
  /// version with the largest position.
  ///
  /// It replaces a folder and a row with the same label.
  ///
  /// Throws an [AtlasException] when the label is not one path segment of
  /// letters, digits, `.`, `_`, `+` and `-`. It throws also when the fetch
  /// of the branch `origin/main` fails, and when the branch holds the folder
  /// of the version.
  void publish(AtlasVersion version, AtlasVersionRendering rendering) {
    final label = version.label;

    if (!isLabel(label)) {
      throw _createLabelFailure(label);
    }

    _fetchMainBranch();

    if (isOnMainBranch(label)) {
      throw AtlasException(
        'The branch origin/main holds the version folder '
        '${resolveVersionPath(label)}; a published version does not change.',
      );
    }

    final config = readConfig();
    final versions = _sort([
      ...read().where((row) => row.label != label),
      version,
    ]);

    _deleteVersionFolder(label);
    _writeBytes(
      p.join(resolveVersionPath(label), _pageFileName),
      utf8.encode(rendering.page),
    );
    _writeBytes(
      p.join(resolveVersionPath(label), dataFileName),
      rendering.data,
    );
    _writeVersions(versions);
    _writeJson(configFileName, {
      ...config,
      _shotUrlTemplateKey: rendering.shotUrlTemplate,
    });
  }

  /// Deletes the folder and the row of each version that [labels] name. It
  /// then points the `index.html` of the site folder at the version with the
  /// largest position that stays. It deletes that `index.html` when no
  /// version stays.
  ///
  /// Throws an [AtlasException] when a label names a folder outside the site
  /// folder.
  void remove(Iterable<String> labels) {
    final removed = labels.toSet();

    if (removed.isEmpty) {
      return;
    }

    removed.forEach(_deleteVersionFolder);
    _writeVersions(
      read().where((row) => !removed.contains(row.label)).toList(),
    );
  }

  List<Object?> _decodeRows(File file) {
    final rows = _tryDecode(file.readAsStringSync());

    if (rows is List<Object?>) {
      return rows;
    }

    throw AtlasException('${file.path} is not a JSON list.');
  }

  Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  String? _tryRunGit(
    List<String> arguments, {
    required String workingDirectory,
  }) {
    final result = _runGit(workingDirectory, arguments);

    return result.exitCode == 0 ? '${result.stdout}'.trim() : null;
  }

  static AtlasException _createLabelFailure(String label) {
    return AtlasException(
      'The version label "$label" is not a folder name: it takes letters, '
      'digits and the characters . _ + -.',
    );
  }

  void _fetchMainBranch() {
    final directory = _findExistingDirectory();

    if (!_isInsideRepository(directory) || !_hasOrigin(directory)) {
      return;
    }

    final listing = _runGit(directory, [
      'ls-remote',
      '--exit-code',
      _remote,
      _mainBranchHead,
    ]);

    if (listing.exitCode == _noMatchingRefExitCode) {
      return;
    }

    if (listing.exitCode != 0) {
      throw _createGitFailure(
        directory,
        'ls-remote $_remote $_mainBranchHead',
        listing,
      );
    }

    final fetch = _runGit(directory, [
      'fetch',
      '--quiet',
      _remote,
      '+$_mainBranchHead:$_mainBranchRef',
    ]);

    if (fetch.exitCode != 0) {
      throw _createGitFailure(
        directory,
        'fetch $_remote $_mainBranchHead',
        fetch,
      );
    }
  }

  String _findExistingDirectory() {
    Directory directory = Directory(sitePath);

    while (!directory.existsSync() && directory.parent.path != directory.path) {
      directory = directory.parent;
    }

    return directory.path;
  }

  bool _isInsideRepository(String path) {
    Directory directory = Directory(path);

    while (!_hasGitEntry(directory) &&
        directory.parent.path != directory.path) {
      directory = directory.parent;
    }

    return _hasGitEntry(directory);
  }

  bool _hasGitEntry(Directory directory) {
    final entry = p.join(directory.path, _gitDirectory);

    return FileSystemEntity.typeSync(entry) != FileSystemEntityType.notFound;
  }

  bool _hasOrigin(String directory) {
    final remotes = _runGit(directory, ['remote']);

    if (remotes.exitCode != 0) {
      throw _createGitFailure(directory, 'remote', remotes);
    }

    return const LineSplitter().convert('${remotes.stdout}').contains(_remote);
  }

  ProcessResult _runGit(String directory, List<String> arguments) {
    return Process.runSync(
      'git',
      arguments,
      workingDirectory: directory,
      stdoutEncoding: utf8,
    );
  }

  AtlasException _createGitFailure(
    String directory,
    String command,
    ProcessResult result,
  ) {
    return AtlasException(
      'git $command failed in $directory: ${result.stderr}',
    );
  }

  List<AtlasVersion> _sort(List<AtlasVersion> versions) {
    return versions..sort(_compare);
  }

  int _compare(AtlasVersion first, AtlasVersion second) {
    final byPosition = first.position.compareTo(second.position);

    return byPosition == 0 ? first.label.compareTo(second.label) : byPosition;
  }

  void _deleteVersionFolder(String label) {
    final folder = Directory(p.normalize(resolveVersionPath(label)));

    if (!p.isWithin(sitePath, folder.path)) {
      throw AtlasException(
        'The version folder ${folder.path} is outside the site folder '
        '$sitePath.',
      );
    }

    if (folder.existsSync()) {
      folder.deleteSync(recursive: true);
    }
  }

  void _writeVersions(List<AtlasVersion> versions) {
    _writeJson(_versionsFileName, [
      for (final version in versions) version.toJson(),
    ]);

    final latest = versions.lastOrNull;
    final page = File(p.join(sitePath, _pageFileName));

    if (latest != null) {
      _writeBytes(page.path, utf8.encode(_buildRedirectPage(latest.label)));

      return;
    }

    if (page.existsSync()) {
      page.deleteSync();
    }
  }

  void _writeJson(String fileName, Object? json) {
    _writeBytes(
      p.join(sitePath, fileName),
      utf8.encode('${_encoder.convert(json)}\n'),
    );
  }

  String _buildRedirectPage(String label) {
    final link = './${Uri.encodeComponent(label)}/';

    return '<!doctype html>\n'
        '<html lang="en">\n'
        '<head>\n'
        '<meta charset="utf-8">\n'
        '<meta http-equiv="refresh" content="0; url=$link">\n'
        '<title>Atlas</title>\n'
        '</head>\n'
        '<body>\n'
        '<p><a href="$link">$label</a></p>\n'
        '</body>\n'
        '</html>\n';
  }

  void _writeBytes(String path, List<int> bytes) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }
}

/// {@category Utils}
///
/// One row of the `versions.json` file of a site folder.
final class AtlasVersion {
  static const _labelKey = 'version';
  static const _positionKey = 'position';
  static const _builtAtKey = 'builtAt';
  static const _sourceLabelKey = 'sourceLabel';

  /// The label of the version. It names the folder of the version.
  final String label;

  /// The place of the version among the others. The version with the largest
  /// position is the latest one.
  final int position;

  /// The time when the page of the version was built, as ISO 8601 text.
  final String builtAt;

  /// The label of the source that the page footer shows; `null` when the
  /// version has none.
  final String? sourceLabel;

  const AtlasVersion({
    required this.label,
    required this.position,
    required this.builtAt,
    this.sourceLabel,
  });

  /// Reads a row of `versions.json`.
  ///
  /// Throws an [AtlasException] when the row holds no label or no position.
  /// It throws also when the label is not a folder name.
  factory AtlasVersion.fromJson(Map<String, Object?> json) {
    final position = json[_positionKey];
    final label = AtlasJson.readString(json, _labelKey);

    if (position is! int) {
      throw AtlasException('"$_positionKey" is not a whole number in $json.');
    }

    if (!AtlasVersions.isLabel(label)) {
      throw AtlasVersions._createLabelFailure(label);
    }

    return AtlasVersion(
      label: label,
      position: position,
      builtAt: AtlasJson.tryReadString(json, _builtAtKey) ?? '',
      sourceLabel: AtlasJson.tryReadString(json, _sourceLabelKey),
    );
  }

  /// The row as `versions.json` holds it.
  Map<String, Object?> toJson() {
    return {
      _labelKey: label,
      _positionKey: position,
      _builtAtKey: builtAt,
      _sourceLabelKey: ?sourceLabel,
    };
  }
}
