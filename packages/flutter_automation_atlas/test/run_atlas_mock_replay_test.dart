import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_mock_replay.dart';
import 'package:flutter_automation_atlas/src/run_atlas_mock_replay.dart';

import 'test_utils/fake_atlas_project.dart';

void main() {
  group('runAtlasMockReplayFiles Tests', () {
    _runAtlasMockReplayFiles_should_askStatefulEndpointOncePerInput();
    _runAtlasMockReplayFiles_should_tellRequestNoEndpointAnswered();
    _runAtlasMockReplayFiles_should_failOnlyTheAnswerWhoseResponderThrew();
  });
}

void _runAtlasMockReplayFiles_should_askStatefulEndpointOncePerInput() {
  test('runAtlasMockReplayFiles should ask a stateful endpoint once per '
      'input', () async {
    final outcome = await _replay(
      const AtlasMockReplayInput(
        id: 'shop_flow/shopFromSearch',
        scenario: {},
        locale: 'uk',
        stageMoments: [
          (anchor: '2026-10-06T09:00:00.000Z', launchedAt: null),
          (anchor: '2026-10-07T09:00:00.000Z', launchedAt: null),
        ],
        answers: [
          AtlasRecordedAnswer(
            stage: 0,
            record: {
              'kind': 'request',
              'method': 'POST',
              'path': '/items',
              'status': 200,
              'response': {'count': 1},
            },
          ),
          AtlasRecordedAnswer(
            stage: 1,
            record: {
              'kind': 'request',
              'method': 'GET',
              'path': '/items',
              'status': 200,
              'response': {'count': 1},
            },
          ),
        ],
      ),
    );

    expect(outcome.stage, isNull);
    expect(outcome.difference, isNull);
  });
}

void _runAtlasMockReplayFiles_should_tellRequestNoEndpointAnswered() {
  test('runAtlasMockReplayFiles should tell a request no endpoint '
      'answered', () async {
    final outcome = await _replay(
      const AtlasMockReplayInput(
        id: 'shop_flow/shopFromSearch',
        scenario: {},
        locale: 'uk',
        answers: [
          AtlasRecordedAnswer(
            stage: 0,
            record: {
              'kind': 'request',
              'method': 'GET',
              'path': '/unknown',
              'status': 200,
              'response': {'count': 1},
            },
          ),
        ],
      ),
    );

    expect(outcome.difference, contains('answered nothing'));
  });
}

void _runAtlasMockReplayFiles_should_failOnlyTheAnswerWhoseResponderThrew() {
  test('runAtlasMockReplayFiles should fail only the answer whose responder '
      'threw', () async {
    final outcome = await _replay(
      const AtlasMockReplayInput(
        id: 'shop_flow/shopFromSearch',
        scenario: {},
        locale: 'uk',
        answers: [
          AtlasRecordedAnswer(
            stage: 0,
            record: {
              'kind': 'request',
              'method': 'GET',
              'path': '/broken',
              'status': 200,
              'response': {'count': 1},
            },
          ),
        ],
      ),
    );

    expect(outcome.difference, contains('failed:'));
  });
}

Future<AtlasMockReplayOutcome> _replay(AtlasMockReplayInput input) async {
  final directory = Directory.systemTemp.createTempSync('run_replay_test');

  addTearDown(() => directory.deleteSync(recursive: true));

  final inputFile = File('${directory.path}/input.json')
    ..writeAsStringSync(jsonEncode([input.toJson()]));
  final outputFile = File('${directory.path}/output.json');

  await runAtlasMockReplayFiles(
    inputPath: inputFile.path,
    outputPath: outputFile.path,
    schema: fakeAtlasJournalSchema,
    apis: (_) => [_ItemsApi()],
  );

  return AtlasMockReplayOutcome.readAll(
    outputFile.readAsStringSync(),
  )[input.id]!;
}

final class _ItemsApi implements MockApi {
  int _count = 0;

  @override
  List<MockApiEndpoint> get endpoints => [
    MockApiEndpoint(
      path: '/items',
      title: AutomationLocalizedText({'en': 'Items'}),
      respond: _respond,
    ),
    MockApiEndpoint(
      path: '/broken',
      title: AutomationLocalizedText({'en': 'Broken'}),
      respond: (_) => throw StateError('broken responder'),
    ),
  ];

  MockApiResponse _respond(MockApiRequest request) {
    if (request.method == 'POST') {
      _count++;
    }

    return MockApiResponse(body: {'count': _count});
  }
}
