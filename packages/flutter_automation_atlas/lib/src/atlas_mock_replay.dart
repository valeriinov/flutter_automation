import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_journal_schema.dart';
import 'package:flutter_automation_atlas/src/atlas_launch_settings.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';

/// {@category Utils}
///
/// Asks the mock built from the current code what the snapshots recorded it
/// was asked and tells, for each snapshot, the first stage it answers
/// differently.
abstract interface class AtlasMockReplay {
  /// The outcome of each of [inputs], keyed by [AtlasMockReplayInput.id].
  Map<String, AtlasMockReplayOutcome> replay(List<AtlasMockReplayInput> inputs);
}

/// {@category Utils}
///
/// Replays under `flutter test`, since the mock reaches the SDKs and the app's
/// DTOs, which a plain Dart VM cannot load: one run for every input, handed
/// over and read back through two JSON files.
final class AtlasMockReplayProcess implements AtlasMockReplay {
  /// The define naming the file the inputs are read from.
  static const inputDefine = 'ATLAS_MOCK_REPLAY_INPUT';

  /// The define naming the file the outcomes are written to.
  static const outputDefine = 'ATLAS_MOCK_REPLAY_OUTPUT';

  static const _directoryPrefix = 'atlas-mock-replay-';
  static const _inputFileName = 'input.json';
  static const _outputFileName = 'output.json';

  final String _rootPath;
  final String _helperPath;
  final AtlasLaunchSettings _launch;

  /// The [_helperPath] parameter is the `flutter test` file the replay runs
  /// in, relative to the root; the [_launch] parameter tells how `flutter` is
  /// called.
  const AtlasMockReplayProcess(this._rootPath, this._helperPath, this._launch);

  @override
  Map<String, AtlasMockReplayOutcome> replay(
    List<AtlasMockReplayInput> inputs,
  ) {
    if (inputs.isEmpty) {
      return const {};
    }

    final directory = Directory.systemTemp.createTempSync(_directoryPrefix);

    try {
      return _replayIn(directory, inputs);
    } finally {
      directory.deleteSync(recursive: true);
    }
  }

  Map<String, AtlasMockReplayOutcome> _replayIn(
    Directory directory,
    List<AtlasMockReplayInput> inputs,
  ) {
    final inputFile = File(p.join(directory.path, _inputFileName))
      ..writeAsStringSync(
        jsonEncode(inputs.map((input) => input.toJson()).toList()),
      );
    final outputFile = File(p.join(directory.path, _outputFileName));
    final flutter = _launch.resolveCommand('flutter');
    final result = Process.runSync(flutter.executable, [
      ...flutter.arguments,
      'test',
      _helperPath,
      '--dart-define=$inputDefine=${inputFile.path}',
      '--dart-define=$outputDefine=${outputFile.path}',
    ], workingDirectory: _rootPath);

    if (result.exitCode != 0 || !outputFile.existsSync()) {
      throw AtlasException(
        'The mock replay failed:\n${result.stdout}\n${result.stderr}',
      );
    }

    return AtlasMockReplayOutcome.readAll(outputFile.readAsStringSync());
  }
}

/// {@category Utils}
///
/// The moments the stage of a snapshot was captured on, as UTC ISO 8601
/// moments, absent in a stage captured before stages held them.
typedef AtlasStageMoments = ({String? anchor, String? launchedAt});

/// {@category Utils}
///
/// The answers of the mock one snapshot recorded, the moments each stage was
/// captured on and the scenario it was captured against.
final class AtlasMockReplayInput {
  /// The variant id the snapshot belongs to.
  final String id;

  /// The scenario of the variant.
  final Map<String, Object?> scenario;

  /// The locale the snapshot was captured in, which the capture made the
  /// language of the signed-in user.
  final String locale;

  /// Every answer record of the snapshot, oldest first, each with the index
  /// of the stage it was recorded in.
  final List<AtlasRecordedAnswer> answers;

  /// The moments of each stage, in stage order.
  final List<AtlasStageMoments> stageMoments;

  const AtlasMockReplayInput({
    required this.id,
    required this.scenario,
    required this.answers,
    required this.locale,
    this.stageMoments = const [],
  });

  /// The input replaying [snapshot] of the variant [id] against the mock.
  ///
  /// An answer the mock gives implicitly ([AtlasJournalSchema.tryImplyAnswer])
  /// is preceded by the record it implies, in the stage of the answer.
  factory AtlasMockReplayInput.fromSnapshot({
    required String id,
    required Map<String, Object?> scenario,
    required AtlasSnapshot snapshot,
    required AtlasJournalSchema schema,
  }) {
    final recordedAnswers = [
      for (final (stage, snapshotStage) in snapshot.stages.indexed)
        for (final record in snapshotStage.journal)
          if (AtlasRecordedAnswer.isAnswer(record, schema))
            AtlasRecordedAnswer(
              stage: stage,
              record: AtlasJson.readObject(record, 'An answer record'),
            ),
    ];

    return AtlasMockReplayInput(
      id: id,
      scenario: scenario,
      locale: snapshot.locale,
      stageMoments: [
        for (final stage in snapshot.stages)
          (anchor: stage.anchor, launchedAt: stage.launchedAt),
      ],
      answers: [
        for (final (index, answer) in recordedAnswers.indexed) ...[
          if (_tryImplyAnswer(schema, recordedAnswers, index)
              case final implied?)
            AtlasRecordedAnswer(stage: answer.stage, record: implied),
          answer,
        ],
      ],
    );
  }

