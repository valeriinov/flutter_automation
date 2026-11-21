import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_selection.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_locale_key_coverage.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_page_renderer.dart';
import 'package:flutter_automation_atlas/src/atlas_project.dart';
import 'package:flutter_automation_atlas/src/atlas_published_variants.dart';
import 'package:flutter_automation_atlas/src/atlas_remote_shots.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_id.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_check.dart';

/// {@category Utils}
///
/// How a check of [AtlasChecks] ended.
enum AtlasCheckStatus {
  /// Everything the check compares matches.
  passed('ok'),

  /// The check found something out of step, and the run fails.
  failed('FAIL'),

  /// The check found something out of step. The author decides on it, and
  /// the run still passes.
  warned('WARN'),

  /// The check has something to say that is not a fault.
  reported('note'),

  /// The run did not do the check.
  skipped('skip');

  /// The word the report prints in its first column.
  final String label;

  const AtlasCheckStatus(this.label);
}

/// {@category Utils}
///
/// What one check of [AtlasChecks] found.
final class AtlasCheckOutcome {
  static const _linesIndent = '      ';

  /// How the check ended.
  final AtlasCheckStatus status;

  /// A sentence for a note, a warning or a skipped check; `null` for a pass
  /// or a failure.
  final String? summary;

  /// One line per problem, each naming the path and the command that puts it
  /// back in step.
  final List<String> lines;

  const AtlasCheckOutcome({
    required this.status,
    this.summary,
    this.lines = const [],
  });

  /// A check that found nothing out of step.
  const AtlasCheckOutcome.passed() : this(status: AtlasCheckStatus.passed);

  /// A check that found out-of-step [lines], which fails the run.
  const AtlasCheckOutcome.failed(List<String> lines)
    : this(status: AtlasCheckStatus.failed, lines: lines);

  /// A check that found something out of step, told by [summary] and [lines],
  /// which the run passes with.
  const AtlasCheckOutcome.warned(
    String summary, [
    List<String> lines = const [],
  ]) : this(status: AtlasCheckStatus.warned, summary: summary, lines: lines);

  /// A check with something to say that is not a fault.
  const AtlasCheckOutcome.reported(String summary)
    : this(status: AtlasCheckStatus.reported, summary: summary);

  /// A check left out of this run, because [summary] says so.
  const AtlasCheckOutcome.skipped(String summary)
    : this(status: AtlasCheckStatus.skipped, summary: summary);

  /// Whether this outcome fails the run.
  bool get isFailure => status == AtlasCheckStatus.failed;

  /// The lines a report prints for the check [name], the first naming it.
  List<String> describe(String name) {
    return [
      '${status.label.padRight(5)} $name${_describeHeadline()}',
      for (final line in lines) '$_linesIndent$line',
    ];
  }

  String _describeHeadline() {
    if (summary != null) {
      return ' — $summary';
    }

    if (lines.isEmpty) {
      return '';
    }

    return lines.length == 1 ? ' — 1 problem' : ' — ${lines.length} problems';
  }
}

/// {@category Utils}
///
/// The checks that the stored atlas of a project agrees with the project, for
/// a gate that runs outside `runAtlas`, such as a documentation check. The
/// `check` command of `runAtlas` runs the same six.
///
/// Each check only reads files and does not depend on the others. A check
/// that cannot read its sources ends `failed` with the cause. [snapshots]
/// ends `warned` instead. The lines name the commands of `runAtlas` that put
/// the atlas back in step, such as `render` and `stale`. A project that
/// wraps `runAtlas` in its own command adds that command.
final class AtlasChecks {
  final AtlasLocations _paths;
  final String? _sourceLabel;

  /// The [rootPath] parameter names the repository the checks read. It is the
  /// current directory by default. The [store] parameter replaces the output
  /// folder of the project. The [shotsCache] parameter replaces the cache
  /// folder of the screenshots of a remote storage. The [sourceLabel]
  /// parameter is the label that the page footer shows; it is the
  /// `--source-label` of the `render` command that wrote the page.
  AtlasChecks(
    AtlasProject project, {
    String rootPath = '.',
    String? store,
    String? shotsCache,
    String? sourceLabel,
  }) : _paths = AtlasLocations(
         rootPath,
         project,
         store: store,
         shotsCache: shotsCache,
       ),
       _sourceLabel = sourceLabel;

