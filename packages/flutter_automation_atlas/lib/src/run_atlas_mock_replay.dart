import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_mock/flutter_automation_mock.dart';

import 'package:flutter_automation_atlas/src/atlas_journal_schema.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_answer_comparison.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replay.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replayer.dart';

/// {@category Utils}
///
/// Builds the apis of the [mock] that a replay asks again.
typedef AtlasMockApisBuilder = List<MockApi> Function(AutomationMock mock);

/// {@category Utils}
///
/// Whether this `flutter test` run is a mock replay that the atlas started:
/// [AtlasMockReplayProcess] sets the define of its input file.
const isAtlasMockReplayRun = bool.hasEnvironment(
  AtlasMockReplayProcess.inputDefine,
);

const _inputPath = String.fromEnvironment(AtlasMockReplayProcess.inputDefine);
const _outputPath = String.fromEnvironment(AtlasMockReplayProcess.outputDefine);

/// {@category Utils}
///
/// The body of the `flutter test` file that [AtlasMockReplayProcess] runs:
/// asks the mock of the app again for every answer a snapshot recorded.
///
/// Reads the snapshots from the file of [AtlasMockReplayProcess.inputDefine].
/// For each one it starts a mock with the [sections] parameter and the
/// scenario of the snapshot, and asks the apis that the [apis] parameter
/// builds for every recorded request. The [schema] parameter is the journal
/// schema of the project, which [AtlasMockAnswerComparison] compares the
/// answers by. It writes one [AtlasMockReplayOutcome] for each snapshot to the
/// file of [AtlasMockReplayProcess.outputDefine].
Future<void> runAtlasMockReplay({
  required List<MockSection<Object?>> sections,
  required AtlasMockApisBuilder apis,
  required AtlasJournalSchema schema,
}) async {
  final replay = _MockReplay(
    sections: sections,
    apis: apis,
    comparison: AtlasMockAnswerComparison(schema),
  );
  final inputs = AtlasMockReplayInput.readAll(
    File(_inputPath).readAsStringSync(),
  );
  final outcomes = {
    for (final input in inputs) input.id: await replay.run(input),
  };

  File(_outputPath).writeAsStringSync(
    jsonEncode({
      for (final MapEntry(:key, :value) in outcomes.entries)
        key: value.toJson(),
    }),
  );
}

final class _MockReplay {
  static const _directoryPrefix = 'atlas_replay';

  final List<MockSection<Object?>> sections;
  final AtlasMockApisBuilder apis;
  final AtlasMockAnswerComparison comparison;

  const _MockReplay({
    required this.sections,
    required this.apis,
    required this.comparison,
  });

  Future<AtlasMockReplayOutcome> run(AtlasMockReplayInput input) async {
    final directory = Directory.systemTemp.createTempSync(_directoryPrefix);

    try {
      final mock = await AutomationMock.init(
        isEnabled: true,
        scenarioDirectory: directory.path,
        sections: sections,
      );

      await mock.updateScenario(MockScenario.fromJson(input.scenario));

      final endpoints = MockApiEndpointResolver(apis(mock));
      final responses = [
        for (final answer in input.answers)
          await _respond(endpoints, answer.record),
      ];

      return AtlasMockReplayer(input, (input, timing) {
        return [
          for (final (index, answer) in input.answers.indexed)
            _describeAnswer(answer, responses[index], timing),
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

    return endpoints
        .tryResolve(path)
        ?.respond(
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
    AtlasReplayTiming timing,
  ) {
    final recorded = answer.record;

    return AtlasReplayedAnswer(
      stage: answer.stage,
      request: '${recorded['method']} ${recorded['path']}',
      difference: comparison.compare(
        recorded: recorded,
        replayed: {
          'kind': recorded['kind'],
          'status': response?.statusCode,
          'response': response?.body,
        },
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
}