  /// Reads an input written by [toJson].
  factory AtlasMockReplayInput.fromJson(Map<String, Object?> json) {
    return AtlasMockReplayInput(
      id: AtlasJson.readString(json, 'id'),
      scenario: AtlasJson.tryReadObject(json, 'scenario') ?? const {},
      locale: AtlasJson.readString(json, 'locale'),
      answers: AtlasJson.readObjects(json, 'answers')
          .map(
            (answer) => AtlasRecordedAnswer(
              stage: switch (answer['stage']) {
                final int stage => stage,
                _ => 0,
              },
              record: AtlasJson.tryReadObject(answer, 'record') ?? {},
            ),
          )
          .toList(),
      stageMoments: AtlasJson.readObjects(json, 'stageMoments')
          .map(
            (moments) => (
              anchor: AtlasJson.tryReadString(moments, 'anchor'),
              launchedAt: AtlasJson.tryReadString(moments, 'launchedAt'),
            ),
          )
          .toList(),
    );
  }

  /// Reads the inputs a [AtlasMockReplayProcess] wrote.
  static List<AtlasMockReplayInput> readAll(String source) {
    final json = jsonDecode(source);

    if (json is! List<Object?>) {
      throw const AtlasException('The replay input is not a list.');
    }

    return json
        .map(
          (item) => AtlasMockReplayInput.fromJson(
            AtlasJson.readObject(item, 'A replay input'),
          ),
        )
        .toList();
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'scenario': scenario,
      'locale': locale,
      'answers': [
        for (final answer in answers)
          {'stage': answer.stage, 'record': answer.record},
      ],
      'stageMoments': [
        for (final moments in stageMoments)
          {'anchor': ?moments.anchor, 'launchedAt': ?moments.launchedAt},
      ],
    };
  }

  static Map<String, Object?>? _tryImplyAnswer(
    AtlasJournalSchema schema,
    List<AtlasRecordedAnswer> answers,
    int index,
  ) {
    return schema.tryImplyAnswer?.call([
      for (final answer in answers.take(index)) answer.record,
    ], answers[index].record);
  }
}

/// {@category Utils}
///
/// One answer of the mock a snapshot recorded — a request, a launch, a device
/// answer or a stand-in's output — with the stage it was recorded in.
final class AtlasRecordedAnswer {
  /// The index of the stage whose journal holds the record.
  final int stage;

  /// The journal record as the snapshot stores it.
  final Map<String, Object?> record;

  const AtlasRecordedAnswer({required this.stage, required this.record});

  /// Whether the journal [record] is an answer of the mock, by the
  /// [AtlasJournalSchema.answerKinds] of [schema].
  static bool isAnswer(Object? record, AtlasJournalSchema schema) {
    return record is Map<String, Object?> &&
        schema.answerKinds.contains(record['kind']);
  }
}

/// {@category Utils}
///
/// Where the current mock first answers a snapshot's requests differently.
final class AtlasMockReplayOutcome {
  /// The stage of the first request answered differently, `null` when every
  /// answer is the recorded one.
  final int? stage;

  /// The request answered differently and how, `null` with [stage].
  final String? difference;

  const AtlasMockReplayOutcome({this.stage, this.difference});

  /// The outcome of a snapshot every request of which is answered alike.
  const AtlasMockReplayOutcome.same() : stage = null, difference = null;

  factory AtlasMockReplayOutcome._fromJson(Map<String, Object?> json) {
    final stage = json['stage'];

    return AtlasMockReplayOutcome(
      stage: stage is int ? stage : null,
      difference: AtlasJson.tryReadString(json, 'difference'),
    );
  }

  /// Whether the mock answers every request as recorded.
  bool get isSame => stage == null;

  /// Reads the outcomes the replay helper wrote, keyed by input id.
  static Map<String, AtlasMockReplayOutcome> readAll(String source) {
    final json = AtlasJson.readObject(jsonDecode(source), 'The replay output');

    return {
      for (final MapEntry(:key, :value) in json.entries)
        key: AtlasMockReplayOutcome._fromJson(
          AtlasJson.readObject(value, 'The outcome of $key'),
        ),
    };
  }

  Map<String, Object?> toJson() {
    return {'stage': ?stage, 'difference': ?difference};
  }
}
