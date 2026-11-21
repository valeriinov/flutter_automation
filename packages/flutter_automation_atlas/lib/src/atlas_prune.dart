import 'dart:io';
import 'dart:math';

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_remote_shots.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_id.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_references.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_storage.dart';
import 'package:flutter_automation_atlas/src/atlas_site_repository.dart';
import 'package:flutter_automation_atlas/src/atlas_versions.dart';

/// {@category Utils}
///
/// The part of the atlas that a prune cleans.
enum AtlasPruneScope {
  /// The repository of the store folder and the shot storage.
  all,

  /// The repository of the store folder only.
  repository,

  /// The shot storage only.
  storage;

  /// Whether the scope covers the repository.
  bool get hasRepository => this != storage;

  /// Whether the scope covers the shot storage.
  bool get hasStorage => this != repository;
}

/// {@category Utils}
///
/// Finds what the repository of the store folder and the shot storage hold
/// past their use. It deletes that when the caller applies the prune.
///
/// A prune first runs `git fetch --prune --no-tags origin` in the
/// repository. It then fetches the refspec
/// `+refs/heads/*:refs/remotes/origin/*`, which takes each branch of
/// `origin`, whatever the refspec of the clone is. A failed fetch stops the
/// prune. So does a repository without the branch
/// `origin/main`. The prune reads everything before it deletes anything.
///
/// The repository part works on each site folder. The `atlas-config.json`
/// of a site folder gives the retention in two fields:
///
/// - `keptVersions`, the count of the latest versions by position that
///   stay ([AtlasVersions.readKeptVersions]). Without the field, each
///   version stays.
/// - `versionTagTemplate`, the name of the git tag of a version, with
///   `{version}` in place of the label ([AtlasVersions.resolveVersionTag]).
///   Without the field, the prune leaves the tags.
///
/// The part deletes, in the working tree, the folder and the `versions.json`
/// row of each version past the retention.
///
/// The part deletes the tag of a version on `origin` and in the repository.
/// The tag goes on two conditions:
///
/// - The branch `origin/main` held the folder of the version once, in a site
///   folder of the prune whose `versionTagTemplate` gives the tag.
/// - No site folder of the prune holds a folder of that label, on the branch
///   or in the working tree.
///
/// A tag that only the repository holds goes without a push. A tag of a
/// label that never had a folder stays. The tags go before the folders.
///
/// The storage part reads the needed set of [AtlasShotReferences] and the
/// files of [AtlasShotStorage.list]. It deletes each file that the set does
/// not name and that the storage took more than 7 days ago. A project
/// without a shot storage has no storage part.
final class AtlasPrune {
  static const _storageGracePeriod = Duration(days: 7);
  static const _ExpiredTags _noExpiredTags = (all: [], local: [], origin: []);

  final AtlasLocations _paths;
  final List<String> _sites;
  final DateTime Function() _clock;

  /// The [sites] parameter names the site folders. When it is empty, the
  /// prune takes each folder `site/<name>/` of the repository that holds an
  /// `atlas-config.json`. The [clock] parameter gives the time that the age
  /// of a stored file counts from. It is [DateTime.now] by default.
  AtlasPrune(
    this._paths, {
    List<String> sites = const [],
    DateTime Function()? clock,
  }) : _sites = sites,
       _clock = clock ?? DateTime.now;

  /// Reports what the [scope] holds past its use. It deletes that when
  /// [isApplied] is `true`.
  ///
  /// Throws an [AtlasException] in these cases:
  /// - The store folder is outside a git repository, or the fetch fails.
  /// - The repository holds no branch `origin/main`.
  /// - A site folder is missing or outside the repository.
  /// - The retention of a site folder is malformed.
  /// - The storage part runs and no file of the repository names a
  ///   screenshot.
  /// - The shot storage does not list or delete its files.
  Future<AtlasPruneReport> run({
    AtlasPruneScope scope = AtlasPruneScope.all,
    bool isApplied = false,
  }) async {
    final repository = AtlasSiteRepository.fetch(_paths, reader: 'the prune');
    final sites = repository.resolveSites(_sites);
    final expiredSites = scope.hasRepository
        ? [for (final site in sites) _findExpired(site)]
        : const <_ExpiredSite>[];
    final expiredTags = scope.hasRepository
        ? _findExpiredTags(repository, sites)
        : _noExpiredTags;
    final remoteShots = scope.hasStorage
        ? AtlasRemoteShots.tryCreate(_paths)
        : null;
    final strandedShots = remoteShots == null
        ? const <String>[]
        : await _findStrandedShots(remoteShots);

    if (isApplied) {
      _deleteExpired(repository, expiredSites, expiredTags);

      await remoteShots?.delete(strandedShots);
    }

    return AtlasPruneReport(
      versionFolders: [
        for (final site in expiredSites)
          for (final label in site.labels)
            site.versions.resolveVersionPath(label),
      ],
      tags: expiredTags.all,
      shots: strandedShots,
      isStorageSkipped: scope.hasStorage && remoteShots == null,
      isApplied: isApplied,
    );
  }

  _ExpiredSite _findExpired(AtlasVersions site) {
    final versions = site.read();
    final keptVersions = site.readKeptVersions() ?? versions.length;

    return (
      versions: site,
      labels: [
        for (final version in versions.take(
          max(0, versions.length - keptVersions),
        ))
          version.label,
      ],
    );
  }

