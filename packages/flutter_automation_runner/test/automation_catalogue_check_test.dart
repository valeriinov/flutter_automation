import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/automation_flow_definition.dart';
import 'package:flutter_automation_runner/automation_recording.dart';
import 'package:flutter_automation_runner/src/automation_runner.dart';
import 'package:flutter_automation_runner/src/automation_runner_config.dart';

const _config = AutomationRunnerConfig(packagePrefix: 'package:sample_app/');
const _items = [
  WaitFor(ByText('Hello'), label: 'open'),
  WaitFor(ByText('Done'), label: 'finish'),
];

final _flows = [
  AutomationFlowDefinition(
    name: 'login',
    isInQaCatalogue: true,
    variants: [
      FlowVariant('accepted', items: _items),
      FlowVariant('rejected', items: _items),
    ],
  ),
  AutomationFlowDefinition(
    name: 'help',
    variants: [FlowVariant('main', items: _items)],
  ),
];

final _probeFlows = [
  AutomationFlowDefinition(
    name: 'scroll',
    isInQaCatalogue: true,
    variants: [
      FlowVariant(
        'main',
        items: [
          const WaitFor(ByText('Hello'), label: 'open'),
          ProbeSeries(
            label: 'drift',
            duration: const Duration(seconds: 1),
            probes: const [FlowProbe(name: 'header', finder: ByText('Header'))],
          ),
          const WaitFor(ByText('Done'), label: 'finish'),
        ],
      ),
    ],
  ),
];

typedef _Result = ({Map<String, Object?> report, int code});

void main() {
  group('AutomationRunner Catalogue Check Tests', () {
    _automationRunner_should_passACatalogueThatIsUpToDate();
    _automationRunner_should_reportAFileThatWasEdited();
    _automationRunner_should_reportAVariantWithoutARecording();
    _automationRunner_should_reportARecordingOfAFailedRun();
    _automationRunner_should_reportRecordedLabelsThatDifferFromTheFlow();
    _automationRunner_should_reportARecordingThatNoFlowHolds();
    _automationRunner_should_acceptARecordingOfAFlowOutsideTheCatalogue();
    _automationRunner_should_ignoreProbeSeriesReadsOfARecording();
    _automationRunner_should_writeNothingWhenTheFileIsMissing();
  });
}

AutomationRecording _recording(
  String variant, {
  String flow = 'login',
  bool ok = true,
  List<String> labels = const ['open', 'finish'],
  List<String> probeLabels = const [],
}) {
  return AutomationRecording.fromReport({
    'flow': flow,
    'variant': variant,
    'ok': ok,
    'steps': [
      for (final label in labels) {'label': label, 'action': 'waitFor'},
      for (final label in probeLabels)
        {'label': label, 'action': 'probeSeries'},
    ],
  });
}

List<AutomationRecording> _fresh() {
  return [_recording('accepted'), _recording('rejected')];
}

Future<_Result> _run(
  List<String> args, {
  List<AutomationFlowDefinition>? flows,
}) async {
  final lines = <String>[];

  addTearDown(() => exitCode = 0);

  await IOOverrides.runZoned(
    () => AutomationRunner.fromDefinitions(
      args,
      config: _config,
      flows: flows ?? _flows,
    ).run(),
    stdout: () => _LineStdout(lines),
  );

  final code = exitCode;

  exitCode = 0;

  return (report: jsonDecode(lines.single) as Map<String, Object?>, code: code);
}

Future<_Result> _check(
  List<AutomationRecording> recordings, {
  void Function(File catalogue)? edit,
  List<AutomationFlowDefinition>? flows,
}) async {
  final directory = Directory.systemTemp.createTempSync('catalogue_check');

  addTearDown(() => directory.deleteSync(recursive: true));

  final files = AutomationRecordingFiles('${directory.path}/rec');
  final path = '${directory.path}/qa_catalogue.json';

  for (final recording in recordings) {
    files.write(recording);
  }

  await _run([
    '--qa-catalogue',
    path,
    '--recordings',
    files.directory,
  ], flows: flows);

  edit?.call(File(path));

  final result = await _run([
    '--qa-catalogue',
    path,
    '--recordings',
    files.directory,
    '--check',
  ], flows: flows);

  return result;
}