  /// Holds the committed page against the snapshots, the flow files and the
  /// design screens it comes from.
  ///
  /// The check starts the runner of the project to read the flows, builds the
  /// page, and compares it with the committed page. It does not write the page
  /// or delete a shot, so the captured screenshots stay where they are.
  Future<AtlasCheckOutcome> page() {
    return _guard(_checkPage);
  }

  /// Holds the published variants list against the flow files. A listed
  /// name that no flow file holds fails.
  ///
  /// The check reads no store. It starts the runner of the project to read
  /// the flows.
  Future<AtlasCheckOutcome> publishedVariants() {
    return _guard(() => _PublishedVariantsCheck(_paths).run());
  }

  /// Holds the stored snapshots against the flow files and the published
  /// variants list.
  ///
  /// A snapshot of a variant that its flow file dropped fails. A snapshot
  /// folder of no flow file fails also. A captured variant that the list
  /// leaves out gets a note, not a failure: the list keeps the bundle inside
  /// its size limit.
  ///
  /// The check starts the runner of the project to read the flows.
  Future<AtlasCheckOutcome> storedVariants() {
    return _guard(() => _StoredVariantsCheck(_paths).run());
  }

  /// Holds the stored snapshots of the published variants in the default
  /// locale against the variants they describe, as `stale --published` does.
  ///
  /// A stale variant warns and does not fail. A new capture needs a device,
  /// so a stale variant does not block the change. A stale list that the
  /// check cannot read warns also.
  ///
  /// The check reads the headless reports on disk and walks no variant. It
  /// replays the recorded mock answers of a snapshot under `flutter test`.
  Future<AtlasCheckOutcome> snapshots() {
    return AtlasSnapshotsCheck(_paths).run();
  }

  /// Holds each translation key of the default locale to one of two places.
  /// A frame of a published variant shows the key, or the file that
  /// [AtlasPaths.uncoveredLocaleKeys] names lists it with a reason.
  ///
  /// These cases fail:
  /// - A key that the list leaves out and no published variant shows.
  /// - A line that names a key that a published variant shows after all.
  /// - A line that names a key that the translations do not hold.
  /// - A word that names no reason.
  /// - An `unused` key without its `place` and `widget`.
  ///
  /// A run that found nothing reports how many keys the published variants
  /// show. The run skips the check when the project names no list.
  Future<AtlasCheckOutcome> localeKeyCoverage() {
    return _guard(() => _LocaleKeyCoverageCheck(_paths).run());
  }

  /// Holds the screenshot identifiers of each stored snapshot.
  ///
  /// An identifier that is not an [AtlasShotId] fails, with the
  /// `migrate-shots` command. With a remote shot storage
  /// ([AtlasProject.shotStorage]), an identifier that the storage does not
  /// hold fails also. The check asks the storage with one public `GET` per
  /// identifier.
  Future<AtlasCheckOutcome> shots() {
    return _guard(() => _ShotsCheck(_paths).run());
  }

  Future<AtlasCheckOutcome> _guard(
    FutureOr<AtlasCheckOutcome> Function() check,
  ) async {
    try {
      return await check();
    } on AtlasException catch (error) {
      return AtlasCheckOutcome.failed([error.message]);
    } on AutomationRunnerException catch (error) {
      return AtlasCheckOutcome.failed([error.message]);
    }
  }

  Future<AtlasCheckOutcome> _checkPage() async {
    final path = _paths.pagePath;
    final file = File(path);

    if (!file.existsSync()) {
      return AtlasCheckOutcome.failed(['$path does not exist; run `render`.']);
    }

    final rendering = await AtlasPageRenderer(
      _paths,
      sourceLabel: _sourceLabel,
    ).build();

    final expectedLines = rendering.page.split('\n');
    final foundLines = file.readAsStringSync().split('\n');
    final index = _findFirstDifference(expectedLines, foundLines);

    if (index == null) {
      return const AtlasCheckOutcome.passed();
    }

    final lineNumber = index + 1;

    return AtlasCheckOutcome.failed([
      '$path is out of step with its sources at line $lineNumber; '
          'run `render`.',
      'expected: ${_excerptLine(expectedLines, lineNumber)}',
      'found:    ${_excerptLine(foundLines, lineNumber)}',
    ]);
  }

