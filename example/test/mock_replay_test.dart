import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/mock/catalog_mock_section.dart';
import 'package:example/mock/mock_catalog_api.dart';

import '../tool/example_atlas_project.dart';

const _inputPath = String.fromEnvironment(AtlasMockReplayProcess.inputDefine);
const _outputPath = String.fromEnvironment(AtlasMockReplayProcess.outputDefine);

/// The `flutter test` file of `AtlasProject.mockReplayEntry`: it asks the mock
/// of the app again for every answer a snapshot recorded.
void main() {
  test('Mock replay should write the outcome of each snapshot', () async {
    final inputs = AtlasMockReplayInput.readAll(
      File(_inputPath).readAsStringSync(),
    );
    final outcomes = <String, AtlasMockReplayOutcome>{};

    for (final input in inputs) {
      outcomes[input.id] = await _replay(input);
    }

    File(_outputPath).writeAsStringSync(
      jsonEncode({
        for (final MapEntry(:key, :value) in outcomes.entries)
          key: value.toJson(),
      }),
    );
  }, skip: _inputPath.isEmpty);
}

Future<AtlasMockReplayOutcome> _replay(AtlasMockReplayInput input) async {
  final directory = Directory.systemTemp.createTempSync('atlas_replay');

  try {
    final mock = await AutomationMock.init(
      isEnabled: true,
      scenarioDirectory: directory.path,
      sections: [catalogMockSection],
    );

    await mock.updateScenario(MockScenario.fromJson(input.scenario));

    final endpoints = MockApiEndpointResolver([MockCatalogApi(mock)]);
    final comparison = AtlasMockAnswerComparison(
      const ExampleAtlasProject().journalSchema,
    );
    final responses = [
      for (final answer in input.answers)
        await _respond(endpoints, answer.record),
    ];

    return AtlasMockReplayer(input, (input, timing) {
      return [
        for (final (index, answer) in input.answers.indexed)
          _describeAnswer(answer, responses[index], comparison, timing),
      ];
    }).replay();
  } finally {
    directory.deleteSync(recursive: true);
  }
}

Future<MockApiResponse?> _respond(
  MockApiEndpointResolver endpoints,
  Map<String, Object?> recorded,
) async {
  final path = '${recorded['path']}';
  final endpoint = endpoints.tryResolve(path);

  return endpoint?.respond(
    MockApiRequest(
      path: path,
      method: '${recorded['method']}',
      body: _readBody(recorded['body']),
    ),
  );
}

AtlasReplayedAnswer _describeAnswer(
  AtlasRecordedAnswer answer,
  MockApiResponse? response,
  AtlasMockAnswerComparison comparison,
  AtlasReplayTiming timing,
) {
  final recorded = answer.record;
  final path = '${recorded['path']}';
  final method = '${recorded['method']}';
  final replayed = {
    'kind': recorded['kind'],
    'status': response?.statusCode,
    'response': response?.body,
  };

  return AtlasReplayedAnswer(
    stage: answer.stage,
    request: '$method $path',
    difference: comparison.compare(
      recorded: recorded,
      replayed: replayed,
      hasKnownMoments: timing.launchedAt != null,
    ),
  );
}

Map<String, Object?> _readBody(Object? body) {
  return switch (body) {
    final Map<String, Object?> map => map,
    _ => const {},
  };
}
