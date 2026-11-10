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

void main() {
  group('AutomationRunner Tests', () {
    _automationRunner_should_dryRunFlowWithoutMockBlock();
  });
}

void _automationRunner_should_dryRunFlowWithoutMockBlock() {
  test('AutomationRunner should dry run flow without mock block', () async {
    final directory = Directory.systemTemp.createTempSync('runner-dry-run-');
    final previous = Directory.current;
    final flowsDirectory = Directory('${directory.path}/flows')..createSync();
    final lines = <String>[];

    File(
      '${flowsDirectory.path}/$_flowName.json',
    ).writeAsStringSync(jsonEncode(_flowJson));

    try {
      Directory.current = directory;

      await IOOverrides.runZoned(
        () => AutomationRunner(
          [_flowName, '--dry-run'],
          config: const AutomationRunnerConfig(
            packagePrefix: 'package:sample_app/',
            flowsPath: 'flows',
          ),
        ).run(),
        stdout: () => _LineStdout(lines),
      );
    } finally {
      Directory.current = previous;

      directory.deleteSync(recursive: true);
    }

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
