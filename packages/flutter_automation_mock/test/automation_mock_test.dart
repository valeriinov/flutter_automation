import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

final _catalog = MockSection<Map<String, Object?>>(
  name: 'catalog',
  fromJson: _readJson,
);
final _launch = MockSection<Map<String, Object?>>(
  name: 'launch',
  fromJson: _readJson,
  restartKeys: {'isSignedIn'},
);
const _scenarioJson = <String, Object?>{
  'latency': 'fast',
  'failures': {
    '/items': {'statusCode': 500},
  },
  'catalog': {'itemCount': 0},
};

final _directory = Directory.systemTemp.createTempSync('automation_mock');
final _file = File('${_directory.path}/mock_scenario.json');
final _events = <String>[];
final _store = AutomationStateStore(_directory.path);
final _stateFile = File('${_directory.path}/state.json');

void main() {
  _setup();
  group('AutomationMock Tests', () {
    _automationMock_should_startFromTheSavedScenario();
    _automationMock_should_consumeTheScenarioFile();
    _automationMock_should_ignoreTheFileWhenDisabled();
    _automationMock_should_substituteTheFakeWhenEnabled();
    _automationMock_should_keepTheRealObjectWhenDisabled();
    _automationMock_should_readTheSettingsOfASection();
    _automationMock_should_saveTheScenarioOnApply();
    _automationMock_should_answerTheApplyCommand();
    _automationMock_should_runOnApplyAfterItsOwnPart();
    _automationMock_should_emptyTheJournalAfterOnApply();
    _automationMock_should_rejectAnApplyWithoutAConfig();
    _automationMock_should_readTheJournalAndEmptyIt();
    _automationMock_should_waitForTheAnswersBeforeReadingTheJournal();
    _automationMock_should_readTheLatencyProfileAndSeedOfTheScenario();
    _automationMock_should_defaultTheLatencyToRealisticWithSeedZero();
    _automationMock_should_readTheFailuresOfTheScenario();
    _automationMock_should_startWithoutSections();
    _automationMock_should_updateTheScenarioWithoutSeedingAgain();
    _automationMock_should_keepTheJournalOnUpdate();
    _automationMock_should_setAndRemoveAFailureKeepingTheOtherKeys();
    _automationMock_should_setAndRemoveALatencyKeepingTheOtherKeys();
    _automationMock_should_requireARestartForARestartKeyOnly();
    _automationMock_should_compareTheRestartKeysWithTheLaunchScenario();
    _automationMock_should_keepTheChoiceAcrossTwoColdStarts();
    _automationMock_should_preferTheAppliedScenarioFileToTheState();
    _automationMock_should_keepTheWalkAcrossColdStarts();
    _automationMock_should_keepTheModeOnSetFailure();
    _automationMock_should_startFromAnEmptyScenarioFileNotFromTheState();
    _automationMock_should_dropTheWalkWhenAScenarioFileStartsTheApp();
    _automationMock_should_keepTheOutcomeFailuresAcrossColdStarts();
    _automationMock_should_endTheWalkOnTheApplyCommand();
  });
}

void _setup() {
  tearDown(() {
    _events.clear();

    if (_file.existsSync()) {
      _file.deleteSync();
    }

    if (_stateFile.existsSync()) {
      _stateFile.deleteSync();
    }
  });
  tearDownAll(() {
    _directory.deleteSync(recursive: true);
  });
}

void _automationMock_should_startFromTheSavedScenario() {
  test('AutomationMock should start from the saved scenario', () async {
    await _file.writeAsString(jsonEncode(_scenarioJson));

    final mock = await _init();

    expect(mock.scenario.toJson(), _scenarioJson);
  });
}

void _automationMock_should_consumeTheScenarioFile() {
  test('AutomationMock should consume the scenario file', () async {
    await _file.writeAsString(jsonEncode(_scenarioJson));
    await _init();

    expect(_file.existsSync(), isFalse);
  });
}

void _automationMock_should_ignoreTheFileWhenDisabled() {
  test('AutomationMock should ignore the file when disabled', () async {
    await _file.writeAsString(jsonEncode(_scenarioJson));

    final mock = await _init(isEnabled: false);

    expect(mock.scenario.toJson(), isEmpty);
    expect(_file.existsSync(), isTrue);
  });
}

void _automationMock_should_substituteTheFakeWhenEnabled() {
  test('AutomationMock should substitute the fake when enabled', () async {
    final mock = await _init();

    final value = mock.substitute<String>(
      real: 'real',
      fake: (received) => received == mock ? 'fake' : 'foreign',
    );

    expect(value, 'fake');
  });
}

