import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_source_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_settings.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_upload.dart';

typedef _ReportCompletion = ({
  AtlasHeadlessUncomparableFrames uncomparableFrames,
  Map<String, String?>? sourceHashes,
  String? commit,
});

typedef _RecordedSource = ({String path, String hash});

typedef _BaselineCommits = ({
  Map<String, String> commits,
  Set<String> failedCommits,
});

/// {@category Utils}
///
/// Walks variants in the app under `flutter test`, on the in-app mock and
/// without a device, and has each write to its headless report, for every
/// stage and for the end, the hash of the frame before the user action and the
/// journal records the app wrote up to it, and the PNG of every frame beside
/// the report, named by the stage index or `end`. `stale` compares the
/// current report with the hashes the walk of a capture wrote into the
/// snapshot ([AtlasStage.headlessFrameHash]), or with the baseline report
/// where the snapshot holds none, and walks the current one itself for a
/// variant a change of code alone stales.
///
/// A walk applies the locale and reads the journal the way a capture does:
/// the locale once the app is past its splash, the records after every step,
/// and the records up to a frame right after it; the records before the first
/// frame belong to no stage.
///
/// The current walk runs on the working tree and its report holds the hash of
/// every manifest file of the snapshot as the walk found it. The baseline walk
/// runs each variant on the commit its stored shots were taken on, or, when
/// that commit holds a stage source otherwise than the snapshot recorded, on
/// its newest first-parent ancestor holding every one as recorded
/// ([tryReadSnapshotCommit]): a detached worktree of that commit, under
/// `build/`, takes the current walk files and is removed afterwards, and its
/// report names the commit. A stage whose sources that commit holds otherwise
/// than the snapshot recorded has no frame hash. Both walks take the steps of
/// the current flow files and run once on the moments of each group of stored
/// stages captured on the same moments, every stage taken from the walk on its
/// own moments; a snapshot without stages is walked on [stagelessMoments]. A
/// walk compresses the uploaded images as the snapshot recorded
/// ([AtlasHeadlessUploads]).
final class AtlasHeadless {
  /// The define naming the file the inputs are read from.
  static const inputDefine = 'ATLAS_HEADLESS_INPUT';

  /// The anchor and the launch moment, as UTC ISO 8601 moments, both walks
  /// of a snapshot without stages run on: it holds none of its capture.
  static const stagelessMoments = (
    anchor: '2026-10-06T09:00:00.000Z',
    launchedAt: '2026-10-06T12:00:00.000Z',
  );

  /// The file name of the frame of the end beside the stage frames.
  static const endFrameName = 'end';

  static const _directoryPrefix = 'atlas-headless-';
  static const _inputFileName = 'input.json';
  static const _timeout = '30m';
  static const _noReport = 'no report';
  static const AtlasHeadlessUncomparableFrames _comparableFrames = (
    stages: {},
    isEndUncomparable: false,
  );
  static const _noCommit = 'no committed snapshot';
  static const _noBaseline = 'no baseline on';
  static const _sourcesCommitLimit = 50;
  static const _headRevision = 'HEAD';
  static const _newline = 0x0A;
  static const _treeCommits = (
    commits: <String, String>{},
    failedCommits: <String>{},
  );
  static const _journalKey = 'journal';
  static const _headlessKeyPrefix = 'headless';
  static const _endKey = 'end';
  static const _stagesKey = 'stages';
  static const _jsonExtension = '.json';
  static const _pngExtension = '.png';
  static const _fvmConfigPath = '.fvmrc';
  static const _versionFlag = '--version';
  static const _machineFlag = '--machine';
  static const _frameworkVersionKey = 'frameworkVersion';
  static const _pubspecPath = 'pubspec.yaml';
  static final _assetEntry = RegExp(r'^\s+-\s+(\S+)\s*$', multiLine: true);
  static const _entryPath = 'headless_entry/atlas_headless_entry_test.dart';

  final AtlasLocations _paths;
  final bool _isBaseline;

  /// Walks on the working tree.
  AtlasHeadless(this._paths) : _isBaseline = false;

  /// Walks on the commit the shots of each stored snapshot were taken on.
  AtlasHeadless.baseline(this._paths) : _isBaseline = true;

  AtlasHeadlessSettings get _settings => _paths.project.headlessSettings;

  /// The renderer a walk on the tree under [paths] draws its frames with: the
  /// Flutter version `flutter --version --machine` reports, run with
  /// [AtlasLaunchSettings.commandPrefix] in the root of the project, then the
  /// operating system and the architecture this process runs on, as
  /// `Flutter 3.47.5 · macos_arm64`.
  static String readRenderer(AtlasLocations paths) {
    final flutter = paths.project.launch.resolveCommand('flutter');
    final report = AtlasJson.readObject(
      jsonDecode(
        _runProcess(flutter.executable, [
          ...flutter.arguments,
          _versionFlag,
          _machineFlag,
        ], paths.rootPath),
      ),
      _versionFlag,
    );

    return 'Flutter ${AtlasJson.readString(report, _frameworkVersionKey)} · '
        '${Abi.current()}';
  }

