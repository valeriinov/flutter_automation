import 'package:collection/collection.dart';

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_stages.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_store_reader.dart';
import 'package:flutter_automation_atlas/src/atlas_table.dart';

typedef _Request = ({String method, String path});

/// {@category Utils}
///
/// One request the code of a project declares, for [AtlasRequestsTable].
final class AtlasDeclaredRequest {
  /// The HTTP method the code calls the [path] with, `null` for a path that
  /// no code calls.
  final String? method;

  /// The path the project declares.
  final String path;

  /// The names the project gives the declaration of [path], in its order.
  final List<String> names;

  /// Where the code uses the request, as `<path>:<line>` relative to the root
  /// of the project.
  final List<String> usages;

  const AtlasDeclaredRequest({
    required this.method,
    required this.path,
    required this.names,
    required this.usages,
  });
}

/// {@category Utils}
///
/// Builds the [AtlasTable] of the requests a project declares and the
/// published variants log.
///
/// The table holds one row per declared request in the order of `declared`.
/// Then it holds one row per logged request that no declared path matches, in
/// the order of the records. A row holds the `method`, the `path`, the
/// `endpoints` (the names of the declaration), the `usages`, the `stages`
/// that log the request and its `status`:
///
/// - `onFrames`: a published variant logs the request;
/// - `pending`: the code calls the request and no published variant logs it;
/// - `codeOnly`: the project declares the path and no code calls it;
/// - `mockIssued`: a published variant logs a path the project does not
///   declare.
///
/// A logged path matches a declared path when it is equal to it, else when it
/// continues the longest declared path by whole segments. A logged path that
/// matches none shows its numeric and UUID segments as `{id}`.
abstract final class AtlasRequestsTable {
  static const _pathIdPlaceholder = '{id}';
  static final _pathIdPattern = RegExp(
    r'^(\d+|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12})$',
  );

  /// Builds the table [id] named [title] by locale from the records of
  /// [journalKind] that [store] holds and the [declared] requests.
  ///
  /// Throws an [AtlasException] when a published variant logs a method on a
  /// declared path that no declaration calls with that method.
  static AtlasTable build({
    required String id,
    required Map<String, String> title,
    required String journalKind,
    required AtlasStoreReader store,
    required List<AtlasDeclaredRequest> declared,
  }) {
    final declaredPaths = declared.map((request) => request.path).toSet();
    final stagesByRequest = _readStagesByRequest(
      store.recordsOf(journalKind),
      declaredPaths.sorted((first, second) => second.length - first.length),
    );

    _ensureLoggedRequestsDeclared(
      stagesByRequest.keys,
      declared,
      declaredPaths,
    );

    return AtlasTable(
      id: id,
      title: title,
      columns: const [
        AtlasTableColumn(key: 'method', title: {'en': 'Method', 'uk': 'Метод'}),
        AtlasTableColumn(key: 'path', title: {'en': 'Path', 'uk': 'Шлях'}),
        AtlasTableColumn(
          key: 'endpoints',
          title: {'en': 'Endpoints', 'uk': 'Ендпоінти'},
        ),
      ],
      rows: [
        for (final request in declared)
          _buildDeclaredRow(request, stagesByRequest),
        for (final MapEntry(key: (:method, :path), value: stages)
            in stagesByRequest.entries)
          if (!declaredPaths.contains(path))
            _buildRow(
              method: method,
              path: path,
              status: 'mockIssued',
              names: const [],
              usages: const [],
              stages: stages,
            ),
      ],
      journalKind: journalKind,
    );
  }

  static Map<_Request, List<AtlasJournalStage>> _readStagesByRequest(
    List<AtlasJournalRecord> records,
    List<String> longestFirstPaths,
  ) {
    return records
        .groupListsBy(
          (entry) => (
            method: AtlasJson.readString(entry.record, 'method'),
            path: _resolvePath(
              AtlasJson.readString(entry.record, 'path'),
              longestFirstPaths,
            ),
          ),
        )
        .map(
          (request, entries) => MapEntry(
            request,
            entries.map((entry) => entry.stage).toSet().toList(),
          ),
        );
  }

  static void _ensureLoggedRequestsDeclared(
    Iterable<_Request> loggedRequests,
    List<AtlasDeclaredRequest> declared,
    Set<String> declaredPaths,
  ) {
    final calledRequests = {
      for (final request in declared)
        if (request.method case final method?)
          (method: method, path: request.path),
    };

    for (final request in loggedRequests) {
      if (declaredPaths.contains(request.path) &&
          !calledRequests.contains(request)) {
        throw AtlasException(
          'The snapshots log ${request.method} ${request.path}, which no '
          'declaration calls with that method.',
        );
      }
    }
  }

  static Map<String, Object?> _buildDeclaredRow(
    AtlasDeclaredRequest request,
    Map<_Request, List<AtlasJournalStage>> stagesByRequest,
  ) {
    final method = request.method;
    final stages = method == null
        ? const <AtlasJournalStage>[]
        : stagesByRequest[(method: method, path: request.path)] ?? const [];

    return _buildRow(
      method: method,
      path: request.path,
      status: _resolveStatus(method, stages),
      names: request.names,
      usages: request.usages,
      stages: stages,
    );
  }

  static String _resolveStatus(String? method, List<AtlasJournalStage> stages) {
    if (method == null) {
      return 'codeOnly';
    }

    return stages.isEmpty ? 'pending' : 'onFrames';
  }

  static Map<String, Object?> _buildRow({
    required String? method,
    required String path,
    required String status,
    required List<String> names,
    required List<String> usages,
    required List<AtlasJournalStage> stages,
  }) {
    return {
      'method': ?method,
      'path': path,
      'status': status,
      'endpoints': names,
      'usages': usages,
      ...AtlasTable.stagesData(stages),
    };
  }

  static String _resolvePath(String path, List<String> longestFirstPaths) {
    if (longestFirstPaths.contains(path)) {
      return path;
    }

    final declaredPath = longestFirstPaths.firstWhereOrNull(
      (declaredPath) => path.startsWith('$declaredPath/'),
    );

    return declaredPath ?? _replacePathIds(path);
  }

  static String _replacePathIds(String path) {
    return path
        .split('/')
        .map(
          (segment) =>
              _pathIdPattern.hasMatch(segment) ? _pathIdPlaceholder : segment,
        )
        .join('/');
  }
}
