import 'dart:io';

String runTestGit(String directory, List<String> arguments) {
  final result = Process.runSync('git', [
    '-c',
    'user.name=test',
    '-c',
    'user.email=test@example.com',
    '-c',
    'commit.gpgsign=false',
    ...arguments,
  ], workingDirectory: directory);

  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')}: ${result.stderr}');
  }

  return '${result.stdout}'.trim();
}

String commitTestGit(String directory, String message) {
  runTestGit(directory, ['add', '--all']);
  runTestGit(directory, ['commit', '--quiet', '--message', message]);

  return runTestGit(directory, ['rev-parse', 'HEAD']);
}