  /// The commit whose capture the shots of the snapshot file at
  /// [snapshotPath] under [paths] come from; absent when none is known or git
  /// cannot tell.
  ///
  /// A snapshot that records the commit of a clean code tree
  /// ([AtlasSnapshot.sourceCommit], [AtlasSnapshot.sourceDirty]) names that
  /// commit while it is an ancestor of `HEAD`. When it is not, as after a
  /// rebase, the commit is the newest first-parent ancestor of `HEAD`, 50
  /// commits at most, that holds every source of every stage as recorded;
  /// absent when none does.
  ///
  /// Any other snapshot comes from the commits that last wrote the file: the
  /// oldest whose version differs from the file only in the journals of its
  /// stages and the hashes and renderer of a headless walk, which a journal
  /// refresh and a headless walk rewrite without a shot. When that commit
  /// holds a source of a stage otherwise than the snapshot recorded, as after
  /// a rebase that put commits changing it below the capture, the commit is
  /// the newest of it and its first-parent ancestors, 50 commits at most, that
  /// holds every source of every stage as recorded, and stays that commit
  /// when none does.
  static String? tryReadSnapshotCommit(
    AtlasLocations paths,
    String snapshotPath,
  ) {
    final file = File(snapshotPath);

    if (!file.existsSync()) {
      return null;
    }

    try {
      final source = file.readAsStringSync();
      final snapshot = AtlasSnapshot.fromJson(
        jsonDecode(source),
        fileLocale: paths.resolveSnapshotLocale(snapshotPath),
      );
      final sourceCommit = snapshot.sourceCommit;

      if (sourceCommit != null && snapshot.sourceDirty == false) {
        return _tryReadCleanSourceCommit(paths, snapshot, sourceCommit);
      }

      return _tryReadCommittedSnapshotCommit(paths, snapshotPath, source);
    } on AtlasException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Walks [variants] in the default locale and prints one line per variant:
  /// the stages its report holds, and the step that failed when one did.
  /// Answers whether every variant the walk takes wrote its report.
  ///
  /// A walk that stopped on a step names it in its report; a test
  /// `flutter test` failed after its report was written, such as one leaving
  /// a timer the app leaves pending, fails no walk. The baseline walk leaves
  /// out a variant whose snapshot is not committed as it stands, and the
  /// variants of a commit whose worktree cannot run the walk; their lines say
  /// so, and neither makes the answer false.
  Future<bool> run(List<AtlasVariantDefinition> variants) async {
    if (variants.isEmpty) {
      return true;
    }

    final inputs = readInputs(variants);
    final snapshots = _readSnapshots(inputs);

    for (final input in inputs) {
      _deleteReport(input);
    }

    final commits = _isBaseline
        ? await _runAtCommits(inputs, snapshots)
        : await _runOnTree(inputs, snapshots);
    final outcomes = [
      for (final input in inputs)
        if (input.momentsIndex == 0) _describeOutcome(input, commits),
    ];

    outcomes.forEach(stdout.writeln);

    return !outcomes.any((outcome) => outcome.endsWith(_noReport));
  }

  /// The inputs of [variants]: one per group of stored stages captured on the
  /// same moments, in the order of their first stage, and one on
  /// [stagelessMoments] for a variant whose snapshot holds no stage.
  List<AtlasHeadlessInput> readInputs(List<AtlasVariantDefinition> variants) {
    final store = AtlasSnapshotStore(_paths);

    return [
      for (final variant in variants)
        ..._readVariantInputs(
          variant,
          store.tryRead(
            flow: variant.flow,
            variant: variant.name,
            locale: _paths.defaultLocale,
          ),
        ),
    ];
  }

  /// The frames of [snapshot] the baseline walk on the tree at
  /// [baselineRootPath] cannot compare: the stages one of whose sources that
  /// tree holds otherwise than the snapshot recorded, and, of a snapshot
  /// without stages, the end when that tree holds any manifest file
  /// otherwise.
  AtlasHeadlessUncomparableFrames readUncomparableFrames(
    AtlasSnapshot? snapshot, {
    required String baselineRootPath,
  }) {
    if (snapshot == null) {
      return _comparableFrames;
    }

    return (
      stages: _readUnmatchedStages(snapshot, baselineRootPath),
      isEndUncomparable:
          snapshot.stages.isEmpty &&
          !snapshot.manifest.entries.every(
            (entry) =>
                _isRecordedFile(baselineRootPath, entry.key, entry.value),
          ),
    );
  }

  /// The moments each group of the stages of [snapshot] was captured on, in
  /// the order of their first stage; [stagelessMoments] for a snapshot
  /// without stages, and one group without moments for no snapshot.
  static List<AtlasHeadlessMoments> readMomentGroups(AtlasSnapshot? snapshot) {
    if (snapshot == null) {
      return const [(anchor: null, launchedAt: null)];
    }

    if (snapshot.stages.isEmpty) {
      return const [stagelessMoments];
    }

    return {
      for (final stage in snapshot.stages)
        (anchor: stage.anchor, launchedAt: stage.launchedAt),
    }.toList();
  }

  static String? _tryReadCleanSourceCommit(
    AtlasLocations paths,
    AtlasSnapshot snapshot,
    String sourceCommit,
  ) {
    if (_isAncestorOfHead(paths.rootPath, sourceCommit)) {
      return sourceCommit;
    }

    return _tryFindSourcesCommit(
      paths.rootPath,
      _headRevision,
      _readStageSources(snapshot),
    );
  }

  static String? _tryReadCommittedSnapshotCommit(
    AtlasLocations paths,
    String snapshotPath,
    String snapshotSource,
  ) {
    final relativePath = './${p.relative(snapshotPath, from: paths.rootPath)}';
    final shotContent = _stripJournalsAndHeadlessFields(snapshotSource);
    final commits = _runProcess('git', [
      'log',
      '--format=%H',
      '--',
      snapshotPath,
    ], paths.rootPath).split('\n').where((commit) => commit.isNotEmpty);
    final shotCommit = commits
        .takeWhile(
          (commit) =>
              _stripJournalsAndHeadlessFields(
                _runProcess('git', [
                  'show',
                  '$commit:$relativePath',
                ], paths.rootPath),
              ) ==
              shotContent,
        )
        .lastOrNull;

    if (shotCommit == null) {
      return null;
    }

    return _findSourcesCommit(
      paths.rootPath,
      shotCommit,
      _readStageSources(
        AtlasSnapshot.fromJson(
          jsonDecode(snapshotSource),
          fileLocale: paths.resolveSnapshotLocale(snapshotPath),
        ),
      ),
    );
  }

  static bool _isAncestorOfHead(String rootPath, String commit) {
    final result = Process.runSync('git', [
      'merge-base',
      '--is-ancestor',
      commit,
      _headRevision,
    ], workingDirectory: rootPath);

    return result.exitCode == 0;
  }

  static String? _tryFindSourcesCommit(
    String rootPath,
    String startRevision,
    Set<_RecordedSource> sources,
  ) {
    if (sources.isEmpty) {
      return null;
    }

    return _listFirstParentCommits(rootPath, startRevision).firstWhereOrNull(
      (commit) => _holdsRecordedSources(rootPath, commit, sources),
    );
  }

  static Iterable<String> _listFirstParentCommits(
    String rootPath,
    String startRevision,
  ) {
    return _runProcess('git', [
      'rev-list',
      '--first-parent',
      '--max-count=$_sourcesCommitLimit',
      startRevision,
    ], rootPath).split('\n').where((commit) => commit.isNotEmpty);
  }

  static String _stripJournalsAndHeadlessFields(String snapshotSource) {
    final snapshot = AtlasJson.readObject(
      jsonDecode(snapshotSource),
      'Snapshot',
    );
    final end = AtlasJson.tryReadObject(snapshot, _endKey);

    return AtlasContentHash.encodeCanonicalJson({
      ..._stripHeadlessFields(snapshot),
      _stagesKey: [
        for (final stage in AtlasJson.readObjects(snapshot, _stagesKey))
          _stripHeadlessFields(stage)..remove(_journalKey),
      ],
      if (end != null) _endKey: _stripHeadlessFields(end),
    });
  }

  static String _findSourcesCommit(
    String rootPath,
    String shotCommit,
    Set<_RecordedSource> sources,
  ) {
    return _tryFindSourcesCommit(rootPath, shotCommit, sources) ?? shotCommit;
  }

  static Set<_RecordedSource> _readStageSources(AtlasSnapshot snapshot) {
    return {
      for (final stage in snapshot.stages)
        for (final MapEntry(:key, :value) in stage.sources.entries)
          (path: key, hash: value),
    };
  }

  Map<String, AtlasSnapshot> _readSnapshots(List<AtlasHeadlessInput> inputs) {
    final store = AtlasSnapshotStore(_paths);

    return {
      for (final input in inputs)
        if (input.momentsIndex == 0)
          input.id: ?store.tryRead(
            flow: input.flow,
            variant: input.variant,
            locale: _paths.defaultLocale,
          ),
    };
  }

  void _deleteReport(AtlasHeadlessInput input) {
    final file = File(input.reportPath);
    final framesDirectory = Directory(input.framesDirectory);

    if (file.existsSync()) {
      file.deleteSync();
    }

    if (framesDirectory.existsSync()) {
      framesDirectory.deleteSync(recursive: true);
    }
  }

  Future<_BaselineCommits> _runAtCommits(
    List<AtlasHeadlessInput> inputs,
    Map<String, AtlasSnapshot> snapshots,
  ) async {
    _pruneWorktrees();

    final commits = {
      for (final input in inputs)
        input.id: ?tryReadSnapshotCommit(
          _paths,
          _paths.resolveSnapshotPath(
            flow: input.flow,
            variant: input.variant,
            locale: _paths.defaultLocale,
          ),
        ),
    };
    final inputsByCommit = groupBy(
      inputs.where((input) => commits.containsKey(input.id)),
      (input) => commits[input.id] ?? '',
    );
    final failedCommits = <String>{};

    for (final MapEntry(key: commit, value: commitInputs)
        in inputsByCommit.entries) {
      if (!await _tryRunAtCommit(commit, commitInputs, snapshots)) {
        failedCommits.add(commit);
      }
    }

    return (commits: commits, failedCommits: failedCommits);
  }

  Future<_BaselineCommits> _runOnTree(
    List<AtlasHeadlessInput> inputs,
    Map<String, AtlasSnapshot> snapshots,
  ) async {
    final sourceHashes = {
      for (final input in inputs)
        if (input.momentsIndex == 0)
          input.id: {
            for (final path in snapshots[input.id]?.manifest.keys ?? <String>[])
              path: AtlasSourceHash.tryHashFile(_paths.resolve(path)),
          },
    };

    await _runIn(_paths.rootPath, inputs);

    for (final MapEntry(key: id, value: variantInputs) in _groupByVariant(
      inputs,
    ).entries) {
      _maybeCompleteReport(variantInputs, snapshots[id], (
        uncomparableFrames: _comparableFrames,
        sourceHashes: sourceHashes[id],
        commit: null,
      ));
    }

    return _treeCommits;
  }

  String _describeOutcome(
    AtlasHeadlessInput input,
    _BaselineCommits baselineCommits,
  ) {
    final (:commits, :failedCommits) = baselineCommits;
    final commit = commits[input.id];

    if (_isBaseline && commit == null) {
      return '${input.id}  $_noCommit';
    }

    if (failedCommits.contains(commit)) {
      return '${input.id}  $_noBaseline $commit';
    }

    final report = AtlasHeadlessReport.tryReadFile(input.reportPath);

    if (report == null) {
      return '${input.id}  $_noReport';
    }

    final stages = '${report.frameHashes.nonNulls.length} stages';

    return switch (report.error) {
      final error? => '${input.id}  $stages, then $error',
      null => '${input.id}  $stages and the end',
    };
  }

  List<AtlasHeadlessInput> _readVariantInputs(
    AtlasVariantDefinition variant,
    AtlasSnapshot? snapshot,
  ) {
    final reportPath = p.absolute(
      _paths.resolveHeadlessReportPath(
        flow: variant.flow,
        variant: variant.name,
        locale: _paths.defaultLocale,
        isBaseline: _isBaseline,
      ),
    );

    return [
      for (final (index, moments) in readMomentGroups(snapshot).indexed)
        AtlasHeadlessInput.fromVariant(
          variant,
          moments: moments,
          locale: _paths.defaultLocale,
          momentsIndex: index,
          recordedUploads: snapshot == null
              ? null
              : AtlasHeadlessUploads.tryRead(snapshot, _settings),
          recordedTexts: [
            for (final stage in snapshot?.stages ?? const <AtlasStage>[])
              ...stage.texts,
            ...?snapshot?.end.texts,
          ],
          reportPath: index == 0
              ? reportPath
              : _resolveMomentsPath(reportPath, index),
        ),
    ];
  }

  Set<int> _readUnmatchedStages(AtlasSnapshot snapshot, String rootPath) {
    return {
      for (final (index, stage) in snapshot.stages.indexed)
        if (!stage.sources.entries.every(
          (entry) => _isRecordedFile(rootPath, entry.key, entry.value),
        ))
          index,
    };
  }

  static Map<String, Object?> _stripHeadlessFields(Map<String, Object?> json) {
    return {
      for (final MapEntry(:key, :value) in json.entries)
        if (!key.startsWith(_headlessKeyPrefix)) key: value,
    };
  }

  static bool _holdsRecordedSources(
    String rootPath,
    String commit,
    Set<_RecordedSource> sources,
  ) {
    final paths = {for (final source in sources) source.path}.toList();
    final contents = _readCommittedFiles(rootPath, commit, paths);

    return sources.every((source) {
      final content = contents[source.path];

      return content != null && _isRecordedContent(content, source.hash);
    });
  }

  void _pruneWorktrees() {
    final directory = Directory(_paths.baselineWorktreesPath);

    if (directory.existsSync()) {
      for (final worktree in directory.listSync().whereType<Directory>()) {
        _removeWorktree(worktree.path);
      }
    }

    _runGit(['worktree', 'prune']);
  }

  Future<bool> _tryRunAtCommit(
    String commit,
    List<AtlasHeadlessInput> inputs,
    Map<String, AtlasSnapshot> snapshots,
  ) async {
    try {
      await _runAtCommit(commit, inputs, snapshots);

      return true;
    } on AtlasException catch (error) {
      stderr.writeln('No baseline on $commit: ${error.message}');

      return false;
    }
  }

  String _resolveMomentsPath(String reportPath, int momentsIndex) {
    return '${p.withoutExtension(reportPath)}.moments$momentsIndex'
        '$_jsonExtension';
  }

  bool _isRecordedFile(String rootPath, String path, String hash) {
    final filePath = p.join(rootPath, path);

    return hash == AtlasContentHash.tryHashFile(filePath) ||
        hash == AtlasSourceHash.tryHashFile(filePath);
  }

  // The git cat-file batch mode answers each object with a header line,
  // then the bytes and a newline, or a name with missing.
  static Map<String, List<int>> _readCommittedFiles(
    String rootPath,
    String commit,
    List<String> paths,
  ) {
    final result = Process.runSync(
      'sh',
      [
        '-c',
        r'printf "%s\n" "$@" | git cat-file --batch',
        'sh',
        for (final path in paths) '$commit:$path',
      ],
      workingDirectory: rootPath,
      stdoutEncoding: null,
    );
    final output = result.stdout;

    if (result.exitCode != 0 || output is! List<int>) {
      throw AtlasException('git cat-file --batch failed:\n${result.stderr}');
    }

    final contents = <String, List<int>>{};
    int offset = 0;

    for (final path in paths) {
      final headerEnd = output.indexOf(_newline, offset);
      final header = utf8.decode(output.sublist(offset, headerEnd));
      final size = int.tryParse(header.split(' ').last);

      offset = headerEnd + 1;

      if (size == null) {
        continue;
      }

      contents[path] = output.sublist(offset, offset + size);
      offset += size + 1;
    }

    return contents;
  }

  static bool _isRecordedContent(List<int> content, String hash) {
    return hash == AtlasContentHash.hashBytes(content) ||
        hash ==
            AtlasSourceHash.hashSource(
              utf8.decode(content, allowMalformed: true),
            );
  }

  Future<void> _runAtCommit(
    String commit,
    List<AtlasHeadlessInput> inputs,
    Map<String, AtlasSnapshot> snapshots,
  ) async {
    final worktreePath = p.absolute(_paths.resolveBaselineWorktreePath(commit));

    _removeWorktree(worktreePath);
    _runGit(['worktree', 'add', '--detach', worktreePath, commit]);

    try {
      final walks = [
        for (final MapEntry(key: id, value: variantInputs) in _groupByVariant(
          inputs,
        ).entries)
          (
            variantInputs: variantInputs,
            snapshot: snapshots[id],
            uncomparableFrames: readUncomparableFrames(
              snapshots[id],
              baselineRootPath: worktreePath,
            ),
          ),
      ];

      _copyWalkFilesInto(worktreePath);

      await _runIn(worktreePath, inputs);

      for (final (:variantInputs, :snapshot, :uncomparableFrames) in walks) {
        _maybeCompleteReport(variantInputs, snapshot, (
          uncomparableFrames: uncomparableFrames,
          sourceHashes: null,
          commit: commit,
        ));
      }
    } finally {
      _removeWorktree(worktreePath);
    }
  }

  Map<String, List<AtlasHeadlessInput>> _groupByVariant(
    List<AtlasHeadlessInput> inputs,
  ) {
    return groupBy(inputs, (input) => input.id);
  }

  void _copyWalkFilesInto(String worktreePath) {
    for (final directory in _settings.copiedDirectories) {
      _copy(_paths.resolve(directory), p.join(worktreePath, directory));
    }

    for (final path in [_fvmConfigPath, ..._readFileAssets()]) {
      _maybeCopyMissing(path, worktreePath);
    }

    final flutter = _paths.project.launch.resolveCommand('flutter');

    _runProcess(flutter.executable, [
      ...flutter.arguments,
      'pub',
      'get',
    ], worktreePath);
  }

  Future<void> _runIn(String rootPath, List<AtlasHeadlessInput> inputs) async {
    _writeEntry(rootPath);

    final directory = Directory.systemTemp.createTempSync(_directoryPrefix);

    try {
      final inputFile = File(p.join(directory.path, _inputFileName))
        ..writeAsStringSync(
          jsonEncode(inputs.map((input) => input.toJson()).toList()),
        );
      final flutter = _paths.project.launch.resolveCommand('flutter');

      final process = await Process.start(
        flutter.executable,
        [
          ...flutter.arguments,
          'test',
          _resolveEntryPath(),
          '--timeout',
          _timeout,
          for (final define in _settings.defines) '--dart-define=$define',
          '--dart-define=$inputDefine=${inputFile.path}',
        ],
        workingDirectory: rootPath,
        mode: ProcessStartMode.inheritStdio,
      );

      await process.exitCode;
    } finally {
      directory.deleteSync(recursive: true);
    }
  }

  void _maybeCompleteReport(
    List<AtlasHeadlessInput> variantInputs,
    AtlasSnapshot? snapshot,
    _ReportCompletion completion,
  ) {
    final input = variantInputs.firstOrNull;

    if (input == null) {
      return;
    }

    final report = variantInputs.length == 1
        ? AtlasHeadlessReport.tryReadFile(input.reportPath)
        : _assembleReport(variantInputs, snapshot);

    if (report == null) {
      return;
    }

    final (:uncomparableFrames, :sourceHashes, :commit) = completion;

    File(input.reportPath).writeAsStringSync(
      jsonEncode(
        report
            .withoutFrames(
              uncomparableFrames,
              sourceHashes: sourceHashes,
              commit: commit,
            )
            .toJson(),
      ),
    );
  }

  void _removeWorktree(String worktreePath) {
    if (!Directory(worktreePath).existsSync()) {
      return;
    }

    _runGit(['worktree', 'remove', '--force', worktreePath]);

    final directory = Directory(worktreePath);

    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }

  void _copy(String source, String target) {
    Directory(target).createSync(recursive: true);
    _runProcess('cp', ['-R', '$source/.', target], _paths.rootPath);
  }

  List<String> _readFileAssets() {
    final pubspec = File(_paths.resolve(_pubspecPath)).readAsStringSync();

    return [
      for (final match in _assetEntry.allMatches(pubspec))
        if (match.group(1) case final asset? when !asset.endsWith('/')) asset,
    ];
  }

  void _maybeCopyMissing(String path, String worktreePath) {
    final source = File(_paths.resolve(path));
    final target = File(p.join(worktreePath, path));

    if (!source.existsSync() || target.existsSync()) {
      return;
    }

    source.copySync(target.path);
  }

  void _writeEntry(String rootPath) {
    final mainPath = p.join(rootPath, _settings.mainPath);
    final entryPath = p.join(rootPath, _resolveEntryPath());
    final source = File(mainPath).readAsStringSync();

    File(entryPath)
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '${_renderEntryImports(rootPath, entryPath)}'
        '${_patch(source, mainPath)}'
        '\n${_settings.entryMain}\n',
      );

    final dart = _paths.project.launch.resolveCommand('dart');

    _runProcess(dart.executable, [
      ...dart.arguments,
      'format',
      entryPath,
    ], rootPath);
  }