  static int? _findFirstDifference(List<String> first, List<String> second) {
    final sharedLength = first.length < second.length
        ? first.length
        : second.length;

    for (int index = 0; index < sharedLength; index++) {
      if (first[index] != second[index]) {
        return index;
      }
    }

    return first.length == second.length ? null : sharedLength;
  }

  static String _excerptLine(List<String> lines, int lineNumber) {
    const maxLength = 100;
    const missingLine = '(the file ends here)';
    final line = lines.elementAtOrNull(lineNumber - 1);

    if (line == null) {
      return missingLine;
    }

    return line.length <= maxLength ? line : '${line.substring(0, maxLength)}…';
  }
}

final class _ShotsCheck {
  final AtlasLocations _paths;

  const _ShotsCheck(this._paths);

  Future<AtlasCheckOutcome> run() async {
    final shots = AtlasSnapshotStore(
      _paths,
    ).readEveryLocale().expand((snapshot) => snapshot.shots).toSet();
    final malformed = shots.whereNot(AtlasShotId.isValid).toList();
    final absent =
        await AtlasRemoteShots.tryCreate(
          _paths,
        )?.findAbsent(shots.where(AtlasShotId.isValid)) ??
        const <String>[];
    final problems = [
      for (final shot in malformed)
        'A snapshot names the shot $shot, which is not a SHA-256 '
            'identifier; run `migrate-shots`.',
      for (final shot in absent)
        'The shot storage holds no $shot; capture its variant again or run '
            '`upload-shots`.',
    ];

    return problems.isEmpty
        ? const AtlasCheckOutcome.passed()
        : AtlasCheckOutcome.failed(problems);
  }
}

typedef _ListedVariant = ({String flow, String variant});

typedef _StoredSnapshot = ({String flow, String variant, String path});

final class _VariantSources {
  static const jsonExtension = '.json';

  final AtlasLocations _paths;

  const _VariantSources(this._paths);

  Map<String, Set<String>> readVariantsByFlow() {
    return {
      for (final flow in AtlasDefinitions.read(_paths).flows)
        flow.name: flow.variants.map((variant) => variant.name).toSet(),
    };
  }

  Map<String, List<String>> readPublishedNames() {
    final file = File(_paths.publishedVariantsPath);

    if (!file.existsSync()) {
      throw AtlasException('No published variants list at ${file.path}.');
    }

    final json = AtlasJson.decodeObject(
      file.readAsStringSync(),
      'The published variants list ${file.path}',
    );

    return {
      for (final MapEntry(:key, :value) in json.entries)
        key: _readVariantNames(value),
    };
  }

  bool isDroppedVariant(
    Map<String, Set<String>> variantsByFlow,
    String flow,
    String variant,
  ) {
    final held = variantsByFlow[flow];

    return held != null && !held.contains(variant);
  }

  List<String> _readVariantNames(Object? variantNames) {
    if (variantNames case final List<Object?> names) {
      return names.whereType<String>().toList();
    }

    return const [];
  }
}

final class _PublishedVariantsCheck {
  final AtlasLocations _paths;
  final _VariantSources _sources;

  _PublishedVariantsCheck(this._paths) : _sources = _VariantSources(_paths);

  AtlasCheckOutcome run() {
    final listName = p.basename(_paths.publishedVariantsPath);
    final variantsByFlow = _sources.readVariantsByFlow();
    final published = _sources.readPublishedNames();
    final problems = [
      ..._describeMissingFlows(listName, published, variantsByFlow),
      ..._describeMissingVariants(listName, published, variantsByFlow),
    ];

    return problems.isEmpty
        ? const AtlasCheckOutcome.passed()
        : AtlasCheckOutcome.failed(problems);
  }

  Iterable<String> _describeMissingFlows(
    String listName,
    Map<String, List<String>> published,
    Map<String, Set<String>> variantsByFlow,
  ) {
    return published.keys
        .where((flow) => !variantsByFlow.containsKey(flow))
        .map((flow) => '$listName names flow "$flow", which has no flow file.');
  }

