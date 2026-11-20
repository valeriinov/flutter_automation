import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_mock/flutter_automation_mock.dart';

import 'package:flutter_automation_atlas/src/atlas_journal_schema.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_answer_comparison.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replay.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replayer.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_session.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_session_run.dart';

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
/// The body of the `flutter test` file that [AtlasMockReplayProcess] runs.
/// It asks the mock of the app again for each answer that a snapshot
/// recorded.
///
/// It reads the snapshots from the file of
/// [AtlasMockReplayProcess.inputDefine]. Each snapshot replays through an
/// [AtlasMockSession] that the [session] parameter builds. The replay walks
/// it in a `FakeAsync` zone. Without [session], the replay starts a mock with
/// the [sections] parameter and the scenario of the snapshot. It asks the
/// apis that the [apis] parameter builds for each recorded request. The
/// [schema] parameter is the journal schema of the project.
/// [AtlasMockAnswerComparison] compares the answers with it. It writes one
/// [AtlasMockReplayOutcome] for each snapshot to the file of
/// [AtlasMockReplayProcess.outputDefine].
Future<void> runAtlasMockReplay({
  required AtlasJournalSchema schema,
  AtlasMockSessionFactory? session,
  List<MockSection<Object?>> sections = const [],
  AtlasMockApisBuilder? apis,
}) {
  return runAtlasMockReplayFiles(
    inputPath: _inputPath,
    outputPath: _outputPath,
    schema: schema,
    session: session,
    sections: sections,
    apis: apis,
  );
}

/// {@category Utils}
///
/// [runAtlasMockReplay] with the paths of the input and the output file given
/// instead of read from the defines.
Future<void> runAtlasMockReplayFiles({
  required String inputPath,
  required String outputPath,
  required AtlasJournalSchema schema,
  AtlasMockSessionFactory? session,
  List<MockSection<Object?>> sections = const [],
  AtlasMockApisBuilder? apis,
}) async {
  assert((session == null) != (apis == null), 'Pass either session or apis.');

  final replay = _MockReplay(
    schema: schema,
    session: session,
    sections: sections,
    apis: apis,
  );
  final inputs = AtlasMockReplayInput.readAll(
    File(inputPath).readAsStringSync(),
  );
  final outcomes = {
    for (final input in inputs) input.id: await replay.run(input),
  };

  File(outputPath).writeAsStringSync(
    jsonEncode({
      for (final MapEntry(:key, :value) in outcomes.entries)
        key: value.toJson(),
    }),
  );
}

final class _MockReplay {
  static const _directoryPrefix = 'atlas_replay';

  final AtlasJournalSchema schema;
  final AtlasMockSessionFactory? session;
  final List<MockSection<Object?>> sections;
  final AtlasMockApisBuilder? apis;

  const _MockReplay({
    required this.schema,
    required this.session,
    required this.sections,
    required this.apis,
  });

  Future<AtlasMockReplayOutcome> run(AtlasMockReplayInput input) async {
    final sessionFactory = session;

    if (sessionFactory != null) {
      return _replay(input, sessionFactory);
    }

    final directory = Directory.systemTemp.createTempSync(_directoryPrefix);

    try {
      final mock = await AutomationMock.init(
        isEnabled: true,
        scenarioDirectory: directory.path,
        sections: sections,
      );

      await mock.updateScenario(MockScenario.fromJson(input.scenario));

      final endpoints = MockApiEndpointResolver(apis?.call(mock) ?? const []);
      final responses = [
        for (final answer in input.answers)
          await _tryRespond(endpoints, answer.record),
      ];

      return _replay(input, (_) => _MockApiSession(responses));
    } finally {
      directory.deleteSync(recursive: true);
    }
  }

  AtlasMockReplayOutcome _replay(
    AtlasMockReplayInput input,
    AtlasMockSessionFactory sessionFactory,
  ) {
    return AtlasMockReplayer(
      input,
      (input, timing) =>
          AtlasMockSessionRun(input, timing, sessionFactory, schema).run(),
    ).replay();
  }

  Future<_MockApiAnswer> _tryRespond(
    MockApiEndpointResolver endpoints,
    Map<String, Object?> recorded,
  ) async {
    try {
      return _MockApiAnswer(response: await _respond(endpoints, recorded));
    } on Object catch (error, stackTrace) {
      return _MockApiAnswer(error: error, stackTrace: stackTrace);
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

  Map<String, Object?> _readBody(Object? body) {
    return switch (body) {
      final Map<String, Object?> map => map,
      _ => const {},
    };
  }
}

/// What an endpoint gave for one recorded request: a response, or the error
/// that its responder threw.
final class _MockApiAnswer {
  final MockApiResponse? response;
  final Object? error;
  final StackTrace? stackTrace;

  const _MockApiAnswer({this.response, this.error, this.stackTrace});
}

/// Serves the responses that the endpoints gave once, in real time, to each
/// asked record in the order of the snapshot, so every timing replays the same
/// answers.
final class _MockApiSession extends AtlasMockSession {
  final List<_MockApiAnswer> _answers;

  int _asked = 0;
  MockApiResponse? _response;

  _MockApiSession(this._answers);

  @override
  Future<Object?> ask(Map<String, Object?> record) async {
    final answer = _answers.elementAtOrNull(_asked++);
    final error = answer?.error;

    _response = answer?.response;

    if (error != null) {
      Error.throwWithStackTrace(error, answer?.stackTrace ?? StackTrace.empty);
    }

    return _response;
  }

  @override
  List<Map<String, Object?>> takeJournal() => const [];

  @override
  Map<String, Object?>? findReplayed(
    Map<String, Object?> record,
    List<Map<String, Object?>> journal,
  ) {
    final response = _response;

    if (response == null) {
      return null;
    }

    return {
      'kind': record['kind'],
      'status': response.statusCode,
      'response': response.body,
    };
  }

  @override
  String describe(Map<String, Object?> record) {
    return '${record['method']} ${record['path']}';
  }

  @override
  Future<void> close() async {}
}