  AtlasHeadlessReport? _assembleReport(
    List<AtlasHeadlessInput> variantInputs,
    AtlasSnapshot? snapshot,
  ) {
    final stageInputs = [
      for (final stage in snapshot?.stages ?? const <AtlasStage>[])
        variantInputs.firstWhereOrNull(
          (input) =>
              input.anchor == stage.anchor &&
              input.launchedAt == stage.launchedAt,
        ),
    ];
    final mainInput = variantInputs.firstOrNull;

    if (mainInput == null) {
      return null;
    }

    if (stageInputs.isEmpty || stageInputs.contains(null)) {
      return null;
    }

    for (final (index, input) in stageInputs.nonNulls.indexed) {
      _maybeCopyFrame(input, mainInput, '$index');
    }

    final lastInput = stageInputs.last;

    if (lastInput != null) {
      _maybeCopyFrame(lastInput, mainInput, endFrameName);
    }

    return AtlasHeadlessReport.assemble([
      for (final input in stageInputs.nonNulls)
        AtlasHeadlessReport.tryReadFile(input.reportPath),
    ]);
  }

  String _runGit(List<String> arguments) {
    return _runProcess('git', arguments, _paths.rootPath);
  }

  String _resolveEntryPath() {
    return p.join(_paths.project.paths.build, _entryPath);
  }

