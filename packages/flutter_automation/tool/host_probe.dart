import 'dart:io';

import 'package:flutter_automation/automation_target.dart';

enum _ProbeTarget with AutomationIdComposer {
  submit;

  @override
  AutomationTargetType get type => AutomationTargetType.button;

  @override
  String get scope => 'probe';
}

void main() {
  const AutomationTarget target = _ProbeTarget.submit;

  if (target.id != 'probe.button.submit') {
    throw StateError('Unexpected id: ${target.id}');
  }

  stdout.writeln('host probe ok: ${target.id}');
}
