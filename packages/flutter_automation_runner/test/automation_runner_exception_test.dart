import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

void main() {
  group('AutomationRunnerException Tests', () {
    _automationRunnerException_should_printItsMessage();
  });
}

void _automationRunnerException_should_printItsMessage() {
  test('AutomationRunnerException should print its message', () {
    const error = AutomationRunnerException('The flow is malformed.');

    expect('$error', 'The flow is malformed.');
  });
}