  String _renderEntryImports(String rootPath, String entryPath) {
    return [
      for (final path in _settings.entryImports)
        "import '${_relativizeImport(rootPath, entryPath, path)}';",
    ].join('\n');
  }

  String _relativizeImport(String rootPath, String entryPath, String path) {
    return p.relative(p.join(rootPath, path), from: p.dirname(entryPath));
  }

  String _patch(String source, String path) {
    return _settings.mainPatch.fold(source, (text, replacement) {
      final (from, to) = replacement;

      if (!text.contains(from)) {
        throw AtlasException(
          'The headless walk finds no "$from" in $path to rewrite.',
        );
      }

      return text.replaceAll(from, to);
    });
  }

  void _maybeCopyFrame(
    AtlasHeadlessInput from,
    AtlasHeadlessInput to,
    String frameName,
  ) {
    if (from == to) {
      return;
    }

    final source = File(
      p.join(from.framesDirectory, '$frameName$_pngExtension'),
    );

    if (!source.existsSync()) {
      return;
    }

    source.copySync(p.join(to.framesDirectory, '$frameName$_pngExtension'));
  }

  static String _runProcess(
    String executable,
    List<String> arguments,
    String workingDirectory,
  ) {
    final result = Process.runSync(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );

    if (result.exitCode != 0) {
      throw AtlasException(
        '$executable ${arguments.join(' ')} failed:\n${result.stderr}',
      );
    }

    return '${result.stdout}'.trim();
  }
}