void _automationMock_should_keepTheRealObjectWhenDisabled() {
  test('AutomationMock should keep the real object when disabled', () async {
    final mock = await _init(isEnabled: false);

    final value = mock.substitute<String>(
      real: 'real',
      fake: (_) => throw StateError('The fake must not be built.'),
    );

    expect(value, 'real');
  });
}

void _automationMock_should_readTheSettingsOfASection() {
  test('AutomationMock should read the settings of a section', () async {
    await _file.writeAsString(jsonEncode(_scenarioJson));

    final mock = await _init();

    expect(mock.settingsOf(_catalog), {'itemCount': 0});
  });
}

void _automationMock_should_saveTheScenarioOnApply() {
  test('AutomationMock should save the scenario on apply', () async {
    final mock = await _init();

    await _send({'command': 'scenario.apply', 'scenario': _scenarioJson});

    expect(jsonDecode(_file.readAsStringSync()), _scenarioJson);
    expect(mock.scenario.toJson(), _scenarioJson);
  });
}

void _automationMock_should_answerTheApplyCommand() {
  test('AutomationMock should answer the apply command', () async {
    await _init();

    final answer = await _send({
      'command': 'scenario.apply',
      'scenario': _scenarioJson,
    });

    expect(jsonDecode(answer), {
      'latency': 'fast',
      'failures': ['/items'],
    });
  });
}

void _automationMock_should_runOnApplyAfterItsOwnPart() {
  test(
    'AutomationMock should run onScenarioApplied after its own part',
    () async {
      late AutomationMock mock;

      mock = await _init(
        onScenarioApplied: (scenario) {
          _events.add('onScenarioApplied saved=${_file.existsSync()}');
          _events.add('onScenarioApplied current=${mock.scenario == scenario}');
        },
      );
      await _send({'command': 'scenario.apply', 'scenario': _scenarioJson});

      expect(_events, [
        'onScenarioApplied saved=true',
        'onScenarioApplied current=true',
      ]);
    },
  );
}

void _automationMock_should_emptyTheJournalAfterOnApply() {
  test(
    'AutomationMock should empty the journal after onScenarioApplied',
    () async {
      late AutomationMock mock;

      mock = await _init(
        onScenarioApplied: (_) =>
            mock.journal.add(MockRequestRecordKind.request, {}),
      );
      await _send({'command': 'scenario.apply', 'scenario': _scenarioJson});

      final answer = await _send({'command': 'journal.read'});

      expect((jsonDecode(answer) as Map<String, Object?>)['records'], isEmpty);
    },
  );
}

void _automationMock_should_rejectAnApplyWithoutAConfig() {
  test('AutomationMock should reject an apply without a config', () async {
    await _init();

    expect(_send({'command': 'scenario.apply'}), throwsStateError);
  });
}

void _automationMock_should_readTheJournalAndEmptyIt() {
  test('AutomationMock should read the journal and empty it', () async {
    final mock = await _init();

    mock.journal
      ..add(MockRequestRecordKind.request, {'path': '/items'})
      ..recordLaunch(MockRequestRecordKind.request, {'path': '/launch'});

    final first = await _send({'command': 'journal.read'});
    final second = await _send({'command': 'journal.read'});

    expect(jsonDecode(first), {
      'records': [
        {'seq': 0, 'kind': 'request', 'path': '/items'},
      ],
      'launch': {'kind': 'request', 'path': '/launch'},
    });
    expect((jsonDecode(second) as Map<String, Object?>)['records'], isEmpty);
  });
}

void _automationMock_should_waitForTheAnswersBeforeReadingTheJournal() {
  test('AutomationMock should wait for the answers before reading '
      'the journal', () async {
    final mock = await _init(
      journalResponseTimeout: const Duration(milliseconds: 50),
    );

    mock.journal.addRequest({'path': '/items'});
    expect(_send({'command': 'journal.read'}), throwsStateError);
  });
}

void _automationMock_should_readTheLatencyProfileAndSeedOfTheScenario() {
  test(
    'AutomationMock should read the latency profile and seed of the scenario',
    () async {
      await _file.writeAsString(
        jsonEncode({'latency': 'realistic', 'latencySeed': 7}),
      );

      final mock = await _init();

      expect(mock.latency.profile, MockLatencyProfile.realistic);
      expect(
        _measureDelays(mock.latency),
        _measureDelays(
          MockLatency(profile: MockLatencyProfile.realistic, seed: 7),
        ),
      );
      expect(
        _measureDelays(mock.latency),
        isNot(
          _measureDelays(
            MockLatency(profile: MockLatencyProfile.slow, seed: 0),
          ),
        ),
      );
    },
  );
}

