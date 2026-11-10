import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_android_device.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

const _header = 'List of devices attached';
const _daemonLine = '* daemon started successfully *';
const _emulator = 'emulator-5554\tdevice';
const _phone = 'R58M123ABC\tdevice';
const _unauthorizedPhone = 'R58M999XYZ\tunauthorized';
const _offlineEmulator = 'emulator-5556\toffline';

void main() {
  group('AutomationAndroidDevice Tests', () {
    _automationAndroidDevice_should_readSingleAttachedDevice();
    _automationAndroidDevice_should_rejectSeveralAttachedDevices();
    _automationAndroidDevice_should_rejectOutputWithoutDevices();
  });
}

void _automationAndroidDevice_should_readSingleAttachedDevice() {
  test('AutomationAndroidDevice should read single attached device', () {
    final device = AutomationAndroidDevice.fromAdbDevices(
      '$_daemonLine\n$_header\n$_emulator\n$_unauthorizedPhone\n'
      '$_offlineEmulator\n\n',
    );

    expect(device.serial, 'emulator-5554');
  });
}

void _automationAndroidDevice_should_rejectSeveralAttachedDevices() {
  test('AutomationAndroidDevice should reject several attached devices', () {
    expect(
      () => AutomationAndroidDevice.fromAdbDevices(
        '$_header\n$_emulator\n$_phone\n',
      ),
      throwsA(
        isA<AutomationRunnerException>().having(
          (error) => error.message,
          'message',
          contains('R58M123ABC'),
        ),
      ),
    );
  });
}

void _automationAndroidDevice_should_rejectOutputWithoutDevices() {
  test('AutomationAndroidDevice should reject output without devices', () {
    expect(
      () => AutomationAndroidDevice.fromAdbDevices('$_header\n\n'),
      throwsA(isA<AutomationRunnerException>()),
    );
  });
}
