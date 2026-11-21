import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _noConfigFile = '/dev/null';
const _environment = {
  'GIT_CONFIG_GLOBAL': _noConfigFile,
  'GIT_CONFIG_NOSYSTEM': '1',
};

// The git calls of the product run without `_environment`. The local config
// of a test repository outranks the global one for them.
const _localConfig = {
  'core.hooksPath': _noConfigFile,
  'commit.gpgSign': 'false',
  'tag.gpgSign': 'false',
  'push.gpgSign': 'false',
};

String runTestGit(String directory, List<String> arguments) {
  final result = tryRunTestGit(directory, arguments);

  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')}: ${result.stderr}');
  }

  return '${result.stdout}'.trim();
}

ProcessResult tryRunTestGit(String directory, List<String> arguments) {
  return Process.runSync(
    'git',
    ['-c', 'user.name=test', '-c', 'user.email=test@example.com', ...arguments],
    workingDirectory: directory,
    environment: _environment,
  );
}

void initTestGit(String directory, {bool isBare = false}) {
  runTestGit(directory, [
    'init',
    '--quiet',
    '--initial-branch',
    'main',
    if (isBare) '--bare',
  ]);
  _writeLocalConfig(directory);
}

String commitTestGit(String directory, String message) {
  runTestGit(directory, ['add', '--all']);
  runTestGit(directory, ['commit', '--quiet', '--message', message]);

  return runTestGit(directory, ['rev-parse', 'HEAD']);
}

String addTestGitOrigin(String directory) {
  final origin = Directory.systemTemp.createTempSync('atlas-origin-');

  addTearDown(() => origin.deleteSync(recursive: true));
  initTestGit(origin.path, isBare: true);
  runTestGit(directory, ['remote', 'add', 'origin', origin.path]);

  return origin.path;
}

String cloneTestGit(String origin, {List<String> options = const []}) {
  final clone = Directory.systemTemp.createTempSync('atlas-clone-');

  addTearDown(() => clone.deleteSync(recursive: true));
  runTestGit(clone.path, ['clone', '--quiet', ...options, origin, '.']);
  _writeLocalConfig(clone.path);

  return clone.resolveSymbolicLinksSync();
}

void pushTestGit(String directory, String ref) {
  runTestGit(directory, ['push', '--quiet', 'origin', ref]);
}

void _writeLocalConfig(String directory) {
  for (final MapEntry(:key, :value) in _localConfig.entries) {
    runTestGit(directory, ['config', key, value]);
  }
}
