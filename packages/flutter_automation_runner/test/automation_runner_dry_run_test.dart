import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_runner.dart';
import 'package:flutter_automation_runner/src/automation_runner_config.dart';

const _flowName = 'greeting';
const _flowJson = {
  'variants': {
    'main': {
      'use': [
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

const _mockJson = {'latency': 'fast'};
const _mockFlowJson = {
  'variants': {
    'main': {
      'mock': _mockJson,
      'use': [
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
    _automationRunner_should_dryRunFlowWithoutMockBlock();
    _automationRunner_should_leaveTheMockOutOfARunWithNoMock();
  });
}

void _automationRunner_should_leaveTheMockOutOfARunWithNoMock() {
  test(
    'AutomationRunner should leave the mock out of a run with --no-mock',
    () async {
      final withMock = await _dryRun([_flowName, '--dry-run']);
      final withoutMock = await _dryRun([_flowName, '--dry-run', '--no-mock']);

      expect(withMock['mock'], _mockJson);
      expect(withoutMock['mock'], isEmpty);
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
      flows: {_flowName: _mockFlowJson},
      blocks: const {},
    ).run(),
    stdout: () => _LineStdout(lines),
  );

  return jsonDecode(lines.single) as Map<String, Object?>;
}

void _automationRunner_should_dryRunFlowWithoutMockBlock() {
  test('AutomationRunner should dry run flow without mock block', () async {
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
    expect(report['mock'], isEmpty);
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
