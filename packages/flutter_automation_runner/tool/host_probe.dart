import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation/automation_target.dart';
import 'package:flutter_automation_mock/mock_section.dart';
import 'package:flutter_automation_runner/automation_flow_definition.dart';

enum _ProbeTarget with AutomationIdComposer {
  submit;

  @override
  AutomationTargetType get type => AutomationTargetType.button;

  @override
  String get scope => 'probe';
}

void main() {
  const definition = AutomationFlowDefinition(
    name: 'probe',
    scenario: [MockOverride('latency', 'fast')],
    variants: [
      FlowVariant(
        'main',
        items: [
          Tap(ByTarget(_ProbeTarget.submit)),
          WaitFor(ByText('Done'), timeout: Duration(seconds: 5)),
        ],
      ),
    ],
  );
  final json = jsonEncode(definition.toJson());

  if (!json.contains('probe.button.submit')) {
    throw StateError('Unexpected flow JSON: $json');
  }

  stdout.writeln('host probe ok: $json');
}