  Iterable<String> _describeMissingVariants(
    String listName,
    Map<String, List<String>> published,
    Map<String, Set<String>> variantsByFlow,
  ) {
    return _readListedVariants(published)
        .where(
          (listed) => _sources.isDroppedVariant(
            variantsByFlow,
            listed.flow,
            listed.variant,
          ),
        )
        .map(
          (listed) =>
              '$listName names "${listed.flow}" "${listed.variant}", '
              'which ${listed.flow}${_VariantSources.jsonExtension} does not '
              'hold.',
        );
  }

  List<_ListedVariant> _readListedVariants(
    Map<String, List<String>> published,
  ) {
    return [
      for (final MapEntry(key: flow, value: variants) in published.entries)
        for (final variant in variants) (flow: flow, variant: variant),
    ];
  }
}

final class _StoredVariantsCheck {
  final AtlasLocations _paths;
  final _VariantSources _sources;

  _StoredVariantsCheck(this._paths) : _sources = _VariantSources(_paths);

  AtlasCheckOutcome run() {
    final variantsByFlow = _sources.readVariantsByFlow();
    final published = _sources.readPublishedNames();
    final directories = _readDataDirectories();
    final snapshots = directories.expand(_readStoredSnapshots).toList();
    final problems = [
      ..._describeStrandedSnapshots(snapshots, variantsByFlow),
      ..._describeStrandedDirectories(directories, variantsByFlow),
    ];

    if (problems.isNotEmpty) {
      return AtlasCheckOutcome.failed(problems);
    }

    return _reportUnpublishedSnapshots(snapshots, published);
  }

  List<Directory> _readDataDirectories() {
    final directory = Directory(_paths.dataPath);

    if (!directory.existsSync()) {
      return const [];
    }

    return directory.listSync().whereType<Directory>().toList()
      ..sort((first, second) => first.path.compareTo(second.path));
  }

  List<_StoredSnapshot> _readStoredSnapshots(Directory directory) {
    final flow = p.basename(directory.path);
    final files =
        directory
            .listSync()
            .whereType<File>()
            .where(
              (file) => p.extension(file.path) == _VariantSources.jsonExtension,
            )
            .toList()
          ..sort((first, second) => first.path.compareTo(second.path));

    return [
      for (final file in files)
        (
          flow: flow,
          variant: _paths.resolveSnapshotVariant(file.path),
          path: file.path,
        ),
    ];
  }

  Iterable<String> _describeStrandedSnapshots(
    List<_StoredSnapshot> snapshots,
    Map<String, Set<String>> variantsByFlow,
  ) {
    return snapshots
        .where(
          (snapshot) => _sources.isDroppedVariant(
            variantsByFlow,
            snapshot.flow,
            snapshot.variant,
          ),
        )
        .map(
          (snapshot) =>
              '${snapshot.path} describes a variant '
              '${snapshot.flow}${_VariantSources.jsonExtension} no longer '
              'holds. Delete it or restore the variant.',
        );
  }

  Iterable<String> _describeStrandedDirectories(
    List<Directory> directories,
    Map<String, Set<String>> variantsByFlow,
  ) {
    return directories
        .where(
          (directory) =>
              !variantsByFlow.containsKey(p.basename(directory.path)),
        )
        .map(
          (directory) =>
              '${directory.path}${p.separator} holds snapshots of no flow '
              'file. Delete the directory.',
        );
  }

  AtlasCheckOutcome _reportUnpublishedSnapshots(
    List<_StoredSnapshot> snapshots,
    Map<String, List<String>> published,
  ) {
    final unpublished = snapshots
        .where(
          (snapshot) =>
              !_isPublished(published, snapshot.flow, snapshot.variant),
        )
        .map((snapshot) => '${snapshot.flow} ${snapshot.variant}')
        .toSet()
        .toList();

    if (unpublished.isEmpty) {
      return const AtlasCheckOutcome.passed();
    }

    return AtlasCheckOutcome.reported(
      '${_describeUnpublishedCount(unpublished.length)}: '
      '${unpublished.join(', ')}',
    );
  }