void _automationMock_should_defaultTheLatencyToRealisticWithSeedZero() {
  test(
    'AutomationMock should default the latency to realistic with seed zero',
    () async {
      final mock = await _init();

      expect(mock.latency.profile, MockLatencyProfile.realistic);

      await _file.writeAsString(jsonEncode({'latency': 'slow'}));

      final seeded = await _init();

      expect(
        _measureDelays(seeded.latency),
        _measureDelays(MockLatency(profile: MockLatencyProfile.slow, seed: 0)),
      );
    },
  );
}

void _automationMock_should_readTheFailuresOfTheScenario() {
  test('AutomationMock should read the failures of the scenario', () async {
    await _file.writeAsString(jsonEncode(_scenarioJson));

    final mock = await _init();

    expect(mock.failures.keys, ['/items']);
    expect(mock.failures['/items']?.statusCode, 500);
  });
}

void _automationMock_should_startWithoutSections() {
  test('AutomationMock should start without sections', () async {
    final mock = await AutomationMock.init(
      isEnabled: true,
      scenarioDirectory: _directory.path,
    );

    expect(mock.sections, isEmpty);
  });
}

void _automationMock_should_updateTheScenarioWithoutSeedingAgain() {
  test(
    'AutomationMock should update the scenario without seeding again',
    () async {
      final mock = await _init(
        onScenarioApplied: (_) => _events.add('applied'),
        onScenarioUpdated: (scenario) => _events.add('updated'),
      );

      await mock.updateScenario(MockScenario.fromJson(_scenarioJson));

      expect(mock.scenario.toJson(), _scenarioJson);
      expect(_events, ['updated']);
      expect(_file.existsSync(), isFalse);
      expect((await _store.read()).scenario, _scenarioJson);
    },
  );
}

void _automationMock_should_keepTheJournalOnUpdate() {
  test('AutomationMock should keep the journal on update', () async {
    final mock = await _init();

    mock.journal.add(MockRequestRecordKind.request, {'path': '/items'});

    await mock.updateScenario(MockScenario.fromJson(_scenarioJson));

    expect(mock.journal.records, hasLength(1));
  });
}

void _automationMock_should_setAndRemoveAFailureKeepingTheOtherKeys() {
  test(
    'AutomationMock should set and remove a failure keeping the other keys',
    () async {
      final mock = await _init();

      await mock.updateScenario(MockScenario.fromJson(_scenarioJson));
      await mock.setFailure(
        '/auth',
        const MockApiFailure(statusCode: 503, message: 'down'),
      );

      expect(mock.failures.keys, ['/items', '/auth']);
      expect(mock.failures['/auth']?.statusCode, 503);
      expect(mock.scenario.toJson()['latency'], 'fast');

      await mock.setFailure('/auth', null);
      await mock.setFailure('/items', null);

      expect(mock.failures, isEmpty);
      expect(mock.scenario.toJson().containsKey('failures'), isFalse);
      expect(mock.scenario.toJson()['catalog'], {'itemCount': 0});
    },
  );
}

void _automationMock_should_setAndRemoveALatencyKeepingTheOtherKeys() {
  test(
    'AutomationMock should set and remove a latency keeping the other keys',
    () async {
      final mock = await _init();

      await mock.updateScenario(MockScenario.fromJson(_scenarioJson));
      await mock.setLatency('/auth', MockLatencyProfile.slow);

      expect(mock.latencies, {'/auth': MockLatencyProfile.slow});
      expect(mock.failures.keys, ['/items']);
      expect(mock.scenario.toJson()['latency'], 'fast');

      await mock.setLatency('/auth', null);

      expect(mock.latencies, isEmpty);
      expect(mock.scenario.toJson().containsKey('latencies'), isFalse);
      expect(mock.scenario.toJson()['catalog'], {'itemCount': 0});
    },
  );
}

void _automationMock_should_requireARestartForARestartKeyOnly() {
  test(
    'AutomationMock should require a restart for a restart key only',
    () async {
      final mock = await _init();

      expect(
        mock.requiresRestart(
          MockScenario.fromJson({
            'failures': {'/items': {}},
          }),
        ),
        isFalse,
      );
      expect(
        mock.requiresRestart(
          MockScenario.fromJson({
            'launch': {'isSignedIn': true},
          }),
        ),
        isTrue,
      );
    },
  );
}

void _automationMock_should_compareTheRestartKeysWithTheLaunchScenario() {
  test(
    'AutomationMock should compare the restart keys with the launch scenario',
    () async {
      final mock = await _init();

      final changed = MockScenario.fromJson({
        'launch': {'isSignedIn': true},
      });

      await mock.updateScenario(changed);

      expect(mock.requiresRestart(changed), isTrue);
      expect(mock.requiresRestart(const MockScenario([])), isFalse);
    },
  );
}

