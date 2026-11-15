import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_mock/mock_section.dart';
import 'package:flutter_automation_runner/automation_flow_definition.dart';
import 'package:flutter_automation_runner/automation_recording.dart';
import 'package:flutter_automation_runner/src/automation_runner.dart';
import 'package:flutter_automation_runner/src/automation_runner_config.dart';

const _config = AutomationRunnerConfig(packagePrefix: 'package:sample_app/');
const _group = AutomationFlowGroup(
  name: 'account',
  title: AutomationLocalizedText({'en': 'Sign-in', 'uk': 'Вхід'}),
);
const _items = [WaitFor(ByText('Hello'))];

final _flows = [
  AutomationFlowDefinition(
    name: 'login',
    group: _group,
    isInQaCatalogue: true,
    defaultVariant: 'accepted',
    variants: [
      FlowVariant(
        'accepted',
        items: _items,
        entry: const AutomationFlowEntry(
          title: AutomationLocalizedText({'en': 'From the icon'}),
          launchedBy: null,
        ),
        scenario: [MockOverride.latency(MockLatencyProfile.fast)],
      ),
      FlowVariant(
        'rejected',
        items: _items,
        scenario: [MockOverride.latency(MockLatencyProfile.slow)],
      ),
    ],
  ),
  AutomationFlowDefinition(
    name: 'login_atlas',
    variants: [
      FlowVariant(
        'frame',
        items: _items,
        entry: const AutomationFlowEntry(
          title: AutomationLocalizedText({'en': 'From settings'}),
          launchedBy: null,
        ),
      ),
    ],
  ),
  AutomationFlowDefinition(
    name: 'chat_probe',
    variants: [
      FlowVariant(
        'main',
        items: [ProbeSeries(duration: Duration(seconds: 1), probes: [])],
      ),
    ],
  ),
];

AutomationRecording _recording(
  String variant,
  int status,
  String code, {
  bool ok = true,
}) {
  return AutomationRecording.fromReport({
    'flow': 'login',
    'variant': variant,
    'ok': ok,
    'totalMs': 10,
    'steps': [
      {
        'label': 'tap send',
        'action': 'tap',
        'ok': true,
        'journal': [
          {
            'method': 'POST',
            'path': '/auth/otp',
            'status': status,
            'response': {'code': code},
          },
        ],
      },
      {'label': 'trace', 'action': 'traceStart', 'ok': true},
    ],
  });
}

void main() {
  group('AutomationCatalogueBuilder Tests', () {
    _automationCatalogueBuilder_should_showAForkWhenBodiesDiffer();
    _automationCatalogueBuilder_should_leaveOutAtlasAndProbeFlows();
    _automationCatalogueBuilder_should_markServiceStepsAndCollectGroups();
    _automationCatalogueBuilder_should_showNoForkForEqualAnswers();
    _automationCatalogueBuilder_should_takeTheFlowsThatSetTheFlagOnly();
    _automationCatalogueBuilder_should_fillTheEntryOfAVariant();
    _automationCatalogueBuilder_should_skipAFailedRecording();
    _automationCatalogueBuilder_should_matchTheForkByOccurrenceNotStepIndex();
    _automationCatalogueBuilder_should_compareListBodies();
  });
  group('AutomationRecordingFiles Tests', () {
    _automationRecordingFiles_should_writeAPassedRunOnly();
  });
  group('AutomationRunner Catalogue Tests', () {
    _automationRunner_should_writeTheCatalogueFile();
  });
}

AutomationCatalogue _build(List<AutomationRecording> recordings) {
  return AutomationCatalogueBuilder(
    flows: {for (final flow in _flows) flow.name: flow.toJson()},
    recordings: recordings,
  ).build();
}

void _automationCatalogueBuilder_should_showAForkWhenBodiesDiffer() {
  test('AutomationCatalogueBuilder should show a fork when bodies differ', () {
    final catalogue = _build([
      _recording('accepted', 200, 'ok'),
      _recording('rejected', 200, 'wrong'),
    ]);
    final fork = catalogue.flows.single.fork;

    expect(fork?.path, '/auth/otp');
    expect(fork?.stepIndex, 0);
    expect(fork?.branches.map((branch) => branch.variant), [
      'accepted',
      'rejected',
    ]);
    expect(fork?.branches.first.label, 'accepted');
  });
}

void _automationCatalogueBuilder_should_showNoForkForEqualAnswers() {
  test('AutomationCatalogueBuilder should show no fork for equal answers', () {
    final catalogue = _build([
      _recording('accepted', 200, 'ok'),
      _recording('rejected', 200, 'ok'),
    ]);

    expect(catalogue.flows.single.fork, isNull);
  });
}

void _automationCatalogueBuilder_should_takeTheFlowsThatSetTheFlagOnly() {
  test(
    'AutomationCatalogueBuilder should take the flows that set the flag only',
    () {
      final catalogue = AutomationCatalogueBuilder(
        flows: {
          'plain': {
            'variants': {'main': <String, Object?>{}},
          },
          'listed': {
            'isInQaCatalogue': true,
            'variants': {'main': <String, Object?>{}},
          },
        },
        recordings: const [],
      ).build();

      expect(catalogue.flows.map((flow) => flow.name), ['listed']);
    },
  );
}