  bool _isPublished(
    Map<String, List<String>> published,
    String flow,
    String variant,
  ) {
    return published[flow]?.contains(variant) ?? false;
  }

  String _describeUnpublishedCount(int count) {
    if (count == 1) {
      return '1 variant has a snapshot and is not published';
    }

    return '$count variants have a snapshot and are not published';
  }
}

/// The check behind [AtlasChecks.snapshots], with the staleness reader a test
/// replaces.
final class AtlasSnapshotsCheck {
  static const _shownLinesLimit = 10;
  static const _shownFlowsLimit = 3;
  static const _preciseListHint =
      'the precise list: `stale --published`, '
      'the captures: `capture --stale --published`';

  final AtlasLocations _paths;
  final AtlasStalenessReader? _readStalenesses;

  /// The [readStalenesses] parameter tells the staleness of each of the
  /// variants in their order. It is [AtlasStaleCheck] in the default locale
  /// by default.
  const AtlasSnapshotsCheck(
    this._paths, {
    AtlasStalenessReader? readStalenesses,
  }) : _readStalenesses = readStalenesses;

  Future<AtlasCheckOutcome> run() async {
    try {
      final definitions = AtlasDefinitions.read(_paths);

      final stalenesses = await _resolveReader()(
        AtlasPublishedVariants.read(
          _paths,
          definitions,
        ).filter(definitions.variants),
      );

      return _describeStalenesses(
        stalenesses,
        AtlasHeadlessSelection(_paths, _paths.defaultLocale),
      );
    } on AutomationRunnerException catch (error) {
      return _describeUnreadStalenesses(error.message);
    } on AtlasException catch (error) {
      return _describeUnreadStalenesses(error.message);
    } on Exception catch (error) {
      return _describeUnreadStalenesses('$error');
    }
  }

  AtlasStalenessReader _resolveReader() {
    return _readStalenesses ??
        AtlasStaleCheck(_paths, _paths.defaultLocale).check;
  }

  AtlasCheckOutcome _describeStalenesses(
    List<AtlasStaleness> stalenesses,
    AtlasHeadlessSelection selection,
  ) {
    final staleVariants = stalenesses
        .where((staleness) => staleness.isStale)
        .toList();

    if (staleVariants.isEmpty) {
      return const AtlasCheckOutcome.passed();
    }

    final uncomparedIds = {
      for (final staleness in staleVariants)
        if (selection.isUncompared(staleness)) staleness.variant.id,
    };
    final changedCount = staleVariants.length - uncomparedIds.length;

    return AtlasCheckOutcome.warned(
      '${_describeCounts(changedCount, uncomparedIds.length)}, '
      'most in ${_describeTopFlows(staleVariants)}; $_preciseListHint',
      _limitLines(
        staleVariants
            .map(
              (staleness) => _describeLine(
                staleness,
                isUncompared: uncomparedIds.contains(staleness.variant.id),
              ),
            )
            .toList(),
      ),
    );
  }

  AtlasCheckOutcome _describeUnreadStalenesses(String message) {
    return AtlasCheckOutcome.warned(
      'the stale variants could not be read; $_preciseListHint',
      _limitLines(message.trim().split('\n')),
    );
  }

  String _describeCounts(int changedCount, int uncomparedCount) {
    return [
      if (changedCount > 0) _describeStaleCount(changedCount),
      if (uncomparedCount > 0) _describeUncomparedCount(uncomparedCount),
    ].join(', ');
  }

  String _describeTopFlows(List<AtlasStaleness> staleVariants) {
    final countsByFlow = staleVariants
        .groupListsBy((staleness) => staleness.variant.flow)
        .map((flow, variants) => MapEntry(flow, variants.length));
    final flows = countsByFlow.keys.sorted(
      (first, second) => _compareFlows(countsByFlow, first, second),
    );

    return flows
        .take(_shownFlowsLimit)
        .map((flow) => '$flow (${countsByFlow[flow]})')
        .join(', ');
  }

  String _describeLine(AtlasStaleness staleness, {required bool isUncompared}) {
    final line = '${staleness.variant.id} ${staleness.reason.label}';

    return isUncompared ? '$line, frames unchecked' : line;
  }