/// {@category Utils}
///
/// What one headless walk of a variant needs: the scenario, the resolved
/// steps and the locale. It also holds the moments the mock seeds its dates on
/// and the file its report goes to.
final class AtlasHeadlessInput {
  /// The run the variant names, the way a stale line names it.
  final String id;

  /// Name of the flow.
  final String flow;

  /// Name of the variant.
  final String variant;

  /// The scenario of the variant.
  final Map<String, Object?> scenario;

  /// The resolved steps, as a dry run of the runner prints them, with the
  /// target under `finder` as well, where a flow file names it, and the
  /// duration and the frequency of every scroll.
  final List<Map<String, Object?>> steps;

  /// The locale the walk applies, as a capture applies it.
  final String locale;

  /// The file the report of the walk is written to.
  final String reportPath;

  /// The position of [anchor] and [launchedAt] among the moments the stages
  /// of the snapshot were captured on.
  final int momentsIndex;

  /// The texts the stages and the end of the snapshot showed; a text among
  /// them is never taken for a wall-clock time of the walk.
  final List<String> recordedTexts;

  /// The anchor the walk runs on, as a UTC ISO 8601 moment, absent to read
  /// it off the launch.
  final String? anchor;

  /// The launch moment the walk runs on, absent with [anchor].
  final String? launchedAt;

