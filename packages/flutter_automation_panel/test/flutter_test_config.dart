import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _fontFolderPath = 'bin/cache/artifacts/material_fonts';
const _monoFont = '/System/Library/Fonts/SFNSMono.ttf';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sdk = Platform.environment['FLUTTER_ROOT'] ?? '';
  final fontFolder = '$sdk/$_fontFolderPath';

  await _loadFont('Roboto', [
    '$fontFolder/Roboto-Regular.ttf',
    '$fontFolder/Roboto-Medium.ttf',
    '$fontFolder/Roboto-Bold.ttf',
  ]);
  await _loadFont('MaterialIcons', ['$fontFolder/MaterialIcons-Regular.otf']);
  await _loadFont('Menlo', [_monoFont]);
  await testMain();
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);

  for (final path in paths) {
    final file = File(path);

    if (file.existsSync()) {
      final bytes = ByteData.sublistView(file.readAsBytesSync());

      loader.addFont(Future.value(bytes));
    }
  }

  await loader.load();
}