  List<String> _limitLines(List<String> lines) {
    if (lines.length <= _shownLinesLimit) {
      return lines;
    }

    return [
      ...lines.take(_shownLinesLimit),
      'and ${lines.length - _shownLinesLimit} more',
    ];
  }

  String _describeStaleCount(int count) {
    if (count == 1) {
      return '1 variant is stale';
    }

    return '$count variants are stale';
  }

  String _describeUncomparedCount(int count) {
    if (count == 1) {
      return '1 variant changed in code with its frames unchecked';
    }

    return '$count variants changed in code with their frames unchecked';
  }

  int _compareFlows(
    Map<String, int> countsByFlow,
    String first,
    String second,
  ) {
    final byCount = (countsByFlow[second] ?? 0).compareTo(
      countsByFlow[first] ?? 0,
    );

    return byCount == 0 ? first.compareTo(second) : byCount;
  }
}

final class _LocaleKeyCoverageCheck {
  final AtlasLocations _paths;

  const _LocaleKeyCoverageCheck(this._paths);

  AtlasCheckOutcome run() {
    final report = AtlasLocaleKeyCoverageReport(_paths);
    final listPath = report.listPath;

    if (listPath == null) {
      return const AtlasCheckOutcome.skipped(
        'AtlasPaths.uncoveredLocaleKeys names no list',
      );
    }

    final coverage = report.reconcile();
    final problems = [
      ..._describeUndeclaredKeys(coverage, listPath),
      ..._describeFramedDeclarations(coverage),
      ..._describeStrandedDeclarations(coverage, listPath),
      ..._describeUnknownReasons(coverage),
      ..._describeUnplacedDeclarations(coverage),
    ];

    if (problems.isNotEmpty) {
      return AtlasCheckOutcome.failed(problems);
    }

    return AtlasCheckOutcome.reported(_describeCounts(coverage));
  }

  String get _reasonChoice {
    final names = AtlasLocaleKeyReason.values
        .map((reason) => reason.name)
        .toList();
    final lastIndex = names.length - 1;

    return '${names.take(lastIndex).join(', ')} or ${names[lastIndex]}';
  }

  Iterable<String> _describeUndeclaredKeys(
    AtlasLocaleKeyCoverage coverage,
    String listPath,
  ) {
    return coverage.undeclaredKeys.map(
      (key) =>
          '$key is shown by no published variant and not listed in '
          '$listPath. Add it with a reason — $_reasonChoice — or '
          'capture a frame showing it.',
    );
  }

  Iterable<String> _describeFramedDeclarations(
    AtlasLocaleKeyCoverage coverage,
  ) {
    return coverage.framedDeclarations.map(
      (declaration) =>
          '${declaration.key} is listed as ${declaration.reason} but a '
          'published variant shows it. Drop the line.',
    );
  }

  Iterable<String> _describeStrandedDeclarations(
    AtlasLocaleKeyCoverage coverage,
    String listPath,
  ) {
    final listName = p.basename(listPath);

    return coverage.strandedDeclarations.map(
      (key) =>
          '$key is listed in $listName and is not a key of the translations. '
          'Drop the line or restore the key.',
    );
  }

  Iterable<String> _describeUnknownReasons(AtlasLocaleKeyCoverage coverage) {
    return coverage.unknownReasons.map(
      (declaration) =>
          '${declaration.key} is listed with reason '
          '"${declaration.reason}". '
          'A reason is one of ${AtlasLocaleKeyReason.names}.',
    );
  }

  Iterable<String> _describeUnplacedDeclarations(
    AtlasLocaleKeyCoverage coverage,
  ) {
    return coverage.unplacedDeclarations.map(
      (key) =>
          '$key is listed as unused without the place and the widget that '
          'would show it. Write the line as {"reason": "unused", "place": '
          '"...", "widget": "..."}.',
    );
  }

  String _describeCounts(AtlasLocaleKeyCoverage coverage) {
    final declarations = AtlasLocaleKeyReason.values.map(
      (reason) => '${reason.name} ${coverage.countDeclarations(reason)}',
    );

    return '${coverage.keysOnFrames.length} of ${coverage.keys.length} '
        'keys on frames, ${coverage.reasonsByKey.length} declared '
        '(${declarations.join(', ')})';
  }
}
