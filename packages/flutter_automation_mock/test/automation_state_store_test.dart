import 'dart:io';

import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_test/flutter_test.dart';

final _directory = Directory.systemTemp.createTempSync('automation_state');
final _sut = AutomationStateStore(_directory.path);

void main() {
  _setup();
  group('AutomationStateStore Tests', () {
    _automationStateStore_should_readTheDefaultStateWithoutAFile();
    _automationStateStore_should_readWhatItWroteAndKeepTheFile();
    _automationStateStore_should_readTheDefaultStateFromBrokenJson();
    _automationStateStore_should_leaveNoTemporaryFile();
    _automationStateStore_should_deleteTheStateOnReset();
    _automationStateStore_should_saveListAndDeletePresets();
    _automationStateStore_should_rejectAPresetNameWithASeparator();
    _automationStateStore_should_keepTheNewestRuns();
    _automationStateStore_should_keepTheRunItJustSaved();
    _automationStateStore_should_rejectDotNames();
    _automationStateStore_should_writeInParallelWithoutLoss();
  });
}

void _setup() {
  tearDown(() {
    for (final entity in _directory.listSync()) {
      entity.deleteSync(recursive: true);
    }
  });
  tearDownAll(() {
    _directory.deleteSync(recursive: true);
  });
}

void _automationStateStore_should_readTheDefaultStateWithoutAFile() {
  test(
    'AutomationStateStore should read the default state without a file',
    () async {
      final state = await _sut.read();

      expect(state.mode, AutomationMode.server);
      expect(state.scenario, isEmpty);
      expect(state.walk, isNull);
    },
  );
}

void _automationStateStore_should_readWhatItWroteAndKeepTheFile() {
  test(
    'AutomationStateStore should read what it wrote and keep the file',
    () async {
      await _sut.write(
        const AutomationState(
          mode: AutomationMode.mock,
          scenario: {'latency': 'fast'},
          walk: AutomationWalkProgress(
            flow: 'login',
            variant: 'otp',
            stepIndex: 1,
          ),
        ),
      );

      final first = await _sut.read();
      final second = await _sut.read();

      expect(first.mode, AutomationMode.mock);
      expect(first.scenario, {'latency': 'fast'});
      expect(second.walk?.variant, 'otp');
    },
  );
}

void _automationStateStore_should_readTheDefaultStateFromBrokenJson() {
  test(
    'AutomationStateStore should read the default state from broken json',
    () async {
      File('${_directory.path}/state.json').writeAsStringSync('{broken');

      final state = await _sut.read();

      expect(state.mode, AutomationMode.server);
    },
  );
}

void _automationStateStore_should_leaveNoTemporaryFile() {
  test('AutomationStateStore should leave no temporary file', () async {
    await _sut.write(const AutomationState(mode: AutomationMode.mock));

    final names = _directory
        .listSync()
        .map((entity) => entity.uri.pathSegments.last)
        .toList();

    expect(names, ['state.json']);
  });
}

void _automationStateStore_should_deleteTheStateOnReset() {
  test('AutomationStateStore should delete the state on reset', () async {
    await _sut.write(const AutomationState(mode: AutomationMode.mock));
    await _sut.reset();

    expect((await _sut.read()).mode, AutomationMode.server);
  });
}

void _automationStateStore_should_saveListAndDeletePresets() {
  test('AutomationStateStore should save list and delete presets', () async {
    await _sut.savePreset('b', {'latency': 'slow'});
    await _sut.savePreset('a', {'latency': 'fast'});

    expect(await _sut.listPresets(), ['a', 'b']);
    expect(await _sut.readPreset('a'), {'latency': 'fast'});

    await _sut.deletePreset('a');

    expect(await _sut.listPresets(), ['b']);
  });
}

void _automationStateStore_should_rejectAPresetNameWithASeparator() {
  test('AutomationStateStore should reject a preset name with a separator', () {
    expect(() => _sut.savePreset('../x', const {}), throwsArgumentError);
  });
}

void _automationStateStore_should_keepTheNewestRuns() {
  test('AutomationStateStore should keep the newest runs', () async {
    for (int index = 0; index < AutomationStateStore.maxRuns + 3; index += 1) {
      await _sut.saveRun('run-${index.toString().padLeft(3, '0')}', {
        'n': index,
      });
    }

    final runs = await _sut.listRuns();

    expect(runs, hasLength(AutomationStateStore.maxRuns));
    expect(runs.first, 'run-022');
    expect(runs.last, 'run-003');
    expect((await _sut.readRun('run-022'))['n'], 22);
  });
}

void _automationStateStore_should_keepTheRunItJustSaved() {
  test('AutomationStateStore should keep the run it just saved', () async {
    for (int index = 0; index < AutomationStateStore.maxRuns; index += 1) {
      await _sut.saveRun('run-${index.toString().padLeft(3, '0')}', {});
    }

    await _sut.saveRun('a-oldest-name', {'n': 1});

    final runs = await _sut.listRuns();

    expect(runs, hasLength(AutomationStateStore.maxRuns));
    expect(runs, contains('a-oldest-name'));
    expect((await _sut.readRun('a-oldest-name'))['n'], 1);
  });
}

void _automationStateStore_should_rejectDotNames() {
  test('AutomationStateStore should reject dot names', () {
    expect(() => _sut.savePreset('..', const {}), throwsArgumentError);
    expect(() => _sut.savePreset('.', const {}), throwsArgumentError);
    expect(() => _sut.saveRun('..', const {}), throwsArgumentError);
  });
}

void _automationStateStore_should_writeInParallelWithoutLoss() {
  test('AutomationStateStore should write in parallel without loss', () async {
    final other = AutomationStateStore(_directory.path);

    await Future.wait([
      _sut.write(const AutomationState(scenario: {'a': 1})),
      other.write(const AutomationState(scenario: {'b': 2})),
      _sut.update((state) => state.copyWith(mode: AutomationMode.mock)),
    ]);

    final state = await _sut.read();

    expect(state.scenario, {'b': 2});
    expect(state.mode, AutomationMode.mock);
    expect(_directory.listSync().map((e) => e.uri.pathSegments.last), [
      'state.json',
    ]);
  });
}
