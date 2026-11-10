import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_runner/src/automation_device.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

/// {@category Utils}
///
/// The one booted iOS simulator a run takes screenshots of.
///
/// Screenshots of different devices differ in every pixel, so a run refuses to
/// guess between several booted simulators. Only iOS runtimes count: a watch
/// paired with the simulator boots beside it and takes no screenshot.
final class AutomationIosSimulator implements AutomationDevice {
  static const _iosRuntimePrefix = 'com.apple.CoreSimulator.SimRuntime.iOS-';
  static const _bootedState = 'Booted';
  static const _screenshotDirectoryPrefix = 'automation-runner-simulator-';
  static const _screenshotFileName = 'screen.png';

  /// Identifier `flutter run -d` and `simctl` address the simulator by.
  final String udid;

  /// The simulator as a report names it, `<name> · iOS <version>`.
  final String device;

  const AutomationIosSimulator({required this.udid, required this.device});

  /// Reads the single booted iOS simulator out of [json], the decoded answer
  /// of `xcrun simctl list devices booted -j`.
  factory AutomationIosSimulator.fromSimctlJson(Object? json) {
    if (json case {'devices': final Map<String, Object?> runtimes}) {
      return _readSingle([
        for (final MapEntry(key: runtime, value: devices) in runtimes.entries)
          if (runtime.startsWith(_iosRuntimePrefix))
            ..._readBootedSimulators(runtime, devices),
      ]);
    }

    throw const AutomationRunnerException('simctl listed no "devices" object.');
  }

  /// Keeps the software keyboard of the simulator over a focused field.
  ///
  /// A simulator that has seen a hardware keyboard minimizes the software one,
  /// unless its keyboard preferences turn automatic minimization off. This
  /// method writes that preference. A second write changes nothing.
  @override
  Future<void> prepareKeyboard() async {
    final result = await Process.run('xcrun', [
      'simctl',
      'spawn',
      udid,
      'defaults',
      'write',
      'com.apple.keyboard.preferences',
      'AutomaticMinimizationEnabled',
      '-bool',
      'NO',
    ]);

    if (result.exitCode != 0) {
      throw AutomationRunnerException(
        'simctl could not write the keyboard preferences: ${result.stderr}',
      );
    }
  }

  /// Returns the PNG bytes of the whole simulator screen, the system keyboard
  /// included.
  @override
  Future<List<int>> takeScreenshot() async {
    final directory = await Directory.systemTemp.createTemp(
      _screenshotDirectoryPrefix,
    );

    final file = File('${directory.path}/$_screenshotFileName');

    try {
      await _writeScreenshot(file.path);

      return await file.readAsBytes();
    } finally {
      await directory.delete(recursive: true);
    }
  }

  /// Asks `simctl` for the single booted iOS simulator.
  static Future<AutomationIosSimulator> find() async {
    final result = await Process.run('xcrun', [
      'simctl',
      'list',
      'devices',
      'booted',
      '-j',
    ]);

    if (result.exitCode != 0) {
      throw AutomationRunnerException(
        'simctl could not list the simulators: ${result.stderr}',
      );
    }

    return AutomationIosSimulator.fromSimctlJson(
      jsonDecode('${result.stdout}'),
    );
  }

  static AutomationIosSimulator _readSingle(
    List<AutomationIosSimulator> simulators,
  ) {
    if (simulators.length != 1) {
      throw AutomationRunnerException(
        'Exactly one booted iOS simulator is needed, found '
        '${simulators.map((simulator) => simulator.device).toList()}. Boot '
        'one and shut the others down.',
      );
    }

    return simulators.single;
  }

  static List<AutomationIosSimulator> _readBootedSimulators(
    String runtime,
    Object? devices,
  ) {
    final version = runtime
        .substring(_iosRuntimePrefix.length)
        .replaceAll('-', '.');

    return [
      if (devices is List<Object?>)
        for (final device in devices.whereType<Map<String, Object?>>())
          if (device case {
            'state': _bootedState,
            'udid': final String udid,
            'name': final String name,
          })
            AutomationIosSimulator(udid: udid, device: '$name · iOS $version'),
    ];
  }

  Future<void> _writeScreenshot(String path) async {
    final result = await Process.run('xcrun', [
      'simctl',
      'io',
      udid,
      'screenshot',
      path,
    ]);

    if (result.exitCode != 0) {
      throw AutomationRunnerException(
        'simctl took no screenshot: ${result.stderr}',
      );
    }
  }
}
