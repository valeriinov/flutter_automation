import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_ios_simulator.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

const _iosRuntime = 'com.apple.CoreSimulator.SimRuntime.iOS-26-4';
const _watchRuntime = 'com.apple.CoreSimulator.SimRuntime.watchOS-26-4';
const _iphone = {
  'name': 'iPhone 17 Pro',
  'udid': 'IPHONE-UDID',
  'state': 'Booted',
};
const _secondIphone = {
  'name': 'iPhone 17',
  'udid': 'SECOND-IPHONE-UDID',
  'state': 'Booted',
};
const _shutDownIphone = {
  'name': 'iPhone Air',
  'udid': 'SHUT-DOWN-UDID',
  'state': 'Shutdown',
};
const _watch = {
  'name': 'Apple Watch Series 11',
  'udid': 'WATCH-UDID',
  'state': 'Booted',
};

void main() {
  group('AutomationIosSimulator Tests', () {
    _automationBootedSimulator_should_readSingleBootedIosSimulator();
    _automationBootedSimulator_should_rejectSeveralBootedIosSimulators();
    _automationBootedSimulator_should_rejectAnswerWithoutDevices();
  });
}

void _automationBootedSimulator_should_readSingleBootedIosSimulator() {
  test('AutomationIosSimulator should read single booted iOS simulator', () {
    final simulator = AutomationIosSimulator.fromSimctlJson({
      'devices': {
        _iosRuntime: [_iphone, _shutDownIphone],
        _watchRuntime: [_watch],
      },
    });

    expect(simulator.udid, 'IPHONE-UDID');
    expect(simulator.device, 'iPhone 17 Pro · iOS 26.4');
  });
}

void _automationBootedSimulator_should_rejectSeveralBootedIosSimulators() {
  test(
    'AutomationIosSimulator should reject several booted iOS simulators',
    () {
      expect(
        () => AutomationIosSimulator.fromSimctlJson({
          'devices': {
            _iosRuntime: [_iphone, _secondIphone],
          },
        }),
        throwsA(
          isA<AutomationRunnerException>().having(
            (error) => error.message,
            'message',
            contains('iPhone 17 · iOS 26.4'),
          ),
        ),
      );
    },
  );
}

void _automationBootedSimulator_should_rejectAnswerWithoutDevices() {
  test('AutomationIosSimulator should reject answer without devices', () {
    expect(
      () => AutomationIosSimulator.fromSimctlJson(const {}),
      throwsA(isA<AutomationRunnerException>()),
    );
  });
}