void _automationMock_should_keepTheChoiceAcrossTwoColdStarts() {
  test(
    'AutomationMock should keep the choice across two cold starts',
    () async {
      final first = await _init();

      await first.updateScenario(MockScenario.fromJson(_scenarioJson));

      final second = await _init();
      final third = await _init();

      expect(second.scenario.toJson(), _scenarioJson);
      expect(third.scenario.toJson(), _scenarioJson);
    },
  );
}

void _automationMock_should_preferTheAppliedScenarioFileToTheState() {
  test(
    'AutomationMock should prefer the applied scenario file to the state',
    () async {
      await _store.write(const AutomationState(scenario: _scenarioJson));
      await _file.writeAsString(jsonEncode({'latency': 'slow'}));

      final mock = await _init();

      expect(mock.scenario.toJson(), {'latency': 'slow'});
    },
  );
}

void _automationMock_should_keepTheWalkAcrossColdStarts() {
  test('AutomationMock should keep the walk across cold starts', () async {
    final first = await _init();

    await first.saveWalk(
      const AutomationWalkProgress(flow: 'login', variant: 'otp', stepIndex: 2),
    );

    final second = await _init();

    expect(second.walk?.stepIndex, 2);
    expect(second.walk?.flow, 'login');
  });
}

void _automationMock_should_keepTheModeOnSetFailure() {
  test('AutomationMock should keep the mode on setFailure', () async {
    final mock = await _init();

    await _store.write(const AutomationState());
    await mock.setFailure('/items', const MockApiFailure(message: 'down'));

    expect((await _store.read()).mode, isNot(AutomationMode.mock));
    expect((await _store.read()).scenario, isNotEmpty);
  });
}

void _automationMock_should_startFromAnEmptyScenarioFileNotFromTheState() {
  test(
    'AutomationMock should start from an empty scenario file, not the state',
    () async {
      await _store.write(const AutomationState(scenario: _scenarioJson));
      await _file.writeAsString(jsonEncode(<String, Object?>{}));

      final mock = await _init();

      expect(mock.scenario.toJson(), isEmpty);
    },
  );
}

void _automationMock_should_dropTheWalkWhenAScenarioFileStartsTheApp() {
  test(
    'AutomationMock should drop the walk when a scenario file starts the app',
    () async {
      await _store.write(
        const AutomationState(
          walk: AutomationWalkProgress(flow: 'login', variant: 'otp'),
          outcomeFailures: {
            '/items': {'statusCode': 500},
          },
        ),
      );
      await _file.writeAsString(jsonEncode(<String, Object?>{}));

      final mock = await _init();

      expect(mock.walk, isNull);
      expect(mock.outcomeFailures, isEmpty);
    },
  );
}

void _automationMock_should_keepTheOutcomeFailuresAcrossColdStarts() {
  test(
    'AutomationMock should keep the outcome failures across cold starts',
    () async {
      const failures = {
        '/items': {'statusCode': 500},
      };

      final first = await _init();

      await first.saveOutcomeFailures(failures);

      final second = await _init();

      expect(second.outcomeFailures, failures);
    },
  );
}

void _automationMock_should_endTheWalkOnTheApplyCommand() {
  test('AutomationMock should end the walk on the apply command', () async {
    final mock = await _init();

    await mock.saveWalk(
      const AutomationWalkProgress(flow: 'login', variant: 'otp'),
    );
    await mock.saveOutcomeFailures(const {
      '/items': {'statusCode': 500},
    });
    await _send({'command': 'scenario.apply', 'scenario': _scenarioJson});

    final state = await _store.read();

    expect(mock.walk, isNull);
    expect(state.walk, isNull);
    expect(state.outcomeFailures, isEmpty);
  });
}

List<Duration> _measureDelays(MockLatency latency) {
  final delays = <Duration>[];

  fakeAsync((async) {
    for (int index = 0; index < 5; index += 1) {
      final start = async.elapsed;
      Duration end = start;

      latency.waitOut().then((_) => end = async.elapsed);
      async.elapse(const Duration(seconds: 1));
      delays.add(end - start);
    }
  });

  return delays;
}

Future<AutomationMock> _init({
  bool isEnabled = true,
  MockScenarioAppliedCallback? onScenarioApplied,
  MockScenarioUpdatedCallback? onScenarioUpdated,
  Duration journalResponseTimeout = const Duration(seconds: 10),
}) {
  return AutomationMock.init(
    isEnabled: isEnabled,
    scenarioDirectory: _directory.path,
    stateStore: _store,
    sections: [_catalog, _launch],
    onScenarioApplied: onScenarioApplied,
    onScenarioUpdated: onScenarioUpdated,
    journalResponseTimeout: journalResponseTimeout,
  );
}

Future<String> _send(Map<String, Object?> payload) {
  return AutomationCommandRegistry.handle(jsonEncode(payload));
}

Map<String, Object?> _readJson(Map<String, Object?> json) => json;
