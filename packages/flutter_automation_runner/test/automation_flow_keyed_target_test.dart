import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation/automation_target.dart';
import 'package:flutter_automation_runner/automation_flow_definition.dart';
import 'package:flutter_automation_runner/src/automation_runner.dart';
import 'package:flutter_automation_runner/src/automation_runner_config.dart';

const _keyedId = 'inbox.button.deleteButton.42';

final _definition = AutomationFlowDefinition(
  name: 'inbox',
  defaultVariant: 'main',
  variants: [
    FlowVariant(
      'main',
      items: [
        const WaitFor(ByTarget(_InboxTarget.inboxScreen)),
        Tap(ByTarget(_InboxTarget.deleteButton.withKey(42))),
      ],
    ),
  ],
);

void main() {
  group('AutomationFlowDefinition Keyed Target Tests', () {
    _automationFlowDefinition_should_printTheKeyedIdInTheCatalogue();
    _automationFlowDefinition_should_labelTheStepWithTheKeyedId();
  });
}

void _automationFlowDefinition_should_printTheKeyedIdInTheCatalogue() {
  test(
    'AutomationFlowDefinition should print the keyed id in the catalogue',
    () async {
      final catalogue = await _run(['--catalogue']);

      final flows = catalogue['flows'] as Map<String, Object?>;
      final steps = _readItems(flows['inbox']);

      expect(steps.last['finder'], {'by': 'valueKey', 'value': _keyedId});
    },
  );
}

void _automationFlowDefinition_should_labelTheStepWithTheKeyedId() {
  test(
    'AutomationFlowDefinition should label the step with the keyed id',
    () async {
      final report = await _run(['inbox', '--dry-run']);

      final steps = (report['steps'] as List<Object?>)
          .cast<Map<String, Object?>>();

      expect(steps.first['label'], 'waitFor inbox.screen.inboxScreen');
      expect(steps.last['label'], 'tap $_keyedId');
      expect(steps.last['finder'], containsPair('keyValueString', _keyedId));
    },
  );
}

List<Map<String, Object?>> _readItems(Object? flow) {
  final variants = (flow as Map<String, Object?>)['variants'];
  final main = (variants as Map<String, Object?>)['main'];

  return ((main as Map<String, Object?>)['items'] as List<Object?>)
      .cast<Map<String, Object?>>();
}

Future<Map<String, Object?>> _run(List<String> args) async {
  final lines = <String>[];

  await IOOverrides.runZoned(
    AutomationRunner.fromDefinitions(
      args,
      config: const AutomationRunnerConfig(
        packagePrefix: 'package:sample_app/',
      ),
      flows: [_definition],
    ).run,
    stdout: () => _LineStdout(lines),
  );

  return jsonDecode(lines.single) as Map<String, Object?>;
}

enum _InboxTarget with AutomationIdComposer {
  inboxScreen(AutomationTargetType.screen),
  deleteButton(AutomationTargetType.button);

  @override
  final AutomationTargetType type;

  const _InboxTarget(this.type);

  @override
  String get scope => 'inbox';
}

final class _LineStdout implements Stdout {
  final List<String> lines;

  _LineStdout(this.lines);

  @override
  void writeln([Object? object = '']) => lines.add('$object');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