void _automationCatalogueBuilder_should_fillTheEntryOfAVariant() {
  test('AutomationCatalogueBuilder should fill the entry of a variant', () {
    final catalogue = _build(const []);
    final variants = catalogue.flows.single.variants;

    expect(variants.first.entry, {'en': 'From the icon'});
    expect(variants.last.entry, isNull);
  });
}

void _automationCatalogueBuilder_should_skipAFailedRecording() {
  test('AutomationCatalogueBuilder should skip a failed recording', () {
    final catalogue = _build([
      _recording('accepted', 200, 'ok', ok: false),
      _recording('rejected', 200, 'ok'),
    ]);
    final variants = catalogue.flows.single.variants;

    expect(variants.first.steps, isEmpty);
    expect(variants.last.steps, isNotEmpty);
  });
}

AutomationRecording _lateRecording(String variant, int status) {
  return AutomationRecording.fromReport({
    'flow': 'login',
    'variant': variant,
    'ok': true,
    'steps': [
      for (int index = 0; index < 2; index += 1)
        {
          'label': 'step $index',
          'action': 'tap',
          'ok': true,
          'journal': [
            if (variant == 'accepted' || index == 1)
              {'method': 'GET', 'path': '/items', 'status': status},
          ],
        },
    ],
  });
}

void _automationCatalogueBuilder_should_matchTheForkByOccurrenceNotStepIndex() {
  test('AutomationCatalogueBuilder should match the fork by occurrence', () {
    final catalogue = _build([
      _lateRecording('accepted', 200),
      _lateRecording('rejected', 500),
    ]);
    final fork = catalogue.flows.single.fork;

    expect(fork?.path, '/items');
    expect(fork?.branches.map((branch) => branch.statusCode), [200, 500]);
  });
}

void _automationCatalogueBuilder_should_compareListBodies() {
  test('AutomationCatalogueBuilder should compare list bodies', () {
    AutomationRecording recording(String variant, List<int> body) {
      return AutomationRecording.fromReport({
        'flow': 'login',
        'variant': variant,
        'ok': true,
        'steps': [
          {
            'label': 'load',
            'action': 'tap',
            'ok': true,
            'journal': [
              {
                'method': 'GET',
                'path': '/items',
                'status': 200,
                'response': body,
              },
            ],
          },
        ],
      });
    }

    final catalogue = _build([
      recording('accepted', [1]),
      recording('rejected', [2]),
    ]);

    expect(catalogue.flows.single.fork?.path, '/items');
    expect(
      catalogue.flows.single.variants.first.steps.first.requests.first.response,
      [1],
    );
  });
}

void _automationRecordingFiles_should_writeAPassedRunOnly() {
  test('AutomationRecordingFiles should write a passed run only', () {
    final directory = Directory.systemTemp.createTempSync('recording_files');
    final files = AutomationRecordingFiles(directory.path);
    const report = {'flow': 'login', 'variant': 'otp', 'steps': <Object?>[]};

    expect(files.writeReport({...report, 'ok': false}), isNull);
    expect(files.writeReport({...report, 'ok': true}), isNotNull);
    expect(files.readAll(), hasLength(1));
    directory.deleteSync(recursive: true);
  });
}

void _automationCatalogueBuilder_should_leaveOutAtlasAndProbeFlows() {
  test('AutomationCatalogueBuilder should leave out atlas and probe flows', () {
    final catalogue = _build(const []);

    expect(catalogue.flows.map((flow) => flow.name), ['login']);
  });
}

void _automationCatalogueBuilder_should_markServiceStepsAndCollectGroups() {
  test(
    'AutomationCatalogueBuilder should mark service steps and collect groups',
    () {
      final catalogue = _build([_recording('accepted', 200, 'ok')]);
      final steps = catalogue.flows.single.variants.first.steps;

      expect(steps.map((step) => step.isService), [false, true]);
      expect(catalogue.groups.single.name, 'account');
      expect(catalogue.groups.single.title['uk'], 'Вхід');
      expect(catalogue.flows.single.group, 'account');
    },
  );
}

void _automationRunner_should_writeTheCatalogueFile() {
  test('AutomationRunner should write the catalogue file', () async {
    final directory = Directory.systemTemp.createTempSync('qa_catalogue');
    final recordings = AutomationRecordingFiles('${directory.path}/rec')
      ..write(_recording('accepted', 200, 'ok'))
      ..write(_recording('rejected', 200, 'wrong'));
    final out = '${directory.path}/qa_catalogue.json';

    await AutomationRunner.fromDefinitions(
      ['--qa-catalogue', out, '--recordings', recordings.directory],
      config: _config,
      flows: _flows,
    ).run();

    final written = AutomationCatalogue.fromJson(
      jsonDecode(File(out).readAsStringSync()) as Map<String, Object?>,
    );

    directory.deleteSync(recursive: true);
    expect(written.flows.single.fork?.path, '/auth/otp');
  });
}
