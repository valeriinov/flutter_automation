import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation/automation_target.dart';
import 'package:flutter_automation_mock/mock_section.dart';
import 'package:flutter_automation_runner/automation_flow_definition.dart';
import 'package:flutter_automation_runner/src/automation_runner.dart';
import 'package:flutter_automation_runner/src/automation_runner_config.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

enum _Target with AutomationIdComposer {
  root,
  submit;

  @override
  AutomationTargetType get type => AutomationTargetType.button;

  @override
  String get scope => 'sample';
}

const _config = AutomationRunnerConfig(
  packagePrefix: 'package:sample_app/',
  dateFormats: {'en': 'MM/dd/yyyy', 'uk': 'dd.MM.yyyy'},
  dateValueKeys: {'dayTile': 'day.{yyyyMMdd}'},
);

const _itemTile = {'en': 'Item', 'uk': 'Позиція'};

final _openItem = FlowBlock(
  name: 'open_item',
  title: const AutomationLocalizedText({
    'en': 'Open an item',
    'uk': 'Відкрити позицію',
  }),
  params: const {'key': 'first', 'tile': _itemTile, 'isFast': false},
  build: (params) => [
    WaitForTappable(
      ByValueKey('item.${params['key']}.tile'),
      label: 'tile ${params['key']} ready',
      timeout: const Duration(seconds: 5),
    ),
    Tap(
      ByText(params['tile']),
      label: 'tap ${params['key']}',
      title: AutomationLocalizedText({
        'en': 'Tap ${params['key']}',
        'uk': 'Натиснути ${params['key']}',
      }),
    ),
    Tap(ByValueKey(params['key'])),
    DriverCommand(
      'sample.open',
      arguments: {'fast': params['isFast'], 'key': '${params['key']}'},
      timeout: const Duration(seconds: 3),
    ),
  ],
);

final _closeItem = FlowBlock(
  name: 'close_item',
  build: (params) => [const Tap(ByPageBack(), label: 'back')],
);

final _definition = AutomationFlowDefinition(
  name: 'sample',
  title: const AutomationLocalizedText({'en': 'Sample', 'uk': 'Зразок'}),
  subtitle: const AutomationLocalizedText({'en': 'A walk', 'uk': 'Хід'}),
  defaultVariant: 'main',
  scenario: [
    MockOverride.latency(MockLatencyProfile.fast),
    const MockOverride('auth', {'isSignedIn': true, 'isAnonymous': false}),
  ],
  variants: [
    FlowVariant(
      'main',
      title: const AutomationLocalizedText({'en': 'Main', 'uk': 'Основний'}),
      proves: const AutomationLocalizedText({'en': 'It works', 'uk': 'Працює'}),
      entry: const AutomationFlowEntry(
        title: AutomationLocalizedText({'en': 'From push', 'uk': 'З пуша'}),
        launchedBy: AutomationLaunchSource.push,
      ),
      scenario: const [
        MockOverride('auth', {'isAnonymous': true}),
        MockOverride('catalog', {'isEmpty': true}),
      ],
      items: [
        Use(_openItem),
        Use(_openItem, arguments: {'key': 'second', 'isFast': true}),
        Use(
          _openItem,
          arguments: {
            'tile': {'en': 'Other', 'uk': 'Інше'},
          },
        ),
        const WaitFor(
          ByTarget(_Target.root),
          label: 'root',
          title: AutomationLocalizedText({'en': 'Root', 'uk': 'Корінь'}),
          timeout: Duration(seconds: 15),
        ),
        const WaitForAbsent(ByTarget(_Target.submit)),
        const ScrollIntoView(ByValueKey(7), timeout: Duration(seconds: 2)),
        const Scroll(
          ByType('ListView'),
          dx: 0,
          dy: -300.5,
          duration: Duration(milliseconds: 400),
          frequency: 30,
          label: 'swipe',
        ),
        const Scroll(
          ByText({'en': '12.5', 'uk': '12,5'}),
          dy: 100,
          duration: Duration(seconds: 1),
        ),
        const EnterText('hello', label: 'type', title: _typeTitle),
        const EnterText('no label'),
        const DriverCommand('sample.reset'),
        const TraceStart(duration: Duration(milliseconds: 250)),
        const TraceStart(),
        const ProbeCenter(
          ByTooltip('Close'),
          label: 'centre',
          timeout: Duration(seconds: 9),
        ),
        const ProbeSeries(
          label: 'series',
          duration: Duration(seconds: 2),
          timeout: Duration(seconds: 4),
          probes: [
            FlowProbe(name: 'a', finder: ByLocaleKey('sample.title')),
            FlowProbe(
              name: 'b',
              after: Duration(milliseconds: 120),
              finder: ByLocaleKeyTooltip('sample.hint'),
            ),
          ],
        ),
        const TraceStop(duration: Duration(seconds: 1)),
        const Tap(
          ByDescendant(
            of: ByValueKey('list'),
            matching: ByText('Row'),
            matchRoot: true,
          ),
        ),
        const Tap(ByAncestor(of: ByType('Icon'), matching: ByType('Card'))),
        const Tap(ByDateText(dayOffset: 1, time: '10:00')),
        const WaitFor(ByDateText(dayOffset: -2)),
        const Tap(ByDeclaredDate('dayTile', dayOffset: 3)),
        Use(_closeItem),
      ],
    ),
    FlowVariant(
      'second',
      stateOf: 'main',
      entry: const AutomationFlowEntry(
        title: AutomationLocalizedText({'en': 'From link', 'uk': 'З лінка'}),
        launchedBy: AutomationLaunchSource.link,
      ),
      items: [Use(_closeItem), const WaitFor(ByValueKey('end'))],
    ),
    const FlowVariant('third', items: [WaitFor(ByPageBack())]),
  ],
);