List<Object?> _problems(_Result result) {
  return result.report['problems'] as List<Object?>;
}

void _automationRunner_should_passACatalogueThatIsUpToDate() {
  test('AutomationRunner should pass a catalogue that is up to date', () async {
    final result = await _check(_fresh());

    expect(result.report['ok'], isTrue);
    expect(_problems(result), isEmpty);
    expect(result.code, 0);
  });
}

void _automationRunner_should_reportAFileThatWasEdited() {
  test('AutomationRunner should report a file that was edited', () async {
    final result = await _check(
      _fresh(),
      edit: (file) => file.writeAsStringSync('${file.readAsStringSync()} '),
    );

    expect(result.report['ok'], isFalse);
    expect(_problems(result), [endsWith('the file is out of date')]);
    expect(result.code, 1);
  });
}

void _automationRunner_should_reportAVariantWithoutARecording() {
  test(
    'AutomationRunner should report a variant without a recording',
    () async {
      final result = await _check([_recording('accepted')]);

      expect(_problems(result), ['login/rejected: no recording']);
      expect(result.code, 1);
    },
  );
}

void _automationRunner_should_reportARecordingOfAFailedRun() {
  test('AutomationRunner should report a recording of a failed run', () async {
    final result = await _check([
      _recording('accepted'),
      _recording('rejected', ok: false),
    ]);

    expect(_problems(result), [
      'login/rejected: the recording is of a failed run',
    ]);
    expect(result.code, 1);
  });
}

void _automationRunner_should_reportRecordedLabelsThatDifferFromTheFlow() {
  test(
    'AutomationRunner should report recorded labels that differ from the flow',
    () async {
      final result = await _check([
        _recording('accepted'),
        _recording('rejected', labels: const ['open', 'tap send']),
      ]);

      expect(_problems(result), [
        'login/rejected: the step labels differ from the flow',
      ]);
      expect(result.code, 1);
    },
  );
}

void _automationRunner_should_reportARecordingThatNoFlowHolds() {
  test(
    'AutomationRunner should report a recording that no flow holds',
    () async {
      final result = await _check([
        ..._fresh(),
        _recording('main', flow: 'ghost'),
        _recording('late'),
      ]);

      expect(_problems(result), [
        'ghost/main: no flow holds this recording',
        'login/late: no flow holds this recording',
      ]);
      expect(result.code, 1);
    },
  );
}

void _automationRunner_should_acceptARecordingOfAFlowOutsideTheCatalogue() {
  test('AutomationRunner should accept a recording of a flow outside the '
      'catalogue', () async {
    final result = await _check([
      ..._fresh(),
      _recording('main', flow: 'help'),
    ]);

    expect(result.report['ok'], isTrue);
    expect(result.code, 0);
  });
}

void _automationRunner_should_ignoreProbeSeriesReadsOfARecording() {
  test(
    'AutomationRunner should ignore probe series reads of a recording',
    () async {
      final result = await _check([
        _recording(
          'main',
          flow: 'scroll',
          probeLabels: const ['drift header 0', 'drift header 1'],
        ),
      ], flows: _probeFlows);

      expect(_problems(result), isEmpty);
      expect(result.code, 0);
    },
  );
}

void _automationRunner_should_writeNothingWhenTheFileIsMissing() {
  test(
    'AutomationRunner should write nothing when the file is missing',
    () async {
      final directory = Directory.systemTemp.createTempSync('catalogue_check');
      final files = AutomationRecordingFiles('${directory.path}/rec');
      final path = '${directory.path}/qa_catalogue.json';

      addTearDown(() => directory.deleteSync(recursive: true));
      _fresh().forEach(files.write);

      final result = await _run([
        '--qa-catalogue',
        path,
        '--recordings',
        files.directory,
        '--check',
      ]);

      expect(_problems(result), ['$path: the file is out of date']);
      expect(result.code, 1);
      expect(File(path).existsSync(), isFalse);
    },
  );
}

final class _LineStdout implements Stdout {
  final List<String> lines;

  _LineStdout(this.lines);

  @override
  void writeln([Object? object = '']) => lines.add('$object');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
