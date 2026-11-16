import 'dart:io';

import 'package:flutter_automation/automation_target.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_mock/mock_section.dart';

enum _ProbeTarget with AutomationIdComposer {
  submit;

  @override
  AutomationTargetType get type => AutomationTargetType.button;

  @override
  String get scope => 'probe';
}

final _catalog = MockSection<_CatalogSettings>(
  name: 'catalog',
  title: AutomationLocalizedText({'en': 'Catalog'}),
  fromJson: _CatalogSettings.fromJson,
  profiles: {
    'empty': MockProfile(
      (settings) => _CatalogSettings(isEmpty: true),
      title: AutomationLocalizedText({'en': 'Empty'}),
    ),
  },
  restartKeys: {'isEmpty'},
);

final class _CatalogSettings {
  final bool isEmpty;

  const _CatalogSettings({this.isEmpty = false});

  factory _CatalogSettings.fromJson(Map<String, Object?> json) {
    return _CatalogSettings(isEmpty: json['isEmpty'] == true);
  }

  Map<String, Object?> toJson() => {'isEmpty': isEmpty};
}

void main() {
  const AutomationTarget target = _ProbeTarget.submit;
  final scenario = MockScenario([
    _catalog.profile('empty'),
    MockOverride.failures({'/items': {}}),
  ]);
  final isEmpty = scenario.settingsOf(_catalog).isEmpty;
  final catalogue = AutomationCatalogue.fromJson(const {'flows': []});
  final title = _catalog.profiles['empty']?.title.resolve('uk');
  final isRestart = _catalog.changesRestartKey(const {}, scenario.toJson());

  if (target.id != 'probe.button.submit' ||
      isEmpty != true ||
      title != 'Empty' ||
      !isRestart ||
      catalogue.flows.isNotEmpty) {
    throw StateError(
      'Unexpected probe result: ${target.id} $isEmpty $title $isRestart',
    );
  }

  stdout.writeln('host probe ok: ${scenario.toJson()}');
}
