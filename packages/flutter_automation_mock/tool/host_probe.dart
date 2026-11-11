import 'dart:io';

import 'package:flutter_automation/automation_target.dart';
import 'package:flutter_automation_mock/mock_feature.dart';

enum _ProbeTarget with AutomationIdComposer {
  submit;

  @override
  AutomationTargetType get type => AutomationTargetType.button;

  @override
  String get scope => 'probe';
}

const _catalog = MockFeature<Map<String, Object?>>(
  name: 'catalog',
  fromJson: _readCatalog,
  profiles: {
    'empty': {'isEmpty': true},
  },
);

Map<String, Object?> _readCatalog(Map<String, Object?> json) => json;

void main() {
  const AutomationTarget target = _ProbeTarget.submit;
  final scenario = MockScenario([
    _catalog.profile('empty'),
    MockScenario.failures({'/items': {}}),
  ]);
  final isEmpty = scenario.settingsOf(_catalog)['isEmpty'];

  if (target.id != 'probe.button.submit' || isEmpty != true) {
    throw StateError('Unexpected probe result: ${target.id} $isEmpty');
  }

  stdout.writeln('host probe ok: ${scenario.toJson()}');
}
