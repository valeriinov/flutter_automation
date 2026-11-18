import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const _packageConfigPath = '.dart_tool/package_config.json';

// Test utility text of the package configuration the workspace resolved, with
// every package at an absolute location and the app package [packageName] at
// the root of a temporary directory.
String readTestPackageConfig(String packageName) {
  Directory directory = Directory.current.absolute;

  while (!File(p.join(directory.path, _packageConfigPath)).existsSync()) {
    directory = directory.parent;
  }

  final configFile = File(p.join(directory.path, _packageConfigPath));
  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, Object?>;
  final packages = [
    for (final package in config['packages'] as List<Object?>)
      _resolveRootUri(package as Map<String, Object?>, configFile.uri),
    {
      'name': packageName,
      'rootUri': '../',
      'packageUri': 'lib/',
      'languageVersion': '3.9',
    },
  ];

  return jsonEncode({...config, 'packages': packages});
}

Map<String, Object?> _resolveRootUri(
  Map<String, Object?> package,
  Uri configUri,
) {
  final rootUri = package['rootUri'] as String;

  return {...package, 'rootUri': configUri.resolve(rootUri).toString()};
}