const _typeTitle = AutomationLocalizedText({'en': 'Type', 'uk': 'Ввести'});

const _openItemJson = {
  'title': {'en': 'Open an item', 'uk': 'Відкрити позицію'},
  'params': {'key': 'first', 'tile': _itemTile, 'isFast': false},
  'steps': [
    {
      'action': 'waitForTappable',
      'label': 'tile {{key}} ready',
      'finder': {'by': 'valueKey', 'value': 'item.{{key}}.tile'},
      'timeoutMs': 5000,
    },
    {
      'action': 'tap',
      'label': 'tap {{key}}',
      'title': {'en': 'Tap {{key}}', 'uk': 'Натиснути {{key}}'},
      'finder': {'by': 'text', 'value': '{{tile}}'},
    },
    {
      'action': 'tap',
      'finder': {'by': 'valueKey', 'value': '{{key}}'},
    },
    {
      'action': 'driverCommand',
      'command': 'sample.open',
      'arguments': {'fast': '{{isFast}}', 'key': '{{key}}'},
      'timeoutMs': 3000,
    },
  ],
};

const _closeItemJson = {
  'steps': [
    {
      'action': 'tap',
      'label': 'back',
      'finder': {'by': 'pageBack'},
    },
  ],
};

const _blocksJson = {'open_item': _openItemJson, 'close_item': _closeItemJson};

