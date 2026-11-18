import 'dart:io';

import 'package:flutter_automation_runner/flutter_automation_runner.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_settings.dart';

/// {@category Utils}
///
/// The app source files one stage of a flow variant can be shaped by: the file
/// of the screen the stage shows and every `lib/` file it reaches through its
/// `import`, `export` and `part` directives.
///
/// The walk stops at the files of [AtlasStaleSettings.stopPaths], which import
/// nearly every screen and service, and at generated files, each following
/// what it is generated from.
///
/// The sources place a changed file on a stage only when the widgets visible
/// on the stage cannot: the stage recorded none, or the file holds a changed
/// declaration none of them reaches (`AtlasStaleCheck`).
final class AtlasStageSources {
  static final _directivePattern = RegExp(
    r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  final AtlasLocations _locations;
  final String _appPackagePrefix;
  final AtlasStaleSettings _settings;

  /// Resolves screens to sources under the root of [AtlasLocations].
  ///
  /// The `appPackagePrefix` parameter is the `package:` prefix of the app
  /// libraries.
  AtlasStageSources(this._locations, this._appPackagePrefix)
    : _settings = _locations.project.staleSettings;

  /// Repository-relative `lib/...` paths the file of [screen] imports
  /// transitively, itself included, intersected with [manifestPaths], sorted.
  ///
  /// The [screen] parameter is the kebab form of a route class
  /// (`items-route` for `ItemsRoute`). Empty when it matches no route, or when
  /// [AtlasStaleSettings.routes] is absent.
  ///
  /// Throws [AtlasException] when the generated routes file is missing.
  List<String> resolve({
    required String screen,
    required Iterable<String> manifestPaths,
  }) {
    final routes = _settings.routes;

    if (routes == null) {
      return const [];
    }

    final screenPath = _findScreenPath(routes, screen);

    if (screenPath == null) {
      return const [];
    }

    final executedPaths = manifestPaths.toSet();
    final reachedPaths = _collectReachedPaths(screenPath);

    return reachedPaths.where(executedPaths.contains).toList()..sort();
  }

  String? _findScreenPath(AtlasRouteSettings routes, String screen) {
    final screenClass = _readScreenClassesByRoute(
      routes,
    )[_toRouteClass(screen)];

    if (screenClass == null) {
      return null;
    }

    final declaration = RegExp('^class $screenClass\\b', multiLine: true);

    for (final path in _readDirectivePaths(routes.routerPath)) {
      final source = _tryReadSource(path);

      if (source != null && declaration.hasMatch(source)) {
        return path;
      }
    }

    return null;
  }

  Set<String> _collectReachedPaths(String screenPath) {
    final reachedPaths = {screenPath};
    final pendingPaths = [screenPath];

    while (pendingPaths.isNotEmpty) {
      final path = pendingPaths.removeLast();
      final nextPaths = _readDirectivePaths(path)
          .where((next) => _isFollowed(next) && !reachedPaths.contains(next))
          .toSet();

      reachedPaths.addAll(nextPaths);
      pendingPaths.addAll(nextPaths);
    }

    return reachedPaths;
  }

  Map<String, String> _readScreenClassesByRoute(AtlasRouteSettings routes) {
    final file = File(_locations.resolve(routes.routesPath));

    if (!file.existsSync()) {
      throw AtlasException('No generated routes file at ${routes.routesPath}.');
    }

    final routePattern = RegExp(routes.routePattern, multiLine: true);

    return {
      for (final match in routePattern.allMatches(file.readAsStringSync()))
        match.group(2) ?? '': match.group(1) ?? '',
    };
  }

  String _toRouteClass(String screen) {
    return screen
        .split('-')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join();
  }

  List<String> _readDirectivePaths(String path) {
    final source = _tryReadSource(path);

    if (source == null) {
      return const [];
    }

    return _directivePattern
        .allMatches(source)
        .map((match) => _tryResolveUri(path, match.group(1) ?? ''))
        .nonNulls
        .toList();
  }

  bool _isFollowed(String path) {
    if (_settings.stopPaths.contains(path)) {
      return false;
    }

    return !AutomationCoverageManifest.generatedSuffixes.any(path.endsWith);
  }

  String? _tryReadSource(String path) {
    final file = File(_locations.resolve(path));

    return file.existsSync() ? file.readAsStringSync() : null;
  }

  String? _tryResolveUri(String fromPath, String uri) {
    if (uri.startsWith(_appPackagePrefix)) {
      return p.posix.join(
        AutomationCoverageManifest.appSourceDirectory,
        uri.substring(_appPackagePrefix.length),
      );
    }

    if (uri.contains(':')) {
      return null;
    }

    final path = p.posix.normalize(
      p.posix.join(p.posix.dirname(fromPath), uri),
    );

    return path.startsWith(AutomationCoverageManifest.appSourceDirectory)
        ? path
        : null;
  }
}
