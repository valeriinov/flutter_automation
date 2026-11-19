import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _widgetTestLibrary = 'widget_tester_finders.dart';

void main() {
  group('AutomationRunner Library Imports Tests', () {
    _automationRunnerLibrary_should_importNoFlutterPackage();
  });
}

void _automationRunnerLibrary_should_importNoFlutterPackage() {
  test('AutomationRunner library should import no Flutter package', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith(_widgetTestLibrary))
        .where(
          (file) => file.readAsLinesSync().any(
            (line) => line.trimLeft().startsWith(
              RegExp(
                '(import|export) [\'"](dart:ui|package:flutter/|'
                'package:flutter_test/)',
              ),
            ),
          ),
        )
        .map((file) => file.path)
        .toList();

    expect(offenders, isEmpty);
  });
}