const _flowJson = {
  'title': {'en': 'Sample', 'uk': 'Зразок'},
  'subtitle': {'en': 'A walk', 'uk': 'Хід'},
  'defaultVariant': 'main',
  'scenario': {
    'latency': 'fast',
    'auth': {'isSignedIn': true, 'isAnonymous': false},
  },
  'variants': {
    'main': {
      'title': {'en': 'Main', 'uk': 'Основний'},
      'proves': {'en': 'It works', 'uk': 'Працює'},
      'entry': {
        'title': {'en': 'From push', 'uk': 'З пуша'},
        'launchedBy': 'push',
      },
      'scenario': {
        'latency': 'fast',
        'auth': {'isSignedIn': true, 'isAnonymous': true},
        'catalog': {'isEmpty': true},
      },
      'items': [
        'open_item',
        {
          'block': 'open_item',
          'with': {'key': 'second', 'isFast': true},
        },
        {
          'block': 'open_item',
          'with': {
            'tile': {'en': 'Other', 'uk': 'Інше'},
          },
        },
        {
          'action': 'waitFor',
          'label': 'root',
          'title': {'en': 'Root', 'uk': 'Корінь'},
          'finder': {'by': 'valueKey', 'value': 'sample.button.root'},
          'timeoutMs': 15000,
        },
        {
          'action': 'waitForAbsent',
          'finder': {'by': 'valueKey', 'value': 'sample.button.submit'},
        },
        {
          'action': 'scrollIntoView',
          'finder': {'by': 'valueKey', 'value': 7},
          'timeoutMs': 2000,
        },
        {
          'action': 'scroll',
          'label': 'swipe',
          'finder': {'by': 'type', 'value': 'ListView'},
          'dx': 0,
          'dy': -300.5,
          'durationMs': 400,
          'frequency': 30,
        },
        {
          'action': 'scroll',
          'finder': {
            'by': 'text',
            'value': {'en': '12.5', 'uk': '12,5'},
          },
          'dy': 100,
          'durationMs': 1000,
        },
        {
          'action': 'enterText',
          'label': 'type',
          'title': {'en': 'Type', 'uk': 'Ввести'},
          'text': 'hello',
        },
        {'action': 'enterText', 'text': 'no label'},
        {'action': 'driverCommand', 'command': 'sample.reset'},
        {'action': 'traceStart', 'durationMs': 250},
        {'action': 'traceStart'},
        {
          'action': 'probeCenter',
          'label': 'centre',
          'finder': {'by': 'tooltip', 'value': 'Close'},
          'timeoutMs': 9000,
        },
        {
          'action': 'probeSeries',
          'label': 'series',
          'durationMs': 2000,
          'timeoutMs': 4000,
          'probes': [
            {
              'name': 'a',
              'finder': {'by': 'localeKey', 'value': 'sample.title'},
            },
            {
              'name': 'b',
              'afterMs': 120,
              'finder': {'by': 'localeKeyTooltip', 'value': 'sample.hint'},
            },
          ],
        },
        {'action': 'traceStop', 'durationMs': 1000},
        {
          'action': 'tap',
          'finder': {
            'by': 'descendant',
            'of': {'by': 'valueKey', 'value': 'list'},
            'matching': {'by': 'text', 'value': 'Row'},
            'matchRoot': true,
          },
        },
        {
          'action': 'tap',
          'finder': {
            'by': 'ancestor',
            'of': {'by': 'type', 'value': 'Icon'},
            'matching': {'by': 'type', 'value': 'Card'},
          },
        },
        {
          'action': 'tap',
          'finder': {'by': 'dateText', 'dayOffset': 1, 'time': '10:00'},
        },
        {
          'action': 'waitFor',
          'finder': {'by': 'dateText', 'dayOffset': -2},
        },
        {
          'action': 'tap',
          'finder': {'by': 'dayTile', 'dayOffset': 3},
        },
        'close_item',
      ],
    },
    'second': {
      'stateOf': 'main',
      'entry': {
        'title': {'en': 'From link', 'uk': 'З лінка'},
        'launchedBy': 'link',
      },
      'scenario': {
        'latency': 'fast',
        'auth': {'isSignedIn': true, 'isAnonymous': false},
      },
      'items': [
        'close_item',
        {
          'action': 'waitFor',
          'finder': {'by': 'valueKey', 'value': 'end'},
        },
      ],
    },
    'third': {
      'scenario': {
        'latency': 'fast',
        'auth': {'isSignedIn': true, 'isAnonymous': false},
      },
      'items': [
        {
          'action': 'waitFor',
          'finder': {'by': 'pageBack'},
        },
      ],
    },
  },
};

void main() {
  group('AutomationFlowDefinition Tests', () {
    _automationFlowDefinition_should_dryRunLikeItsJsonTwin();
    _automationFlowDefinition_should_dryRunLikeItsJsonTwinInUkrainian();
    _automationFlowDefinition_should_printCatalogueBeforeUseExpands();
    _automationFlowDefinition_should_rejectRepeatedVariantName();
    _flowParams_should_rejectUndeclaredParameter();
  });
  group('AutomationRunner Tests', () {
    _automationRunner_should_refuseUnknownFlowWithKnownNames();
    _automationRunner_should_describeHotRestartRefusal();
  });
}

