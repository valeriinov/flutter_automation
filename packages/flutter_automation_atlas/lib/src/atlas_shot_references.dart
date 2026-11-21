import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_versions.dart';

/// {@category Utils}
///
/// The screenshot identifiers that the repository of an atlas store needs:
/// each one that a file of the repository names.
///
/// It reads the files of the working tree and of each remote branch, so a
/// screenshot of an open pull request counts. A file names a screenshot in
/// one of these places:
///
/// - a `shot` field of a JSON file, such as a snapshot of any store folder;
/// - the `atlas-data` script of a page, plain or packed, in its `shot`
///   fields;
/// - the `atlas-shots` script of a page, in the links of `shotUrls`;
/// - the `shot` fields of a `data.json.gz` file, the data of a version
///   folder of a site.
///
/// A folder with no `.git` entry above it is outside a git repository, and
/// the read takes only the files under the folder. A git failure inside a
/// repository stops the read. So does a `data.json.gz` file that is not a
/// gzip of text, or that names no screenshot.
final class AtlasShotReferences {
  static const _jsonExtension = '.json';
  static const _htmlExtension = '.html';
  static const _gitDirectory = '.git';
  static const _remoteRefsPrefix = 'refs/remotes';
  static const _blobType = 'blob';
  static const _lineFeed = 0x0a;
  static const _shotsScriptId = 'atlas-shots';
  static const _dataScriptId = 'atlas-data';
  static final _shotFieldPattern = RegExp(r'"shot"\s*:\s*"([0-9a-f]{64})"');
  static final _shotLinkPattern = RegExp(
    r'(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])',
  );

  final String _path;

  /// The [path] parameter names a folder of the repository, such as the
  /// store folder.
  const AtlasShotReferences(String path) : _path = path;

  /// The identifiers that the repository needs.
  ///
  /// Throws an [AtlasException] when no file names a screenshot. An empty
  /// set tells of a wrong folder, and a command that removes the other
  /// screenshots must stop.
  Future<Set<String>> read() async {
    final root = _tryReadRepositoryRoot();
    final shots = root == null
        ? _readDirectory(_path)
        : {..._readWorkingTree(root), ...await _readRemoteBranches(root)};

    if (shots.isEmpty) {
      throw AtlasException(
        'No file under ${root ?? _path} names a screenshot; the needed set '
        'of screenshots is empty.',
      );
    }

    return shots;
  }

  /// The identifiers that a file with the [path] and the [bytes] names.
  ///
  /// Throws an [AtlasException] when the file is the data of a version
  /// folder and names no screenshot.
  Set<String> readFile(String path, List<int> bytes) {
    if (p.basename(path) == AtlasVersions.dataFileName) {
      return _readVersionData(path, bytes);
    }

    return switch (p.extension(path)) {
      _jsonExtension => _readShotFields(_decode(bytes)),
      _htmlExtension => _readPage(_decode(bytes)),
      _ => const {},
    };
  }

  String? _tryReadRepositoryRoot() {
    if (!Directory(_path).existsSync() || !_isInsideRepository()) {
      return null;
    }

    final result = Process.runSync('git', [
      'rev-parse',
      '--show-toplevel',
    ], workingDirectory: _path);

    if (result.exitCode == 0) {
      return '${result.stdout}'.trim();
    }

    throw AtlasException(
      'git rev-parse --show-toplevel failed in $_path: ${result.stderr}',
    );
  }

  bool _isInsideRepository() {
    Directory directory = Directory(_path).absolute;

    while (true) {
      final entry = p.join(directory.path, _gitDirectory);

      if (FileSystemEntity.typeSync(entry) != FileSystemEntityType.notFound) {
        return true;
      }

      if (directory.parent.path == directory.path) {
        return false;
      }

      directory = directory.parent;
    }
  }

  Set<String> _readDirectory(String path) {
    final directory = Directory(path);

    if (!directory.existsSync()) {
      return const {};
    }

    return {
      for (final file in directory.listSync(recursive: true).whereType<File>())
        if (_isRead(file.path)) ...readFile(file.path, file.readAsBytesSync()),
    };
  }

  Set<String> _readWorkingTree(String root) {
    final paths = _runGit(root, [
      'ls-files',
      '--cached',
      '--others',
      '--exclude-standard',
      '-z',
    ]).split('\x00');

    return {
      for (final path in paths)
        if (_isRead(path) && File(p.join(root, path)).existsSync())
          ...readFile(path, File(p.join(root, path)).readAsBytesSync()),
    };
  }

  Future<Set<String>> _readRemoteBranches(String root) async {
    final refs = const LineSplitter()
        .convert(
          _runGit(root, [
            'for-each-ref',
            '--format=%(refname)',
            _remoteRefsPrefix,
          ]),
        )
        .where((ref) => ref.isNotEmpty);
    final pathsByBlob = <String, String>{
      for (final ref in refs) ..._listBlobs(root, ref),
    };

    if (pathsByBlob.isEmpty) {
      return const {};
    }

    final contents = await _readBlobs(root, pathsByBlob.keys.toList());

    return {
      for (final MapEntry(key: blob, value: bytes) in contents.entries)
        ...readFile(pathsByBlob[blob] ?? '', bytes),
    };
  }