  _ExpiredTags _findExpiredTags(
    AtlasSiteRepository repository,
    List<AtlasVersions> sites,
  ) {
    final taggedSites = [
      for (final site in sites)
        if (site.tryReadVersionTagTemplate() case final template?)
          (site: site, template: template),
    ];

    if (taggedSites.isEmpty) {
      return _noExpiredTags;
    }

    final localTags = repository.readLines(['tag', '--list']).toSet();
    final originTags = repository.readOriginTags();
    final holders = _readHolders(repository, sites);
    final expired = {
      ...localTags,
      ...originTags,
    }.where((tag) => _isExpiredTag(tag, taggedSites, holders)).toList()..sort();

    return (
      all: expired,
      local: expired.where(localTags.contains).toList(),
      origin: expired.where(originTags.contains).toList(),
    );
  }

  List<AtlasVersions> _readHolders(
    AtlasSiteRepository repository,
    List<AtlasVersions> sites,
  ) {
    final holders = {
      for (final site in [...sites, ...repository.resolveSites(const [])])
        site.sitePath: site,
    };

    return holders.values.toList();
  }

  bool _isExpiredTag(
    String tag,
    List<_TaggedSite> taggedSites,
    List<AtlasVersions> sites,
  ) {
    final versions = [
      for (final tagged in taggedSites)
        if (tagged.template.tryResolveLabel(tag) case final label?)
          (site: tagged.site, label: label),
    ];

    return versions.any(_wasPublished) &&
        !versions.any((version) => _isLabelHeld(sites, version.label));
  }

  bool _wasPublished(_SiteVersion version) {
    return version.site.wasOnMainBranch(version.label);
  }

  bool _isLabelHeld(List<AtlasVersions> sites, String label) {
    return sites.any((site) => _isVersionHeld(site, label));
  }

  bool _isVersionHeld(AtlasVersions site, String label) {
    return Directory(site.resolveVersionPath(label)).existsSync() ||
        site.isOnMainBranch(label);
  }

  Future<List<String>> _findStrandedShots(AtlasRemoteShots remoteShots) async {
    final needed = await AtlasShotReferences(_paths.storePath).read();
    final stored = await remoteShots.list();

    final newestStranded = _clock().subtract(_storageGracePeriod);

    return [
      for (final file in stored)
        if (_isStranded(file, needed, newestStranded)) file.shot,
    ];
  }

  bool _isStranded(
    AtlasStoredShot file,
    Set<String> needed,
    DateTime newestStranded,
  ) {
    return AtlasShotId.isValid(file.shot) &&
        !needed.contains(file.shot) &&
        file.uploadedAt.isBefore(newestStranded);
  }

  void _deleteExpired(
    AtlasSiteRepository repository,
    List<_ExpiredSite> sites,
    _ExpiredTags tags,
  ) {
    if (tags.origin.isNotEmpty) {
      repository.runGit([
        'push',
        AtlasSiteRepository.remote,
        '--delete',
        for (final tag in tags.origin)
          '${AtlasSiteRepository.tagRefPrefix}$tag',
      ]);
    }

    if (tags.local.isNotEmpty) {
      repository.runGit(['tag', '--delete', ...tags.local]);
    }

    for (final site in sites) {
      site.versions.remove(site.labels);
    }
  }
}

typedef _ExpiredSite = ({AtlasVersions versions, List<String> labels});

typedef _ExpiredTags = ({
  List<String> all,
  List<String> local,
  List<String> origin,
});

typedef _TaggedSite = ({AtlasVersions site, AtlasVersionTagTemplate template});

typedef _SiteVersion = ({AtlasVersions site, String label});

/// {@category Utils}
///
/// What an [AtlasPrune] found past its use, and whether it deleted that.
final class AtlasPruneReport {
  /// The folders of the versions past the retention of their site folder.
  final List<String> versionFolders;

  /// The git tags of the versions whose folder no site folder of the prune
  /// holds.
  final List<String> tags;

  /// The identifiers of the stored screenshots that no file of the
  /// repository names.
  final List<String> shots;

  /// Whether the prune left the storage part out because the project has no
  /// shot storage.
  final bool isStorageSkipped;

  /// Whether the prune deleted what it found.
  final bool isApplied;

  const AtlasPruneReport({
    required this.versionFolders,
    required this.tags,
    required this.shots,
    required this.isStorageSkipped,
    required this.isApplied,
  });

  /// The lines that tell a reader of each found item, and a last line with
  /// the counts.
  List<String> describe() {
    final verb = isApplied ? 'Deleted' : 'To delete:';

    return [
      for (final folder in versionFolders) '$verb version folder $folder',
      for (final tag in tags) '$verb tag $tag',
      for (final shot in shots) '$verb stored shot $shot',
      if (isStorageSkipped)
        'The project has no shot storage; the storage part is skipped',
      '${isApplied ? 'Deleted' : 'Found'} ${versionFolders.length} version '
          'folders, ${tags.length} tags, ${shots.length} stored shots'
          '${isApplied ? '' : '; --apply deletes them'}',
    ];
  }
}