void _automationFlowDefinition_should_dryRunLikeItsJsonTwin() {
  test('AutomationFlowDefinition should dry run like its JSON twin', () async {
    for (final variant in ['main', 'second', 'third']) {
      final args = ['sample', variant, '--dry-run'];

      expect(await _runDefinition(args), await _runJson(args));
    }

    final main = jsonDecode(await _runDefinition(['sample', '--dry-run']));

    expect((main as Map<String, Object?>)['steps'], hasLength(greaterThan(30)));
    expect(
      await _runDefinition(['sample', '--dry-run']),
      await _runJson(['sample', '--dry-run']),
    );
  });
}

void _automationFlowDefinition_should_dryRunLikeItsJsonTwinInUkrainian() {
  test('AutomationFlowDefinition should dry run in another locale', () async {
    final args = ['sample', 'main', '--dry-run', '--locale', 'uk'];
    final report = jsonDecode(await _runDefinition(args));

    expect(await _runDefinition(args), await _runJson(args));
    expect(report, containsPair('scenario', isA<Map<String, Object?>>()));
  });
}

void _automationFlowDefinition_should_printCatalogueBeforeUseExpands() {
  test('AutomationFlowDefinition should print catalogue before Use', () async {
    final catalogue = jsonDecode(await _runDefinition(['--catalogue']));

    expect(catalogue, {
      'flows': {'sample': _flowJson},
      'blocks': _blocksJson,
    });
  });
}

void _automationFlowDefinition_should_rejectRepeatedVariantName() {
  test('AutomationFlowDefinition should reject repeated variant name', () {
    const definition = AutomationFlowDefinition(
      name: 'dup',
      variants: [
        FlowVariant('a', items: []),
        FlowVariant('a', items: []),
      ],
    );

    expect(definition.toJson, throwsA(isA<AutomationRunnerException>()));
  });
}

void _flowParams_should_rejectUndeclaredParameter() {
  test('FlowParams should reject undeclared parameter', () {
    final block = FlowBlock(
      name: 'typo',
      params: const {'key': 'a'},
      build: (params) => [WaitFor(ByValueKey(params['kye']))],
    );

    expect(block.toJson, throwsA(isA<AutomationRunnerException>()));
  });
}

void _automationRunner_should_refuseUnknownFlowWithKnownNames() {
  test('AutomationRunner should refuse unknown flow with known names', () {
    final runner = AutomationRunner.fromDefinitions(
      ['missing', '--dry-run'],
      config: _config,
      flows: [_definition],
    );

    expect(
      runner.run,
      throwsA(
        isA<AutomationRunnerException>().having(
          (error) => error.message,
          'message',
          'No flow "missing". Known flows: [sample].',
        ),
      ),
    );
  });
}

void _automationRunner_should_describeHotRestartRefusal() {
  test('AutomationRunner should describe hot restart refusal', () {
    expect(
      AutomationRunner.describeHotRestartRefusal('ws://127.0.0.1:1/ws'),
      'No flutter run answers hotRestart at ws://127.0.0.1:1/ws, so the app '
      'cannot launch on the scenario and the locale of the run. Relaunch it '
      'with flutter run and pass the new uri with --uri.',
    );
  });
}

Future<String> _runDefinition(List<String> args) {
  return _capture(
    AutomationRunner.fromDefinitions(
      args,
      config: _config,
      flows: [_definition],
    ),
  );
}

Future<String> _runJson(List<String> args) {
  return _capture(
    AutomationRunner(
      args,
      config: _config,
      flows: const {'sample': _flowJson},
      blocks: _blocksJson,
    ),
  );
}

Future<String> _capture(AutomationRunner runner) async {
  final lines = <String>[];

  await IOOverrides.runZoned(runner.run, stdout: () => _LineStdout(lines));

  return lines.single;
}

final class _LineStdout implements Stdout {
  final List<String> lines;

  _LineStdout(this.lines);

  @override
  void writeln([Object? object = '']) => lines.add('$object');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
