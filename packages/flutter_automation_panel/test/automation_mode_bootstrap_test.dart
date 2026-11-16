import 'dart:io';

import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Automation Mode Bootstrap Tests', () {
    _restore_should_startOnTheServerWithAnEmptyFolder();
    _restore_should_stayOnTheMockInABuildThatCannotSwitch();
    _restore_should_readTheSavedMock();
    _createModeController_should_shareTheRestartFlag();
    _createModeController_should_returnNullInABuildThatCannotSwitch();
  });
}

Directory _createDirectory() {
  final directory = Directory.systemTemp.createTempSync('mode_bootstrap');

  addTearDown(() => directory.deleteSync(recursive: true));

  return directory;
}

void _restore_should_startOnTheServerWithAnEmptyFolder() {
  test('restore should start on the server with an empty folder', () async {
    final bootstrap = await AutomationModeBootstrap.restore(
      directory: _createDirectory().path,
      isSwitchable: true,
    );

    expect(bootstrap.mode, AutomationMode.server);
    expect(bootstrap.isOnMock, isFalse);
    expect(bootstrap.isRestartRequired.value, isFalse);
  });
}

void _restore_should_stayOnTheMockInABuildThatCannotSwitch() {
  test(
    'restore should stay on the mock in a build that cannot switch',
    () async {
      final bootstrap = await AutomationModeBootstrap.restore(
        directory: _createDirectory().path,
        isSwitchable: false,
      );

      expect(bootstrap.mode, AutomationMode.server);
      expect(bootstrap.isOnMock, isTrue);
    },
  );
}

void _restore_should_readTheSavedMock() {
  test('restore should read the saved mock', () async {
    final directory = _createDirectory();

    await AutomationStateStore(
      directory.path,
    ).update((state) => state.copyWith(mode: AutomationMode.mock));

    final bootstrap = await AutomationModeBootstrap.restore(
      directory: directory.path,
      isSwitchable: true,
    );

    expect(bootstrap.mode, AutomationMode.mock);
    expect(bootstrap.isOnMock, isTrue);
  });
}

void _createModeController_should_shareTheRestartFlag() {
  test('createModeController should share the restart flag', () async {
    final bootstrap = await AutomationModeBootstrap.restore(
      directory: _createDirectory().path,
      isSwitchable: true,
    );

    final controller = bootstrap.createModeController();

    if (controller == null) {
      fail('The build can switch, so the controller must exist.');
    }

    addTearDown(controller.dispose);

    await controller.switchTo(AutomationMode.mock);

    expect(controller.mode, AutomationMode.server);
    expect(controller.nextMode, AutomationMode.mock);
    expect(bootstrap.isRestartRequired.value, isTrue);
  });
}

void _createModeController_should_returnNullInABuildThatCannotSwitch() {
  test(
    'createModeController should return null in a build that cannot switch',
    () async {
      final bootstrap = await AutomationModeBootstrap.restore(
        directory: _createDirectory().path,
        isSwitchable: false,
      );

      expect(bootstrap.createModeController(), isNull);
    },
  );
}