  /// The uploads the capture device sent, absent when the snapshot recorded
  /// no mock pick.
  final AtlasHeadlessUploads? recordedUploads;

  const AtlasHeadlessInput({
    required this.id,
    required this.flow,
    required this.variant,
    required this.scenario,
    required this.steps,
    required this.reportPath,
    required this.anchor,
    required this.launchedAt,
    required this.locale,
    this.momentsIndex = 0,
    this.recordedTexts = const [],
    this.recordedUploads,
  });

  /// The input walking [variant] on [moments].
  factory AtlasHeadlessInput.fromVariant(
    AtlasVariantDefinition variant, {
    required AtlasHeadlessMoments moments,
    required String locale,
    required String reportPath,
    int momentsIndex = 0,
    List<String> recordedTexts = const [],
    AtlasHeadlessUploads? recordedUploads,
  }) {
    final automationFlow = variant.automationFlow;

    return AtlasHeadlessInput(
      id: variant.id,
      flow: variant.flow,
      variant: variant.name,
      scenario: variant.scenario,
      steps: [
        for (final step in automationFlow.steps)
          {
            ...step.toReport(),
            'finder': ?step.target,
            'durationMs': step.duration.inMilliseconds,
            'frequency': step.frequency,
          },
      ],
      anchor: moments.anchor,
      launchedAt: moments.launchedAt,
      locale: locale,
      momentsIndex: momentsIndex,
      recordedTexts: recordedTexts,
      recordedUploads: recordedUploads,
      reportPath: reportPath,
    );
  }

