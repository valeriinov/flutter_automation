import 'dart:io';

import 'package:flutter_automation_runner/src/automation_device.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

/// {@category Utils}
///
/// The one Android device or emulator a run takes screenshots of.
///
/// A run refuses to guess between several attached devices, since screenshots
/// of different devices differ in every pixel.
final class AutomationAndroidDevice implements AutomationDevice {
  static const _attachedState = 'device';
  static const _headerPrefix = 'List of devices';

  /// Serial `adb -s` addresses the device by.
  final String serial;

  const AutomationAndroidDevice({required this.serial});

  /// Reads the single attached device out of [output], the text `adb devices`
  /// prints.
  factory AutomationAndroidDevice.fromAdbDevices(String output) {
    final serials = [
      for (final line in output.split('\n'))
        if (_tryReadSerial(line) case final String serial) serial,
    ];

    if (serials.length != 1) {
      throw AutomationRunnerException(
        'Exactly one attached Android device is needed, found $serials. '
        'Attach one and disconnect the others.',
      );
    }

    return AutomationAndroidDevice(serial: serials.single);
  }

  /// The Android keyboard needs no preparation.
  @override
  Future<void> prepareKeyboard() async {}

  @override
  Future<List<int>> takeScreenshot() async {
    final result = await Process.run('adb', [
      '-s',
      serial,
      'exec-out',
      'screencap',
      '-p',
    ], stdoutEncoding: null);

    if (result.exitCode != 0) {
      throw AutomationRunnerException(
        'adb took no screenshot: ${result.stderr}',
      );
    }

    if (result.stdout case final List<int> bytes) {
      return bytes;
    }

    throw const AutomationRunnerException('adb answered no screenshot bytes.');
  }

  /// Asks `adb` for the single attached device.
  static Future<AutomationAndroidDevice> find() async {
    final result = await Process.run('adb', ['devices']);

    if (result.exitCode != 0) {
      throw AutomationRunnerException(
        'adb could not list the devices: ${result.stderr}',
      );
    }

    return AutomationAndroidDevice.fromAdbDevices('${result.stdout}');
  }

  static String? _tryReadSerial(String line) {
    final columns = line.trim().split(RegExp(r'\s+'));

    if (line.startsWith(_headerPrefix)) {
      return null;
    }

    if (columns case [final serial, final state] when state == _attachedState) {
      return serial;
    }

    return null;
  }
}
