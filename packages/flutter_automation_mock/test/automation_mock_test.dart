import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = MockFeature<Map<String, Object?>>(
  name: 'catalog',
  fromJson: _readJson,
  profiles: {
    'empty': {'itemCount': 0},
  },
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

void main() {
  _setup();
  group('AutomationMock Tests', () {
    _automationMock_should_startFromTheSavedScenario();
    _automationMock_should_consumeTheScenarioFile();
    _automationMock_should_ignoreTheFileWhenDisabled();
    _automationMock_should_substituteTheFakeWhenEnabled();
    _automationMock_should_keepTheRealObjectWhenDisabled();
    _automationMock_should_readTheSettingsOfAFeature();
    _automationMock_should_saveTheScenarioOnApply();
    _automationMock_should_answerTheApplyCommand();
    _automationMock_should_runOnApplyAfterItsOwnPart();
    _automationMock_should_emptyTheJournalAfterOnApply();
    _automationMock_should_rejectAnApplyWithoutAConfig();
    _automationMock_should_readTheJournalAndEmptyIt();
    _automationMock_should_waitForTheAnswersBeforeReadingTheJournal();
    _automationMock_should_readTheTextsOfTheFrame();
    _automationMock_should_takeTheLanguageOnLocaleApply();
    _automationMock_should_runOnLocaleAfterItsOwnPart();
    _automationMock_should_rejectALocaleWithoutALanguageCode();
    _automationMock_should_failTheLocaleCommandWithTheCallback();
    _automationMock_should_readTheLatencyProfileAndSeedOfTheScenario();
    _automationMock_should_defaultTheLatencyToRealisticWithSeedZero();
    _automationMock_should_readTheFailuresOfTheScenario();
    _automationMock_should_startWithoutFeatures();
  });
}

void _setup() {
  tearDown(() {
    _events.clear();

    if (_file.existsSync()) {
      _file.deleteSync();
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

void _automationMock_should_readTheSettingsOfAFeature() {
  test('AutomationMock should read the settings of a feature', () async {
    await _file.writeAsString(jsonEncode(_scenarioJson));

    final mock = await _init();

    expect(mock.settingsOf(_catalog), {'itemCount': 0});
  });
}

void _automationMock_should_saveTheScenarioOnApply() {
  test('AutomationMock should save the scenario on apply', () async {
    final mock = await _init();

    await _send({'command': 'mock.apply', 'config': _scenarioJson});

    expect(jsonDecode(_file.readAsStringSync()), _scenarioJson);
    expect(mock.scenario.toJson(), _scenarioJson);
  });
}

void _automationMock_should_answerTheApplyCommand() {
  test('AutomationMock should answer the apply command', () async {
    await _init();

    final answer = await _send({
      'command': 'mock.apply',
      'config': _scenarioJson,
    });

    expect(jsonDecode(answer), {
      'latency': 'fast',
      'failures': ['/items'],
    });
  });
}

void _automationMock_should_runOnApplyAfterItsOwnPart() {
  test('AutomationMock should run onApply after its own part', () async {
    late AutomationMock mock;

    mock = await _init(
      onApply: (scenario) {
        _events.add('onApply saved=${_file.existsSync()}');
        _events.add('onApply current=${mock.scenario == scenario}');
      },
    );
    await _send({'command': 'mock.apply', 'config': _scenarioJson});

    expect(_events, ['onApply saved=true', 'onApply current=true']);
  });
}

void _automationMock_should_emptyTheJournalAfterOnApply() {
  test('AutomationMock should empty the journal after onApply', () async {
    late AutomationMock mock;

    mock = await _init(
      onApply: (_) => mock.journal.add(MockRequestRecordKind.request, {}),
    );
    await _send({'command': 'mock.apply', 'config': _scenarioJson});

    final answer = await _send({'command': 'journal.read'});

    expect((jsonDecode(answer) as Map<String, Object?>)['records'], isEmpty);
  });
}

void _automationMock_should_rejectAnApplyWithoutAConfig() {
  test('AutomationMock should reject an apply without a config', () async {
    await _init();

    expect(_send({'command': 'mock.apply'}), throwsStateError);
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

void _automationMock_should_readTheTextsOfTheFrame() {
  testWidgets('AutomationMock should read the texts of the frame', (
    tester,
  ) async {
    await tester.runAsync(_init);
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: Text('Hi')),
    );

    final answer = await tester.runAsync(
      () => _send({'command': 'journal.read', 'texts': true}),
    );

    final json = jsonDecode(answer ?? '{}') as Map<String, Object?>;

    expect(json['texts'], ['Hi']);
    expect(json.containsKey('widgets'), isFalse);
  });
}

void _automationMock_should_takeTheLanguageOnLocaleApply() {
  test('AutomationMock should take the language on locale apply', () async {
    final mock = await _init();
    final answer = await _send({'command': 'locale.apply', 'locale': 'uk'});

    expect(jsonDecode(answer), {'locale': 'uk'});
    expect(mock.languageCode, 'uk');
  });
}

void _automationMock_should_runOnLocaleAfterItsOwnPart() {
  test('AutomationMock should run onLocale after its own part', () async {
    late AutomationMock mock;

    mock = await _init(
      onLocale: (languageCode) {
        _events.add('onLocale own=${mock.languageCode} given=$languageCode');
      },
    );
    await _send({'command': 'locale.apply', 'locale': 'uk'});

    expect(_events, ['onLocale own=uk given=uk']);
  });
}

void _automationMock_should_rejectALocaleWithoutALanguageCode() {
  test(
    'AutomationMock should reject a locale without a language code',
    () async {
      await _init();

      expect(_send({'command': 'locale.apply'}), throwsStateError);
    },
  );
}

void _automationMock_should_failTheLocaleCommandWithTheCallback() {
  test(
    'AutomationMock should fail the locale command with the callback',
    () async {
      await _init(onLocale: (_) => throw StateError('Unsupported language.'));

      expect(
        _send({'command': 'locale.apply', 'locale': 'xx'}),
        throwsStateError,
      );
    },
  );
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

void _automationMock_should_startWithoutFeatures() {
  test('AutomationMock should start without features', () async {
    final mock = await AutomationMock.init(
      isEnabled: true,
      scenarioDirectory: _directory.path,
    );

    expect(mock.features, isEmpty);
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
  MockApplyCallback? onApply,
  MockLocaleCallback? onLocale,
  Duration journalResponseTimeout = const Duration(seconds: 10),
}) {
  return AutomationMock.init(
    isEnabled: isEnabled,
    scenarioDirectory: _directory.path,
    features: const [_catalog],
    onApply: onApply,
    onLocale: onLocale,
    journalResponseTimeout: journalResponseTimeout,
  );
}

Future<String> _send(Map<String, Object?> payload) {
  return AutomationCommandHandler.handle(jsonEncode(payload));
}

Map<String, Object?> _readJson(Map<String, Object?> json) => json;
