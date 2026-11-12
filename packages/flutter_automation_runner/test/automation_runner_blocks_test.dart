import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/automation_flow_definition.dart';
import 'package:flutter_automation_runner/src/automation_runner.dart';
import 'package:flutter_automation_runner/src/automation_runner_config.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

const _config = AutomationRunnerConfig(packagePrefix: 'package:sample_app/');

final _open = FlowBlock(
  name: 'open',
  build: (params) => const [Tap(ByText('Open'))],
);
final _close = FlowBlock(
  name: 'close',
  build: (params) => const [Tap(ByText('Close'))],
);
final _otherOpen = FlowBlock(
  name: 'open',
  build: (params) => const [Tap(ByText('Other'))],
);

void main() {
  group('AutomationRunner Blocks Tests', () {
    _automationRunner_should_collectTheBlocksOfTheUseItems();
    _automationRunner_should_keepOneBlockUsedByManyVariants();
    _automationRunner_should_mergeEqualBlocksBuiltSeparately();
    _automationRunner_should_rejectTwoDifferentBlocksWithOneName();
  });
}

void _automationRunner_should_collectTheBlocksOfTheUseItems() {
  test('AutomationRunner should collect the blocks of the Use items', () async {
    final catalogue = await _readCatalogue([
      AutomationFlowDefinition(
        name: 'first',
        variants: [
          FlowVariant('main', items: [Use(_open), const WaitFor(ByText('Hi'))]),
        ],
      ),
      AutomationFlowDefinition(
        name: 'second',
        variants: [
          FlowVariant('main', items: [Use(_close)]),
        ],
      ),
    ]);

    expect((catalogue['blocks'] as Map<String, Object?>).keys, [
      'open',
      'close',
    ]);
  });
}

void _automationRunner_should_keepOneBlockUsedByManyVariants() {
  test(
    'AutomationRunner should keep one block used by many variants',
    () async {
      final catalogue = await _readCatalogue([
        AutomationFlowDefinition(
          name: 'first',
          variants: [
            FlowVariant('a', items: [Use(_open), Use(_open)]),
            FlowVariant('b', items: [Use(_open)]),
          ],
        ),
      ]);

      expect((catalogue['blocks'] as Map<String, Object?>).keys, ['open']);
    },
  );
}

void _automationRunner_should_mergeEqualBlocksBuiltSeparately() {
  test('AutomationRunner should merge equal blocks built separately', () async {
    final catalogue = await _readCatalogue([
      AutomationFlowDefinition(
        name: 'first',
        variants: [
          FlowVariant('a', items: [Use(_buildOpen())]),
          FlowVariant('b', items: [Use(_buildOpen())]),
        ],
      ),
    ]);

    expect((catalogue['blocks'] as Map<String, Object?>).keys, ['open']);
  });
}

void _automationRunner_should_rejectTwoDifferentBlocksWithOneName() {
  test('AutomationRunner should reject two blocks with one name', () {
    expect(
      () => AutomationRunner.fromDefinitions(
        ['--catalogue'],
        config: _config,
        flows: [
          AutomationFlowDefinition(
            name: 'first',
            variants: [
              FlowVariant('a', items: [Use(_open)]),
              FlowVariant('b', items: [Use(_otherOpen)]),
            ],
          ),
        ],
      ),
      throwsA(isA<AutomationRunnerException>()),
    );
  });
}

FlowBlock _buildOpen() {
  return FlowBlock(
    name: 'open',
    build: (params) => const [Tap(ByText('Open'))],
  );
}

Future<Map<String, Object?>> _readCatalogue(
  List<AutomationFlowDefinition> flows,
) async {
  final lines = <String>[];

  await IOOverrides.runZoned(
    AutomationRunner.fromDefinitions(
      ['--catalogue'],
      config: _config,
      flows: flows,
    ).run,
    stdout: () => _LineStdout(lines),
  );

  return jsonDecode(lines.single) as Map<String, Object?>;
}

final class _LineStdout implements Stdout {
  final List<String> lines;

  _LineStdout(this.lines);

  @override
  void writeln([Object? object = '']) => lines.add('$object');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
