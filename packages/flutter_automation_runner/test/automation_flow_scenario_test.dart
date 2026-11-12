import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_mock/mock_section.dart';
import 'package:flutter_automation_runner/automation_flow_definition.dart';
import 'package:flutter_automation_runner/src/automation_runner.dart';
import 'package:flutter_automation_runner/src/automation_runner_config.dart';

const _config = AutomationRunnerConfig(packagePrefix: 'package:sample_app/');
const _items = [WaitFor(ByText('Hello'))];

final _shelf = MockSection<_ShelfSettings>(
  name: 'shelf',
  fromJson: _ShelfSettings.fromJson,
  profiles: {
    'empty': (settings) => settings.copyWith(itemCount: 0),
    'standard': (settings) => settings.copyWith(itemCount: 3),
  },
);

void main() {
  group('AutomationFlowDefinition Scenario Tests', () {
    _scenario_should_letTheVariantProfileResetTheFlowProfile();
    _scenario_should_addTheStringOverridesOfTheFlowAndTheVariant();
    _scenario_should_applyAScenarioOfProfilesThatEqualTheDefaults();
    _scenario_should_applyAnEmptyScenarioThatTheVariantNames();
    _scenario_should_applyNoScenarioWithoutOverrides();
    _scenario_should_giveTheVariantWithoutScenarioTheScenarioOfTheFlow();
  });
}

void _scenario_should_letTheVariantProfileResetTheFlowProfile() {
  test(
    'Scenario should let the variant profile reset the flow profile',
    () async {
      final report = await _dryRun(
        AutomationFlowDefinition(
          name: 'sample',
          scenario: [_shelf.profile('empty')],
          variants: [
            FlowVariant(
              'main',
              items: _items,
              scenario: [_shelf.profile('standard')],
            ),
          ],
        ),
      );

      expect(report['scenario'], {'shelf': <String, Object?>{}});
      expect(report['appliesScenario'], isTrue);
    },
  );
}

void _scenario_should_addTheStringOverridesOfTheFlowAndTheVariant() {
  test(
    'Scenario should add the string overrides of flow and variant',
    () async {
      final report = await _dryRun(
        AutomationFlowDefinition(
          name: 'sample',
          scenario: [
            MockOverride.latency(MockLatencyProfile.fast),
            MockOverride.failures({
              '/items': {'statusCode': 500, 'message': 'down'},
            }),
          ],
          variants: [
            FlowVariant(
              'main',
              items: _items,
              scenario: [
                MockOverride.failures({
                  '/items': {'statusCode': 503},
                  '/other': {'statusCode': 404},
                }),
              ],
            ),
          ],
        ),
      );

      expect(report['scenario'], {
        'latency': 'fast',
        'failures': {
          '/items': {'statusCode': 503, 'message': 'down'},
          '/other': {'statusCode': 404},
        },
      });
    },
  );
}

void _scenario_should_applyAScenarioOfProfilesThatEqualTheDefaults() {
  test(
    'Scenario should apply a scenario of profiles equal to defaults',
    () async {
      final report = await _dryRun(
        AutomationFlowDefinition(
          name: 'sample',
          variants: [
            FlowVariant(
              'main',
              items: _items,
              scenario: [_shelf.profile('standard')],
            ),
          ],
        ),
      );

      expect(report['scenario'], {'shelf': <String, Object?>{}});
      expect(report['appliesScenario'], isTrue);
    },
  );
}

void _scenario_should_applyAnEmptyScenarioThatTheVariantNames() {
  test(
    'Scenario should apply an empty scenario that the variant names',
    () async {
      final report = await _dryRunJson({
        'variants': {
          'main': {'scenario': <String, Object?>{}, 'items': <Object?>[]},
        },
      });

      expect(report['scenario'], isEmpty);
      expect(report['appliesScenario'], isTrue);
    },
  );
}

void _scenario_should_applyNoScenarioWithoutOverrides() {
  test('Scenario should apply no scenario without overrides', () async {
    final report = await _dryRun(
      const AutomationFlowDefinition(
        name: 'sample',
        variants: [FlowVariant('main', items: _items)],
      ),
    );

    expect(report['scenario'], isEmpty);
    expect(report['appliesScenario'], isFalse);
  });
}

void _scenario_should_giveTheVariantWithoutScenarioTheScenarioOfTheFlow() {
  test(
    'Scenario should give a variant without scenario the scenario of the flow',
    () async {
      final report = await _dryRunJson({
        'scenario': {'latency': 'fast'},
        'variants': {
          'main': {'items': <Object?>[]},
        },
      });

      expect(report['scenario'], {'latency': 'fast'});
      expect(report['appliesScenario'], isTrue);
    },
  );
}

Future<Map<String, Object?>> _dryRun(AutomationFlowDefinition definition) {
  return _capture(
    AutomationRunner.fromDefinitions(
      ['sample', 'main', '--dry-run'],
      config: _config,
      flows: [definition],
    ),
  );
}

Future<Map<String, Object?>> _dryRunJson(Map<String, Object?> flow) {
  return _capture(
    AutomationRunner(
      ['sample', 'main', '--dry-run'],
      config: _config,
      flows: {'sample': flow},
      blocks: const {},
    ),
  );
}

Future<Map<String, Object?>> _capture(AutomationRunner runner) async {
  final lines = <String>[];

  await IOOverrides.runZoned(
    () => runner.run(),
    stdout: () => _LineStdout(lines),
  );

  return jsonDecode(lines.single) as Map<String, Object?>;
}

final class _ShelfSettings {
  final int itemCount;

  const _ShelfSettings({this.itemCount = 3});

  factory _ShelfSettings.fromJson(Map<String, Object?> json) {
    final itemCount = json['itemCount'];

    return _ShelfSettings(itemCount: itemCount is int ? itemCount : 3);
  }

  _ShelfSettings copyWith({int? itemCount}) =>
      _ShelfSettings(itemCount: itemCount ?? this.itemCount);

  Map<String, Object?> toJson() => {'itemCount': itemCount};
}

final class _LineStdout implements Stdout {
  final List<String> lines;

  _LineStdout(this.lines);

  @override
  void writeln([Object? object = '']) => lines.add('$object');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
