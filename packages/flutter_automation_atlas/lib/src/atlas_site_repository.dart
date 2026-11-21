import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_versions.dart';

/// {@category Utils}
///
/// The repository of the store folder, with its branches as `origin` holds
/// them, and the site folders of the repository.
final class AtlasSiteRepository {
  /// The remote that holds the published branches and tags.
  static const remote = 'origin';

  /// The start of the full name of a tag.
  static const tagRefPrefix = 'refs/tags/';

  /// The branch `origin/main`, by its full name.
  static const mainBranchRef = 'refs/remotes/$remote/main';

  static const _siteDirectory = 'site';
  static const _branchRefspec = '+refs/heads/*:refs/remotes/$remote/*';

  /// The top folder of the repository.
  final String rootPath;

  AtlasSiteRepository._(this.rootPath);

  /// Finds the repository of the store folder of [paths]. It then runs
  /// `git fetch --prune --no-tags origin` and fetches the refspec
  /// `+refs/heads/*:refs/remotes/origin/*`.
  ///
  /// The [reader] parameter names the caller in the failure text of a
  /// repository without the branch `origin/main`, as in `the prune`.
  ///
  /// Throws an [AtlasException] in these cases:
  /// - The store folder is missing or outside a git repository.
  /// - A fetch fails.
  /// - The repository holds no branch `origin/main`.
  factory AtlasSiteRepository.fetch(
    AtlasLocations paths, {
    required String reader,
  }) {
    final repository = AtlasSiteRepository._(_readRootPath(paths.storePath));

    repository.runGit(['fetch', '--prune', '--no-tags', remote]);
    repository.runGit(['fetch', '--no-tags', remote, _branchRefspec]);
    repository._requireMainBranch(reader);

    return repository;
  }

  /// Checks that the repository holds the full history of its branches.
  ///
  /// Throws an [AtlasException] when the repository is a shallow clone.
  void requireFullHistory() {
    if (runGit(['rev-parse', '--is-shallow-repository']) != 'true') {
      return;
    }

    throw AtlasException(
      'The repository $rootPath is a shallow clone; the command needs the '
      'full history of $remote/main.',
    );
  }

  /// The site folders that [sites] name. When [sites] is empty, the result
  /// holds each folder `site/<name>/` of the repository that holds an
  /// `atlas-config.json`.
  ///
  /// Throws an [AtlasException] when a site folder is missing or outside the
  /// repository.
  List<AtlasVersions> resolveSites(List<String> sites) {
    final paths = sites.isEmpty ? _findSites() : sites;

    return [for (final path in paths) _readSite(path)];
  }

  /// The names of the tags that `origin` holds.
  Set<String> readOriginTags() {
    final refs = readLines(['ls-remote', '--tags', '--refs', remote]);

    return {
      for (final ref in refs)
        if (ref.contains(tagRefPrefix))
          ref.substring(ref.indexOf(tagRefPrefix) + tagRefPrefix.length),
    };
  }

  /// The output lines of git with the [arguments] in the repository.
  ///
  /// Throws an [AtlasException] when git fails.
  List<String> readLines(List<String> arguments) {
    return const LineSplitter().convert(runGit(arguments));
  }

  /// The output of git with the [arguments] in the repository.
  ///
  /// Throws an [AtlasException] when git fails.
  String runGit(List<String> arguments) => _runGit(rootPath, arguments);

  static String _readRootPath(String storePath) {
    if (!Directory(storePath).existsSync()) {
      throw AtlasException('No store folder at $storePath.');
    }

    return _runGit(storePath, ['rev-parse', '--show-toplevel']);
  }

  void _requireMainBranch(String reader) {
    final result = Process.runSync('git', [
      'rev-parse',
      '--verify',
      '--quiet',
      '$mainBranchRef^{commit}',
    ], workingDirectory: rootPath);

    if (result.exitCode != 0) {
      throw AtlasException(
        'The repository $rootPath holds no branch $remote/main; $reader '
        'cannot tell a published version.',
      );
    }
  }

  List<String> _findSites() {
    final directory = Directory(p.join(rootPath, _siteDirectory));

    if (!directory.existsSync()) {
      return const [];
    }

    return [
      for (final folder in directory.listSync().whereType<Directory>())
        if (File(
          p.join(folder.path, AtlasVersions.configFileName),
        ).existsSync())
          folder.path,
    ]..sort();
  }

  AtlasVersions _readSite(String path) {
    final directory = Directory(path);

    if (!directory.existsSync()) {
      throw AtlasException('No site folder at $path.');
    }

    final site = AtlasVersions(directory.resolveSymbolicLinksSync());

    if (!p.isWithin(rootPath, site.sitePath)) {
      throw AtlasException(
        'The site folder $path is outside the repository $rootPath of the '
        'store folder.',
      );
    }

    return site;
  }

  static String _runGit(String directory, List<String> arguments) {
    final result = Process.runSync(
      'git',
      arguments,
      workingDirectory: directory,
      stdoutEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw AtlasException(
        'git ${arguments.join(' ')} failed in $directory: ${result.stderr}',
      );
    }

    return '${result.stdout}'.trim();
  }
}