  /// Reads an input written by [toJson].
  factory AtlasHeadlessInput.fromJson(Map<String, Object?> json) {
    return AtlasHeadlessInput(
      id: AtlasJson.readString(json, 'id'),
      flow: AtlasJson.readString(json, 'flow'),
      variant: AtlasJson.readString(json, 'variant'),
      scenario: AtlasJson.tryReadObject(json, 'scenario') ?? const {},
      steps: AtlasJson.readObjects(json, 'steps'),
      locale: AtlasJson.readString(json, 'locale'),
      anchor: AtlasJson.tryReadString(json, 'anchor'),
      launchedAt: AtlasJson.tryReadString(json, 'launchedAt'),
      momentsIndex: switch (json['momentsIndex']) {
        final int index => index,
        _ => 0,
      },
      recordedTexts: AtlasJson.readList(
        json,
        'recordedTexts',
      ).whereType<String>().toList(),
      recordedUploads: switch (AtlasJson.tryReadObject(
        json,
        'recordedUploads',
      )) {
        final recordedUploads? => AtlasHeadlessUploads.fromJson(
          recordedUploads,
        ),
        null => null,
      },
      reportPath: AtlasJson.readString(json, 'reportPath'),
    );
  }

  /// The directory the PNG of every frame is written to, beside the report.
  String get framesDirectory => p.withoutExtension(reportPath);

  /// The walk the test of this input names: the run, and the moments when
  /// they are not the first the stages were captured on.
  String get walkName => momentsIndex == 0 ? id : '$id on $launchedAt';

  /// Reads the inputs a [AtlasHeadless] wrote.
  static List<AtlasHeadlessInput> readAll(String source) {
    final json = jsonDecode(source);

    if (json is! List<Object?>) {
      throw const AtlasException('The headless input is not a list.');
    }

    return json
        .map(
          (item) => AtlasHeadlessInput.fromJson(
            AtlasJson.readObject(item, 'A headless input'),
          ),
        )
        .toList();
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'flow': flow,
      'variant': variant,
      'scenario': scenario,
      'steps': steps,
      'locale': locale,
      'anchor': ?anchor,
      'launchedAt': ?launchedAt,
      'momentsIndex': momentsIndex,
      'recordedTexts': recordedTexts,
      'recordedUploads': ?recordedUploads?.toJson(),
      'reportPath': reportPath,
    };
  }
}

/// {@category Utils}
///
/// The sizes of the images the capture device sent, from the journal of a
/// snapshot.
///
/// A headless walk compresses its images to the same sizes. Each upload holds
/// the size and the pixel size of the compressed original and the size of the
/// preview, in the order of the message. The project reads them out of its
/// journal records ([AtlasHeadlessSettings.tryReadUploads]).
final class AtlasHeadlessUploads {
  /// Every image sent, in the order the message sent holds them.
  final List<AtlasHeadlessUpload> uploads;

  const AtlasHeadlessUploads({required this.uploads});

  /// Reads the uploads that [toJson] wrote.
  factory AtlasHeadlessUploads.fromJson(Map<String, Object?> json) {
    return AtlasHeadlessUploads(
      uploads: [
        for (final upload in AtlasJson.readObjects(json, 'uploads'))
          ?_tryReadUpload(upload),
      ],
    );
  }

  /// Returns the uploads of the first message of [snapshot] with uploads, as
  /// [settings] reads them.
  ///
  /// Returns `null` when the project reads none.
  static AtlasHeadlessUploads? tryRead(
    AtlasSnapshot snapshot,
    AtlasHeadlessSettings settings,
  ) {
    final records = snapshot.stages.expand((stage) => stage.journal).toList();
    final uploads = settings.tryReadUploads?.call(records);

    return uploads == null ? null : AtlasHeadlessUploads(uploads: uploads);
  }

  Map<String, Object?> toJson() {
    return {
      'uploads': [
        for (final (:original, :preview, :width, :height) in uploads)
          {
            'original': original,
            'preview': preview,
            'width': width,
            'height': height,
          },
      ],
    };
  }

  static AtlasHeadlessUpload? _tryReadUpload(Map<String, Object?> json) {
    return switch (json) {
      {
        'original': final int original,
        'preview': final int preview,
        'width': final int width,
        'height': final int height,
      } =>
        (original: original, preview: preview, width: width, height: height),
      _ => null,
    };
  }
}

/// The stage frames and whether the end frame of a headless report cannot be
/// compared with a snapshot.
typedef AtlasHeadlessUncomparableFrames = ({
  Set<int> stages,
  bool isEndUncomparable,
});

/// The anchor and the launch moment a walk runs on, as UTC ISO 8601 moments,
/// absent to read them off the launch.
typedef AtlasHeadlessMoments = ({String? anchor, String? launchedAt});

/// {@category Utils}
///
/// What one headless walk of a variant showed: for every stage it reached, in
/// stage order, and for the end when it walked every step, the hash of the
/// frame — absent when the frame showed an image not yet decoded or the stage
/// cannot be compared — and the journal records the app wrote up to it,
/// cleaned as a snapshot stores them.
final class AtlasHeadlessReport {
  /// The frame hash of every stage the walk reached, in stage order.
  final List<String?> frameHashes;

  /// The records the app wrote up to the frame of every stage the walk
  /// reached, since the frame before it or the start of the walk, and then up
  /// to the end; absent for a frame the report does not read them up to.
  final List<List<Object?>?> journals;

