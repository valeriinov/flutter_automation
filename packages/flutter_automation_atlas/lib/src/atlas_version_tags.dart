import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_site_repository.dart';
import 'package:flutter_automation_atlas/src/atlas_versions.dart';

/// {@category Utils}
///
/// Puts on `origin` the git tag of each row of `versions.json` whose folder
/// the branch `origin/main` holds.
///
/// A run first fetches the branches of `origin`, as an `AtlasPrune` does. It
/// works on each site folder whose `atlas-config.json` holds the field
/// `versionTagTemplate`. The field gives the name of the tag of a version.
///
/// The tag of a version names the commit of the branch `origin/main` that
/// last added the `data.json.gz` file of the version folder. A version
/// gets no tag in these cases:
///
/// - The branch `origin/main` does not hold the folder of the version.
/// - `origin` holds the tag.
/// - A site folder earlier in the run gives the same tag.
///
/// One `git push --atomic` puts the tags on `origin`. The run creates no tag
/// in the repository.
final class AtlasVersionTags {
  final AtlasLocations _paths;
  final List<String> _sites;

  /// The [sites] parameter names the site folders. When it is empty, the run
  /// takes each folder `site/<name>/` of the repository that holds an
  /// `atlas-config.json`.
  AtlasVersionTags(this._paths, {List<String> sites = const []})
    : _sites = sites;

  /// Puts the tags on `origin`. Returns the tags in the order of their
  /// names.
  ///
  /// Throws an [AtlasException] in these cases:
  /// - The store folder is missing.
  /// - The store folder is outside a git repository, or the fetch fails.
  /// - The repository holds no branch `origin/main`.
  /// - The repository is a shallow clone.
  /// - A site folder is missing or outside the repository.
  /// - `versions.json` or `atlas-config.json` of a site folder is malformed.
  /// - The field `versionTagTemplate` of a site folder is malformed.
  /// - `origin` refuses the tags.
  List<AtlasVersionTag> run() {
    final repository = AtlasSiteRepository.fetch(
      _paths,
      reader: 'the tag-versions command',
    );

    repository.requireFullHistory();

    final originTags = repository.readOriginTags();
    final found = [
      for (final site in repository.resolveSites(_sites))
        ..._findTags(repository, site, originTags),
    ];
    final tags =
        {for (final tag in found.reversed) tag.name: tag}.values.toList()
          ..sort((first, second) => first.name.compareTo(second.name));

    if (tags.isNotEmpty) {
      repository.runGit([
        'push',
        '--atomic',
        AtlasSiteRepository.remote,
        for (final tag in tags)
          '${tag.commit}:${AtlasSiteRepository.tagRefPrefix}${tag.name}',
      ]);
    }

    return tags;
  }

  List<AtlasVersionTag> _findTags(
    AtlasSiteRepository repository,
    AtlasVersions site,
    Set<String> originTags,
  ) {
    if (!site.hasVersionTagTemplate) {
      return const [];
    }

    return [
      for (final version in site.read())
        if (site.isOnMainBranch(version.label))
          ?_tryFindTag(repository, site, version.label, originTags),
    ];
  }

  AtlasVersionTag? _tryFindTag(
    AtlasSiteRepository repository,
    AtlasVersions site,
    String label,
    Set<String> originTags,
  ) {
    final name = site.resolveVersionTag(label);

    if (name == null || originTags.contains(name)) {
      return null;
    }

    final commit = repository.readLines([
      'log',
      '-1',
      '--diff-filter=A',
      '--format=%H',
      AtlasSiteRepository.mainBranchRef,
      '--',
      p.relative(
        p.join(site.resolveVersionPath(label), AtlasVersions.dataFileName),
        from: repository.rootPath,
      ),
    ]).firstOrNull;

    return commit == null ? null : AtlasVersionTag(name: name, commit: commit);
  }
}

/// {@category Utils}
///
/// A git tag that an [AtlasVersionTags] put on `origin`.
final class AtlasVersionTag {
  /// The name of the tag.
  final String name;

  /// The commit that the tag names, as a full hash.
  final String commit;

  const AtlasVersionTag({required this.name, required this.commit});
}
