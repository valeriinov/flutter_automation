import 'dart:io';

import 'package:flutter_automation_driver/src/automation_launch_locale_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutomationLaunchLocaleFile Tests', () {
    _automationLaunchLocaleFile_should_answerNullWithoutASavedCode();
    _automationLaunchLocaleFile_should_answerTheSavedCodeOnce();
    _automationLaunchLocaleFile_should_answerNullForAnEmptyFile();
  });
}

void _automationLaunchLocaleFile_should_answerNullWithoutASavedCode() {
  test(
    'AutomationLaunchLocaleFile should answer null without a saved code',
    () {
      final languageCode = _inTemporaryDirectory(
        AutomationLaunchLocaleFile.consume,
      );

      expect(languageCode, isNull);
    },
  );
}

void _automationLaunchLocaleFile_should_answerTheSavedCodeOnce() {
  test(
    'AutomationLaunchLocaleFile should answer the saved code once',
    () async {
      final directory = _createTemporaryDirectory();

      await _inDirectory(
        directory,
        () => AutomationLaunchLocaleFile.save('uk'),
      );

      final firstLaunch = _inDirectory(
        directory,
        AutomationLaunchLocaleFile.consume,
      );
      final secondLaunch = _inDirectory(
        directory,
        AutomationLaunchLocaleFile.consume,
      );

      expect(firstLaunch, 'uk');
      expect(secondLaunch, isNull);
      expect(directory.listSync(), isEmpty);
    },
  );
}

void _automationLaunchLocaleFile_should_answerNullForAnEmptyFile() {
  test('AutomationLaunchLocaleFile should answer null for an empty file', () {
    final directory = _createTemporaryDirectory();

    File('${directory.path}/automation_launch_locale').writeAsStringSync(' ');

    final languageCode = _inDirectory(
      directory,
      AutomationLaunchLocaleFile.consume,
    );

    expect(languageCode, isNull);
    expect(directory.listSync(), isEmpty);
  });
}

T _inTemporaryDirectory<T>(T Function() body) {
  return _inDirectory(_createTemporaryDirectory(), body);
}

T _inDirectory<T>(Directory directory, T Function() body) {
  return IOOverrides.runZoned(body, getSystemTempDirectory: () => directory);
}

Directory _createTemporaryDirectory() {
  final directory = Directory.systemTemp.createTempSync('launch_locale_');

  addTearDown(() => directory.deleteSync(recursive: true));

  return directory;
}
