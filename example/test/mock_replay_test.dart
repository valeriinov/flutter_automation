import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_atlas/mock_replay.dart';
import 'package:flutter_automation_atlas/src/run_atlas_mock_replay.dart'
    show runAtlasMockReplayFiles;
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/mock/catalog_mock_section.dart';
import 'package:example/mock/mock_catalog_api.dart';

import '../tool/example_atlas_project.dart';

const _replayId = 'catalog/items';

/// The `flutter test` file of `AtlasProject.mockReplayEntry`. It asks the mock
/// of the app again for each answer that a snapshot recorded.
void main() {
  test('Mock replay should write the outcome of each snapshot', () async {
    final mock = await _initMock();

    return runAtlasMockReplay(
      schema: const ExampleAtlasProject().journalSchema,
      session: (context) => _ExampleMockSession(mock, context),
    );
  }, skip: !isAtlasMockReplayRun);
  group('Example mock session', () {
    _exampleMockSession_should_replayAnswerOfScenario();
    _exampleMockSession_should_replayFailureOfScenario();
    _exampleMockSession_should_tellDifferentStatus();
  });
}

void _exampleMockSession_should_replayAnswerOfScenario() {
  test(
    'Example mock session should replay the answer of the scenario',
    () async {
      final outcome = await _replayRecorded(
        scenario: {
          'catalogSection': {'itemCount': 2},
        },
        record: _itemsRecord(
          status: 200,
          response: {
            'items': [
              {'id': 1, 'title': 'Item 1'},
              {'id': 2, 'title': 'Item 2'},
            ],
          },
        ),
      );

      expect(outcome['difference'], isNull);
    },
  );
}

void _exampleMockSession_should_replayFailureOfScenario() {
  test('Example mock session should replay a failure that the scenario '
      'names', () async {
    final outcome = await _replayRecorded(
      scenario: {
        'failures': {
          '/catalog/items': {'statusCode': 429, 'errorCode': 'rateLimited'},
        },
      },
      record: _itemsRecord(
        status: 429,
        response: {'code': 'rateLimited'},
        override: {'failure': true},
      ),
    );

    expect(outcome['difference'], isNull);
  });
}

void _exampleMockSession_should_tellDifferentStatus() {
  test(
    'Example mock session should tell an answer with another status',
    () async {
      final outcome = await _replayRecorded(
        scenario: {
          'failures': {
            '/catalog/items': {'statusCode': 429, 'errorCode': 'rateLimited'},
          },
        },
        record: _itemsRecord(status: 200, response: {'items': <Object?>[]}),
      );

      expect(outcome['difference'], isNotNull);
    },
  );
}

Map<String, Object?> _itemsRecord({
  required int status,
  required Map<String, Object?> response,
  Map<String, Object?>? override,
}) {
  return {
    'kind': 'request',
    'method': 'GET',
    'path': '/catalog/items',
    'status': status,
    'response': response,
    'override': ?override,
  };
}

Future<Map<String, Object?>> _replayRecorded({
  required Map<String, Object?> scenario,
  required Map<String, Object?> record,
}) async {
  final directory = Directory.systemTemp.createTempSync('example_replay_io');

  addTearDown(() => directory.deleteSync(recursive: true));

  final input = File('${directory.path}/input.json')
    ..writeAsStringSync(
      jsonEncode([
        {
          'id': _replayId,
          'scenario': scenario,
          'locale': 'en',
          'answers': [
            {'stage': 0, 'record': record},
          ],
          'stageMoments': const <Object?>[],
        },
      ]),
    );
  final output = File('${directory.path}/output.json');

  await _replay(inputPath: input.path, outputPath: output.path);

  final outcomes = jsonDecode(output.readAsStringSync());

  return (outcomes as Map<String, Object?>)[_replayId] as Map<String, Object?>;
}

Future<void> _replay({
  required String inputPath,
  required String outputPath,
}) async {
  final mock = await _initMock();

  return runAtlasMockReplayFiles(
    inputPath: inputPath,
    outputPath: outputPath,
    schema: const ExampleAtlasProject().journalSchema,
    session: (context) => _ExampleMockSession(mock, context),
  );
}

Future<AutomationMock> _initMock() async {
  final directory = Directory.systemTemp.createTempSync('example_replay');

  addTearDown(() => directory.deleteSync(recursive: true));

  return AutomationMock.init(
    isEnabled: true,
    scenarioDirectory: directory.path,
    sections: [catalogMockSection],
  );
}

final class _ExampleMockSession extends AtlasMockSession {
  final AutomationMock _mock;
  final MockApiTransport _transport;

  _ExampleMockSession(this._mock, AtlasMockSessionContext context)
    : _transport = MockApiTransport(
        backend: MockScenarioBackend(
          readScenario: () => _mock.scenario,
          buildApis: () => [MockCatalogApi(_mock)],
          buildFailureBody: (failure, request) => {'code': failure.errorCode},
        ),
        journal: _mock.journal,
      ) {
    // The scenario is set before updateScenario first waits.
    _mock.updateScenario(MockScenario.fromJson(context.scenario));
  }

  @override
  Future<Object?> ask(Map<String, Object?> record) {
    return _transport.answer(
      MockApiRequest(
        path: '${record['path']}',
        method: '${record['method']}',
        body: _readBody(record['body']),
      ),
    );
  }

  @override
  List<Map<String, Object?>> takeJournal() => _mock.journal.readAndClear();

  @override
  Map<String, Object?>? findReplayed(
    Map<String, Object?> record,
    List<Map<String, Object?>> journal,
  ) {
    return journal
        .where(
          (replayed) =>
              replayed['path'] == record['path'] &&
              replayed['method'] == record['method'],
        )
        .lastOrNull;
  }

  @override
  String describe(Map<String, Object?> record) {
    return '${record['method']} ${record['path']}';
  }

  @override
  Future<void> close() async {}

  Map<String, Object?> _readBody(Object? body) {
    return switch (body) {
      final Map<String, Object?> map => map,
      _ => const {},
    };
  }
}
