import 'dart:io';

import 'package:flutter_automation_mock/src/mock_scenario_file.dart';
import 'package:flutter_test/flutter_test.dart';

final _directory = Directory.systemTemp.createTempSync('mock_scenario_file');
final _file = File('${_directory.path}/mock_scenario.json');

void main() {
  _setup();
  group('MockScenarioFile Tests', () {
    _mockScenarioFile_should_consumeWhatItSaved();
    _mockScenarioFile_should_removeTheFileAfterConsuming();
    _mockScenarioFile_should_answerAnEmptyObjectWithoutAFile();
    _mockScenarioFile_should_answerAnEmptyObjectForBrokenJson();
    _mockScenarioFile_should_answerAnEmptyObjectForANonObject();
  });
}

void _setup() {
  tearDown(() {
    if (_file.existsSync()) {
      _file.deleteSync();
    }
  });
  tearDownAll(() {
    _directory.deleteSync(recursive: true);
  });
}

void _mockScenarioFile_should_consumeWhatItSaved() {
  test('MockScenarioFile should consume what it saved', () async {
    await MockScenarioFile.save(_directory.path, {
      'latency': 'fast',
      'catalog': {'itemCount': 0},
    });

    final json = await MockScenarioFile.consume(_directory.path);

    expect(json, {
      'latency': 'fast',
      'catalog': {'itemCount': 0},
    });
  });
}

void _mockScenarioFile_should_removeTheFileAfterConsuming() {
  test('MockScenarioFile should remove the file after consuming', () async {
    await MockScenarioFile.save(_directory.path, {'latency': 'fast'});
    await MockScenarioFile.consume(_directory.path);

    expect(_file.existsSync(), isFalse);
  });
}

void _mockScenarioFile_should_answerAnEmptyObjectWithoutAFile() {
  test(
    'MockScenarioFile should answer an empty object without a file',
    () async {
      final json = await MockScenarioFile.consume(_directory.path);

      expect(json, isEmpty);
    },
  );
}

void _mockScenarioFile_should_answerAnEmptyObjectForBrokenJson() {
  test(
    'MockScenarioFile should answer an empty object for broken json',
    () async {
      await _file.writeAsString('{not json');

      final json = await MockScenarioFile.consume(_directory.path);

      expect(json, isEmpty);
      expect(_file.existsSync(), isFalse);
    },
  );
}

void _mockScenarioFile_should_answerAnEmptyObjectForANonObject() {
  test(
    'MockScenarioFile should answer an empty object for a non object',
    () async {
      await _file.writeAsString('[1, 2]');

      final json = await MockScenarioFile.consume(_directory.path);

      expect(json, isEmpty);
    },
  );
}