  Map<String, String> _listBlobs(String root, String ref) {
    final entries = _runGit(root, ['ls-tree', '-r', '-z', ref]).split('\x00');

    return {
      for (final entry in entries)
        if (_tryReadTreeEntry(entry) case (:final blob, :final path))
          blob: path,
    };
  }

  ({String blob, String path})? _tryReadTreeEntry(String entry) {
    final tabIndex = entry.indexOf('\t');

    if (tabIndex < 0) {
      return null;
    }

    final fields = entry.substring(0, tabIndex).split(' ');
    final path = entry.substring(tabIndex + 1);

    if (fields.length != 3 || fields[1] != _blobType || !_isRead(path)) {
      return null;
    }

    return (blob: fields[2], path: path);
  }

  Future<Map<String, Uint8List>> _readBlobs(
    String root,
    List<String> blobs,
  ) async {
    final process = await Process.start('git', [
      'cat-file',
      '--batch',
    ], workingDirectory: root);

    final output = BytesBuilder(copy: false);
    final outputDone = process.stdout.forEach(output.add);
    final errorDone = process.stderr.drain<void>();

    process.stdin.writeln(blobs.join('\n'));

    await process.stdin.close();
    await Future.wait([outputDone, errorDone]);

    if (await process.exitCode != 0) {
      throw AtlasException('git cat-file --batch failed in $root.');
    }

    return _splitBatch(output.takeBytes(), blobs.length, root);
  }

  // Each record of `git cat-file --batch` is a header line
  // `<sha> <type> <size>`, the content of that size and one line feed.
  Map<String, Uint8List> _splitBatch(Uint8List bytes, int count, String root) {
    final contents = <String, Uint8List>{};
    int offset = 0;

    for (int index = 0; index < count; index++) {
      final headerEnd = bytes.indexOf(_lineFeed, offset);
      final header = headerEnd < 0
          ? const <String>[]
          : ascii.decode(bytes.sublist(offset, headerEnd)).split(' ');
      final size = header.length == 3 ? int.tryParse(header[2]) : null;

      if (size == null) {
        throw AtlasException('git cat-file --batch answered no blob in $root.');
      }

      final start = headerEnd + 1;

      contents[header.first] = Uint8List.sublistView(
        bytes,
        start,
        start + size,
      );
      offset = start + size + 1;
    }

    return contents;
  }

  bool _isRead(String path) {
    return _hasReadExtension(path) && !p.split(path).contains(_gitDirectory);
  }

  bool _hasReadExtension(String path) {
    final extension = p.extension(path);

    return extension == _jsonExtension ||
        extension == _htmlExtension ||
        p.basename(path) == AtlasVersions.dataFileName;
  }

  Set<String> _readVersionData(String path, List<int> bytes) {
    final shots = _readShotFields(_tryInflate(bytes) ?? '');

    if (shots.isEmpty) {
      throw AtlasException(
        'The version data $path names no screenshot; the needed set of '
        'screenshots is not known.',
      );
    }

    return shots;
  }

  String? _tryInflate(List<int> bytes) {
    try {
      return _decode(gzip.decode(bytes));
    } on FormatException {
      return null;
    }
  }

  String _decode(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);

  Set<String> _readPage(String page) {
    final links = _tryReadScript(page, _shotsScriptId);
    final data = _tryReadScript(page, _dataScriptId);

    return {
      if (links != null)
        ..._shotLinkPattern.allMatches(links).map((match) => match[0]).nonNulls,
      if (data != null) ..._readShotFields(_unpack(data)),
    };
  }

  String? _tryReadScript(String page, String id) {
    final start = page.indexOf('id="$id">');
    final end = start < 0 ? -1 : page.indexOf('</script>', start);

    return end < 0 ? null : page.substring(start + id.length + 6, end);
  }

  String _unpack(String data) {
    final text = data.trim();

    if (!text.startsWith('"')) {
      return text;
    }

    try {
      return _decode(gzip.decode(base64Decode('${jsonDecode(text)}')));
    } on FormatException {
      return text;
    }
  }

  Set<String> _readShotFields(String text) {
    return _shotFieldPattern
        .allMatches(text)
        .map((match) => match[1])
        .nonNulls
        .toSet();
  }

  String _runGit(String root, List<String> arguments) {
    final result = Process.runSync(
      'git',
      arguments,
      workingDirectory: root,
      stdoutEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw AtlasException(
        'git ${arguments.join(' ')} failed in $root: ${result.stderr}',
      );
    }

    return '${result.stdout}';
  }
}