  /// The record of the launch, as a snapshot opens its first stage with it.
  final Map<String, Object?>? launch;

  /// The frame hash of the end, absent when a step failed.
  final String? endFrameHash;

  /// The step that failed and why, absent when every step passed.
  final String? error;

  /// The hash of every manifest file of the snapshot when the current walk
  /// ran, absent in a baseline report.
  final Map<String, String?>? sourceHashes;

  /// The commit the baseline walk ran on, absent in a current report.
  final String? commit;

  const AtlasHeadlessReport({
    required this.frameHashes,
    required this.endFrameHash,
    required this.error,
    this.journals = const [],
    this.launch,
    this.sourceHashes,
    this.commit,
  });

  /// Reads a report written by [toJson].
  factory AtlasHeadlessReport.fromJson(Object? json) {
    final report = AtlasJson.readObject(json, 'A headless report');
    final sourceHashes = AtlasJson.tryReadObject(report, 'sourceHashes');

    return AtlasHeadlessReport(
      frameHashes: AtlasJson.readList(
        report,
        'frameHashes',
      ).map((hash) => hash is String ? hash : null).toList(),
      journals: AtlasJson.readList(
        report,
        'journals',
      ).map((journal) => journal is List<Object?> ? journal : null).toList(),
      launch: AtlasJson.tryReadObject(report, 'launch'),
      endFrameHash: AtlasJson.tryReadString(report, 'endFrameHash'),
      error: AtlasJson.tryReadString(report, 'error'),
      sourceHashes: sourceHashes?.map(
        (path, hash) => MapEntry(path, hash is String ? hash : null),
      ),
      commit: AtlasJson.tryReadString(report, 'commit'),
    );
  }

  /// The report each stage of which comes from the report [stageReports]
  /// holds at its index, the end and the journal before the first stage from
  /// the report of the last stage and of the first stage, and the error from
  /// the first report left without the frame of its own stage, else from the
  /// report of the last stage.
  factory AtlasHeadlessReport.assemble(
    List<AtlasHeadlessReport?> stageReports,
  ) {
    final firstReport = stageReports.firstOrNull;
    final lastReport = stageReports.lastOrNull;

    return AtlasHeadlessReport(
      frameHashes: [
        for (final (index, report) in stageReports.indexed)
          report?.frameHashes.elementAtOrNull(index),
      ],
      journals: [
        firstReport?.journals.firstOrNull,
        for (final (index, report) in stageReports.indexed)
          report?.journals.elementAtOrNull(index + 1),
      ],
      launch: firstReport?.launch,
      endFrameHash: lastReport?.endFrameHash,
      error: _tryReadErrorOfMissingStage(stageReports) ?? lastReport?.error,
    );
  }

  /// Reads the report at [path], absent when there is none or it is
  /// unreadable.
  static AtlasHeadlessReport? tryReadFile(String path) {
    final file = File(path);

    if (!file.existsSync()) {
      return null;
    }

    try {
      return AtlasHeadlessReport.fromJson(jsonDecode(file.readAsStringSync()));
    } on Object {
      return null;
    }
  }

  /// Whether stage [index] showed the frame [baseline] holds for it; a stage
  /// with no frame hash on either side never did.
  bool hasSameFrame(AtlasHeadlessReport baseline, int index) {
    final frameHash = frameHashes.elementAtOrNull(index);

    return frameHash != null &&
        frameHash == baseline.frameHashes.elementAtOrNull(index);
  }

  /// Whether the walk ended on the frame [baseline] ended on.
  bool hasSameEndFrame(AtlasHeadlessReport baseline) {
    return endFrameHash != null && endFrameHash == baseline.endFrameHash;
  }

  /// The journal stage [index] holds as a snapshot stores it: the records
  /// read after its frame, up to the frame of the next stage or of the end,
  /// the first stage opened by the launch; absent when the report does not
  /// read them. The records before the frame of the first stage belong to no
  /// stage, since a capture keeps no journal before its first shot.
  List<Object?>? tryReadStageJournal(int index) {
    final journal = journals.elementAtOrNull(index + 1);

    if (journal == null) {
      return null;
    }

    return [if (index == 0) ?launch, ...journal];
  }

  /// The same report without the frame hash of the frames in [frames].
  AtlasHeadlessReport withoutFrames(
    AtlasHeadlessUncomparableFrames frames, {
    required Map<String, String?>? sourceHashes,
    required String? commit,
  }) {
    final (:stages, :isEndUncomparable) = frames;

    return AtlasHeadlessReport(
      frameHashes: [
        for (final (index, hash) in frameHashes.indexed)
          stages.contains(index) ? null : hash,
      ],
      journals: journals,
      launch: launch,
      endFrameHash: isEndUncomparable ? null : endFrameHash,
      error: error,
      sourceHashes: sourceHashes,
      commit: commit,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'frameHashes': frameHashes,
      'journals': journals,
      'launch': ?launch,
      'endFrameHash': endFrameHash,
      'error': ?error,
      'sourceHashes': ?sourceHashes,
      'commit': ?commit,
    };
  }

  static String? _tryReadErrorOfMissingStage(
    List<AtlasHeadlessReport?> stageReports,
  ) {
    for (final (index, report) in stageReports.indexed) {
      if (report?.frameHashes.elementAtOrNull(index) == null) {
        return report?.error;
      }
    }

    return null;
  }
}
