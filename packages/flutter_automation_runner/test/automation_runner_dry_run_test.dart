import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_runner.dart';
import 'package:flutter_automation_runner/src/automation_runner_config.dart';

const _flowName = 'greeting';
const _flowJson = {
  'variants': {
    'main': {
      'items': [
        {
          'action': 'tap',
          'label': 'open the greeting',
          'finder': {'by': 'valueKey', 'value': 'greeting.button'},
        },
        {
          'action': 'waitFor',
          'finder': {'by': 'text', 'value': 'Hello'},
        },
      ],
    },
  },
};

const _scenarioJson = {'latency': 'fast'};
const _scenarioFlowJson = {
  'variants': {
    'main': {
      'scenario': _scenarioJson,
      'items': [
        {
          'action': 'waitFor',
          'finder': {'by': 'text', 'value': 'Hello'},
        },
      ],
    },
  },
};

void main() {
  group('AutomationRunner Tests', () {
    _automationRunner_should_dryRunFlowWithoutScenario();
    _automationRunner_should_leaveTheScenarioOutOfARunWithNoScenario();
  });
}

void _automationRunner_should_leaveTheScenarioOutOfARunWithNoScenario() {
  test(
    'AutomationRunner should skip the scenario with --no-scenario',
    () async {
      final withScenario = await _dryRun([_flowName, '--dry-run']);
      final withoutScenario = await _dryRun([
        _flowName,
        '--dry-run',
        '--no-scenario',
      ]);

      expect(withScenario['scenario'], _scenarioJson);
      expect(withoutScenario['scenario'], isEmpty);
    },
  );
}

Future<Map<String, Object?>> _dryRun(List<String> args) async {
  final lines = <String>[];

  await IOOverrides.runZoned(
    () => AutomationRunner(
      args,
      config: const AutomationRunnerConfig(
        packagePrefix: 'package:sample_app/',
      ),
      flows: {_flowName: _scenarioFlowJson},
      blocks: const {},
    ).run(),
    stdout: () => _LineStdout(lines),
  );

  return jsonDecode(lines.single) as Map<String, Object?>;
}

void _automationRunner_should_dryRunFlowWithoutScenario() {
  test('AutomationRunner should dry run flow without scenario', () async {
    final lines = <String>[];

    await IOOverrides.runZoned(
      () => AutomationRunner(
        [_flowName, '--dry-run'],
        config: const AutomationRunnerConfig(
          packagePrefix: 'package:sample_app/',
        ),
        flows: {_flowName: _flowJson},
        blocks: const {},
      ).run(),
      stdout: () => _LineStdout(lines),
    );

    final report = jsonDecode(lines.single) as Map<String, Object?>;
    final steps = report['steps'] as List<Object?>;

    expect(report['dryRun'], isTrue);
    expect(report['scenario'], isEmpty);
    expect(steps, hasLength(2));
    expect(
      (steps.first as Map<String, Object?>)['finder'],
      containsPair('finderType', 'ByValueKey'),
    );
  });
}

final class _LineStdout implements Stdout {
  final List<String> lines;

  _LineStdout(this.lines);

  @override
  void writeln([Object? object = '']) => lines.add('$object');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
