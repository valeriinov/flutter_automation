import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils/sample_panel.dart';

const _launchKeyScenario = {
  'auth': {'isSignedInOnLaunch': false},
};

void main() {
  group('Automation Panel Controller Tests', () {
    _applyOutcome_should_dropTheFailuresOfThePreviousOutcome();
    _applyOutcome_should_mergeOutcomeFailuresWithTesterOverrides();
    _applyOutcome_should_saveTheWalkBeforeTheRestartAsk();
    _applyOutcome_should_reportThatARestartIsNeeded();
    _setFailure_should_notAskForARestart();
    _failureOf_should_matchTheParentPathOfAPathId();
    _setFailure_should_clearTheOverrideOfTheParentPath();
    _applyOutcome_should_keepTheOutcomeFailuresAcrossARestart();
    _applyOutcome_should_keepTheLatenciesOfTheTester();
    _latencyOf_should_matchTheParentPathOfAPathId();
    _failureOf_should_leaveAnExactEndpointUnderAPathIdAlone();
    _backendErrorCodesOf_should_addTheCodesOfTheEndpoint();
    _backendErrorStatusCodesOf_should_letTheEndpointReplaceTheStatusesOfACode();
    _overrideCount_should_countAPathWithAFailureAndALatencyOnce();
    _clearOverride_should_clearTheFailureAndTheLatency();
    _startWalk_should_saveTheWalkAndAskForARestart();
    _startWalk_should_keepTheModeAcrossARestart();
    _resumeWalk_should_runAnAutorunFromTheFirstStep();
    _playNext_should_doOneActionAndStopAtTheFork();
    _playNext_should_takeTheSelectedBranchAtTheFork();
    _finishWalk_should_saveTheReportOfAManualWalk();
    _chooseBranch_should_applyTheScenarioAndLetTheWalkGoOn();
    _playNext_should_stopWithTheReasonOfAFailedStep();
    _forkChoices_should_leaveOutABranchThatNeedsARestart();
    _exitWalk_should_endTheWalkAndGiveTheFingerBack();
    _didPopRoute_should_beHandledWhileAWalkRuns();
    _didPopRoute_should_stayFreeWhileTheLauncherIsHidden();
    _startWalk_should_askForARestartWhenTheScenarioHoldsTheKey();
    _playNext_should_openThePlaqueOnAFailure();
    _playNext_should_turnAnyErrorIntoAFailure();
    _runWalk_should_finishAnAutorunOfAVariantWithNoSteps();
    _runWalk_should_tryAgainAfterAFailure();
    _isAutorunPlaying_should_holdOnlyWhileTheAutorunPlays();
    _automationPanelController_should_failOnARestartKeyNoSettingsJsonHolds();
    _automationPanelController_should_acceptARestartKeyOnlyAProfileWrites();
  });
}

Future<SamplePanel> _createSample({
  SamplePanel? restartOf,
  AutomationFlowPlayer? player,
}) async {
  final sample = await SamplePanel.create(
    restartOf: restartOf,
    player: player,
    catalogue: sampleCatalogueWithSession,
  );

  addTearDown(() => _disposeAfterWrites(sample));

  return sample;
}

Future<void> _waitUntil(bool Function() isMet) async {
  for (int round = 0; round < 500 && !isMet(); round += 1) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _disposeAfterWrites(SamplePanel sample) async {
  await AutomationStateStore(sample.directory.path).update((state) => state);

  sample.dispose();
}

Map<String, Object?> _failureScenario(String path) {
  return {
    MockScenario.failuresKey: {path: const MockApiFailure().toJson()},
  };
}

void _applyOutcome_should_dropTheFailuresOfThePreviousOutcome() {
  test('applyOutcome should drop the failures of the previous outcome and '
      'keep the tester overrides', () async {
    final sample = await _createSample();

    final controller = sample.controller;

    await controller.applyOutcome(_failureScenario('/a'));
    await controller.setFailure('/b', const MockApiFailure(statusCode: 429));
    await controller.applyOutcome(const {});

    expect(controller.failures.keys, ['/b']);
  });
}

void _applyOutcome_should_mergeOutcomeFailuresWithTesterOverrides() {
  test('applyOutcome should merge the failures of the outcome with the tester '
      'overrides', () async {
    final sample = await _createSample();

    final controller = sample.controller;

    await controller.setFailure('/b', const MockApiFailure(statusCode: 429));
    await controller.applyOutcome(_failureScenario('/c'));

    expect(controller.failures.keys.toSet(), {'/b', '/c'});
  });
}

void _applyOutcome_should_saveTheWalkBeforeTheRestartAsk() {
  test('applyOutcome should save the walk before the restart ask', () async {
    Map<String, Object?>? savedWhenAsked;

    final sample = await _createSample();

    sample.isRestartRequired.addListener(() {
      savedWhenAsked =
          jsonDecode(
                File('${sample.directory.path}/state.json').readAsStringSync(),
              )
              as Map<String, Object?>;
    });

    await sample.controller.applyOutcome(
      _launchKeyScenario,
      walk: const AutomationWalkProgress(
        flow: 'login',
        variant: 'signUpNeeded',
      ),
    );

    final walk = savedWhenAsked?['walk'] as Map<String, Object?>?;

    expect(walk?['flow'], 'login');
    expect(walk?['variant'], 'signUpNeeded');
    expect(savedWhenAsked?['scenario'], _launchKeyScenario);
  });
}

void _applyOutcome_should_reportThatARestartIsNeeded() {
  test('applyOutcome should report that a restart is needed', () async {
    final sample = await _createSample();
    final needsRestart = await sample.controller.applyOutcome(
      _launchKeyScenario,
    );
    final needsNone = await sample.controller.applyOutcome(const {});

    expect(needsRestart, isTrue);
    expect(needsNone, isFalse);
  });
}

void _setFailure_should_notAskForARestart() {
  test('setFailure should not ask for a restart', () async {
    final sample = await _createSample();

    await sample.controller.applyOutcome(_launchKeyScenario);

    sample.isRestartRequired.value = false;

    await sample.controller.setFailure('/b', const MockApiFailure());

    expect(sample.isRestartRequired.value, isFalse);
  });
}

void _failureOf_should_matchTheParentPathOfAPathId() {
  test('failureOf should match the parent path of a path id', () async {
    final sample = await _createSample();

    await sample.controller.setFailure('/items', const MockApiFailure());

    expect(sample.controller.failureOf('/items/7'), isNotNull);
    expect(sample.controller.failureOf('/other/7'), isNull);
  });
}

void _backendErrorCodesOf_should_addTheCodesOfTheEndpoint() {
  test('backendErrorCodesOf should add the codes of the endpoint', () async {
    final sample = await _createSample();

    final controller = sample.controller;

    expect(controller.backendErrorCodesOf('/items/7'), [
      'tooManyRequests',
      'invalidPhone',
      'itemLocked',
    ]);
    expect(controller.backendErrorCodesOf('/auth/otp'), [
      'tooManyRequests',
      'invalidPhone',
    ]);
  });
}

void
_backendErrorStatusCodesOf_should_letTheEndpointReplaceTheStatusesOfACode() {
  test(
    'backendErrorStatusCodesOf should let the endpoint replace the statuses of '
    'a code',
    () async {
      final sample = await _createSample();

      final controller = sample.controller;

      expect(controller.backendErrorStatusCodesOf('/items/7'), {
        'tooManyRequests': {503},
        'itemLocked': {409, 423},
      });
      expect(controller.backendErrorStatusCodesOf('/auth/otp'), {
        'tooManyRequests': {429},
      });
    },
  );
}

void _setFailure_should_clearTheOverrideOfTheParentPath() {
  test('setFailure should clear the override of the parent path', () async {
    final sample = await _createSample();

    await sample.controller.setFailure('/items', const MockApiFailure());
    await sample.controller.setFailure('/items/7', null);

    expect(sample.controller.failureOf('/items/7'), isNull);
    expect(sample.controller.failures, isEmpty);
  });
}

void _applyOutcome_should_keepTheLatenciesOfTheTester() {
  test('applyOutcome should keep the latencies of the tester', () async {
    final sample = await _createSample();

    final controller = sample.controller;

    await controller.setLatency('/b', MockLatencyProfile.slow);
    await controller.applyOutcome(_failureScenario('/c'));

    expect(controller.latencies, {'/b': MockLatencyProfile.slow});
    expect(controller.failures.keys, ['/c']);
  });
}

void _latencyOf_should_matchTheParentPathOfAPathId() {
  test('latencyOf should match the parent path of a path id', () async {
    final sample = await _createSample();

    final controller = sample.controller;

    await controller.setLatency('/items', MockLatencyProfile.slow);

    expect(controller.latencyOf('/items/7'), MockLatencyProfile.slow);
    expect(controller.latencyOf('/items/7/photos'), MockLatencyProfile.slow);
    expect(controller.latencyOf('/other'), isNull);

    await controller.setLatency('/items/7', null);

    expect(controller.latencies, isEmpty);
  });
}

void _failureOf_should_leaveAnExactEndpointUnderAPathIdAlone() {
  test(
    'failureOf should leave an exact endpoint under a path id alone',
    () async {
      final sample = await _createSample();

      final controller = sample.controller;

      await controller.setResponse(
        '/items',
        failure: const MockApiFailure(),
        latency: MockLatencyProfile.slow,
      );

      expect(controller.failureOf('/items/list'), isNull);
      expect(controller.latencyOf('/items/list'), isNull);
      expect(controller.failureOf('/items/7'), isNotNull);
    },
  );
}

void _overrideCount_should_countAPathWithAFailureAndALatencyOnce() {
  test(
    'overrideCount should count a path with a failure and a latency once',
    () async {
      final sample = await _createSample();

      final controller = sample.controller;

      await controller.setResponse(
        '/a',
        failure: const MockApiFailure(),
        latency: MockLatencyProfile.slow,
      );
      await controller.setLatency('/b', MockLatencyProfile.fast);

      expect(controller.overrideCount, 2);
    },
  );
}

void _clearOverride_should_clearTheFailureAndTheLatency() {
  test('clearOverride should clear the failure and the latency', () async {
    final sample = await _createSample();

    final controller = sample.controller;

    await controller.setResponse(
      '/a',
      failure: const MockApiFailure(),
      latency: MockLatencyProfile.slow,
    );
    await controller.clearOverride('/a');

    expect(controller.failures, isEmpty);
    expect(controller.latencies, isEmpty);
    expect(controller.overrideCount, 0);
  });
}

void _applyOutcome_should_keepTheOutcomeFailuresAcrossARestart() {
  test('applyOutcome should keep the outcome failures apart from the tester '
      'overrides across a restart', () async {
    final first = await _createSample();

    await first.controller.applyOutcome(_failureScenario('/a'));

    final second = await _createSample(restartOf: first);

    await second.controller.applyOutcome(const {});

    expect(second.controller.failures, isEmpty);
  });
}

void _startWalk_should_saveTheWalkAndAskForARestart() {
  test('startWalk should save the walk and ask for a restart', () async {
    final plain = await _createSample();

    await plain.controller.startWalk('login', 'signUpNeeded');

    final launchKey = await _createSample();

    await launchKey.controller.startWalk('session', 'signedOut');

    expect(plain.isRestartRequired.value, isTrue);
    expect(launchKey.isRestartRequired.value, isTrue);
    expect(plain.mock.walk?.variant, 'signUpNeeded');
    expect(plain.mock.walk?.stepIndex, 0);
  });
}

void _startWalk_should_keepTheModeAcrossARestart() {
  test('startWalk should keep the mode across a restart', () async {
    final first = await _createSample();

    await first.controller.startWalk(
      'login',
      'signUpNeeded',
      mode: AutomationWalkMode.autorun,
      shouldShowTouches: false,
    );

    final second = await _createSample(restartOf: first);

    expect(second.controller.walk?.mode, AutomationWalkMode.autorun);
    expect(second.controller.walk?.shouldShowTouches, isFalse);
    expect(second.controller.walk?.stepIndex, 0);
  });
}

void _resumeWalk_should_runAnAutorunFromTheFirstStep() {
  test('resumeWalk should run an autorun from the first step', () async {
    final first = await _createSample();

    await first.controller.startWalk(
      'login',
      'signUpNeeded',
      mode: AutomationWalkMode.autorun,
      shouldSignalEnd: false,
    );

    final player = RecordingPlayer();

    final second = await _createSample(restartOf: first, player: player);

    second.controller.resumeWalk();

    await _waitUntil(() => second.controller.runSummary != null);

    expect(player.played.first, 'Phone screen');
    expect(player.played, hasLength(5));
    expect(second.controller.runSummary?.stepCount, 2);
    expect(second.mock.walk, isNull);
  });
}

void _playNext_should_doOneActionAndStopAtTheFork() {
  test('playNext should do one action and stop at the fork', () async {
    final player = RecordingPlayer();

    final sample = await _createSample(player: player);

    await sample.controller.startWalk('login', 'signUpNeeded');
    await sample.controller.playNext();

    expect(player.played, ['Phone screen', 'After code entry']);
    expect(sample.mock.walk?.stepIndex, 2);
    expect(sample.controller.pendingFork, isNotNull);
    expect(sample.controller.selectedBranch, 'signUpNeeded');
  });
}

void _playNext_should_takeTheSelectedBranchAtTheFork() {
  test('playNext should take the selected branch at the fork', () async {
    final player = RecordingPlayer();

    final sample = await _createSample(player: player);

    await sample.controller.startWalk('login', 'signUpNeeded');
    await sample.controller.playNext();

    sample.controller.selectBranch('accountExists');

    await sample.controller.playNext();

    expect(sample.mock.walk?.variant, 'accountExists');
    expect(sample.controller.pendingFork, isNull);
    expect(player.played.length, greaterThan(2));
  });
}

void _finishWalk_should_saveTheReportOfAManualWalk() {
  test('finishWalk should save the report of a manual walk', () async {
    final sample = await _createSample(player: RecordingPlayer());

    await sample.controller.startWalk('login', 'signUpNeeded');
    await sample.controller.playNext();

    sample.controller.selectBranch('accountExists');

    await sample.controller.playNext();
    await sample.controller.finishWalk();

    final summary = sample.controller.runSummary;
    final report = summary?.report;

    expect(summary?.mode, AutomationWalkMode.manual);
    expect(summary?.variant, 'accountExists');
    expect(sample.mock.walk, isNull);
    expect(report?.path, endsWith('report.json'));
    expect(report?.readAsStringSync(), contains('"mode": "manual"'));
  });
}

void _chooseBranch_should_applyTheScenarioAndLetTheWalkGoOn() {
  test(
    'chooseBranch should apply the scenario and let the walk go on',
    () async {
      final player = RecordingPlayer();

      final sample = await _createSample(player: player);

      await sample.controller.startWalk('login', 'signUpNeeded');
      await sample.controller.playNext();
      await sample.controller.chooseBranch('accountExists');

      expect(sample.mock.walk?.variant, 'accountExists');
      expect(sample.mock.scenario.toJson()['auth'], {'codeDelay': 0});
      expect(sample.controller.pendingFork, isNull);

      await sample.controller.playNext();

      expect(player.played.last, 'trace');
      expect(sample.controller.isWalkFinished, isTrue);
    },
  );
}

void _playNext_should_stopWithTheReasonOfAFailedStep() {
  test('playNext should stop with the reason of a failed step', () async {
    final player = RecordingPlayer(failingLabel: 'After code entry');

    final sample = await _createSample(player: player);

    await sample.controller.startWalk('login', 'signUpNeeded');
    await sample.controller.playNext();

    expect(sample.controller.walkFailure, contains('did not appear'));
    expect(sample.mock.walk?.stepIndex, 1);
    expect(sample.controller.isWalkBusy, isFalse);
  });
}

void _forkChoices_should_leaveOutABranchThatNeedsARestart() {
  test('forkChoices should leave out a branch that needs a restart', () async {
    final first = await _createSample();

    await first.controller.startWalk('session', 'signedIn');

    final second = await _createSample(restartOf: first);

    expect(second.controller.forkChoices.map((branch) => branch.variant), [
      'signedIn',
    ]);
    expect(second.controller.pendingFork, isNull);
  });
}

void _exitWalk_should_endTheWalkAndGiveTheFingerBack() {
  test('exitWalk should end the walk and give the finger back', () async {
    final sample = await _createSample(player: RecordingPlayer());

    await sample.controller.startWalk('login', 'signUpNeeded');

    expect(sample.controller.isWalkActive, isTrue);

    await sample.controller.exitWalk();

    expect(sample.controller.isWalkActive, isFalse);
    expect(sample.mock.walk, isNull);
  });
}

void _didPopRoute_should_beHandledWhileAWalkRuns() {
  test('didPopRoute should be handled while a walk runs', () async {
    final sample = await _createSample(player: RecordingPlayer());

    sample.controller.isLauncherVisible = true;

    expect(await sample.controller.didPopRoute(), isFalse);

    await sample.controller.startWalk('login', 'signUpNeeded');

    expect(await sample.controller.didPopRoute(), isTrue);

    await sample.controller.exitWalk();

    expect(await sample.controller.didPopRoute(), isFalse);
  });
}

void _didPopRoute_should_stayFreeWhileTheLauncherIsHidden() {
  test('didPopRoute should stay free while the launcher is hidden', () async {
    final sample = await _createSample(player: RecordingPlayer());

    await sample.controller.startWalk('login', 'signUpNeeded');

    expect(sample.controller.isWalkActive, isTrue);
    expect(await sample.controller.didPopRoute(), isFalse);
  });
}

void _startWalk_should_askForARestartWhenTheScenarioHoldsTheKey() {
  test('startWalk should ask for a restart when the scenario holds the '
      'restart key', () async {
    final sample = await _createSample();

    await sample.controller.applyOutcome(_launchKeyScenario);

    sample.isRestartRequired.value = false;

    await sample.controller.startWalk('session', 'signedOut');

    expect(sample.isRestartRequired.value, isTrue);
    expect(sample.mock.walk?.variant, 'signedOut');
  });
}

void _playNext_should_openThePlaqueOnAFailure() {
  test('playNext should open the plaque on a failure', () async {
    final player = RecordingPlayer(failingLabel: 'After code entry');

    final sample = await _createSample(player: player);

    await sample.controller.startWalk('login', 'signUpNeeded');
    await sample.controller.playNext();

    expect(sample.controller.isWalkExpanded, isTrue);
  });
}

void _playNext_should_turnAnyErrorIntoAFailure() {
  test('playNext should turn any error into a failure', () async {
    final player = RecordingPlayer(
      failingLabel: 'After code entry',
      failingError: StateError('boom'),
    );

    final sample = await _createSample(player: player);

    await sample.controller.startWalk('login', 'signUpNeeded');
    await sample.controller.playNext();

    expect(sample.controller.walkFailure, contains('boom'));
    expect(sample.controller.isWalkBusy, isFalse);
    expect(sample.controller.isWalkExpanded, isTrue);
  });
}

void _runWalk_should_finishAnAutorunOfAVariantWithNoSteps() {
  test('runWalk should finish an autorun of a variant with no steps', () async {
    final sample = await _createSample(player: RecordingPlayer());

    await sample.controller.startWalk(
      'itemCreate',
      'a',
      mode: AutomationWalkMode.autorun,
      shouldSignalEnd: false,
    );
    await sample.controller.runWalk();

    expect(sample.controller.runSummary?.stepCount, 0);
    expect(sample.mock.walk, isNull);
    expect(sample.controller.isWalkBusy, isFalse);
  });
}

void _runWalk_should_tryAgainAfterAFailure() {
  test('runWalk should try again after a failure', () async {
    final player = RecordingPlayer(failingLabel: 'After code entry');

    final sample = await _createSample(player: player);

    await sample.controller.startWalk(
      'login',
      'signUpNeeded',
      mode: AutomationWalkMode.autorun,
      shouldSignalEnd: false,
    );
    await sample.controller.runWalk();

    expect(sample.controller.walkFailure, isNotNull);
    expect(sample.controller.runSummary, isNull);

    player.failingLabel = null;

    await sample.controller.runWalk();

    expect(sample.controller.walkFailure, isNull);
    expect(sample.controller.runSummary?.stepCount, 2);
  });
}

void _isAutorunPlaying_should_holdOnlyWhileTheAutorunPlays() {
  test('isAutorunPlaying should hold only while the autorun plays', () async {
    final release = Completer<void>();
    final player = RecordingPlayer(hold: release.future);

    final sample = await _createSample(player: player);

    await sample.controller.startWalk(
      'login',
      'signUpNeeded',
      mode: AutomationWalkMode.autorun,
      shouldSignalEnd: false,
    );

    expect(sample.controller.isAutorunPlaying, isFalse);

    final run = sample.controller.runWalk();

    expect(sample.controller.isAutorunPlaying, isTrue);
    release.complete();

    await run;

    expect(sample.controller.isAutorunPlaying, isFalse);
  });
}

Future<AutomationPanelController> _createControllerOf(
  MockSection<Map<String, Object?>> section,
) async {
  final directory = Directory.systemTemp.createTempSync('restart_keys');

  addTearDown(() => directory.deleteSync(recursive: true));

  final mock = await AutomationMock.init(
    isEnabled: true,
    scenarioDirectory: directory.path,
    stateStore: AutomationStateStore(directory.path),
    sections: [section],
  );

  final isRestartRequired = ValueNotifier(false);

  addTearDown(isRestartRequired.dispose);

  final controller = AutomationPanelController(
    AutomationPanelDefinition.standard(
      mock: mock,
      catalogue: sampleCatalogue,
      isRestartRequired: isRestartRequired,
    ),
  );

  addTearDown(controller.dispose);

  return controller;
}

void _automationPanelController_should_failOnARestartKeyNoSettingsJsonHolds() {
  test(
    'AutomationPanelController should fail on an unknown restart key',
    () async {
      final section = MockSection<Map<String, Object?>>(
        name: 'auth',
        title: const AutomationLocalizedText({'en': 'Auth'}),
        fromJson: (json) => json,
        profiles: {
          'slowCode': MockProfile(
            (settings) => {...settings, 'codeDelay': 3},
            title: const AutomationLocalizedText({'en': 'Slow code'}),
          ),
        },
        restartKeys: {'isSignedInOnLaunch'},
      );

      await expectLater(
        () => _createControllerOf(section),
        throwsA(
          isA<AssertionError>().having(
            (error) => error.message.toString(),
            'message',
            allOf(contains('auth'), contains('isSignedInOnLaunch')),
          ),
        ),
      );
    },
  );
}

void _automationPanelController_should_acceptARestartKeyOnlyAProfileWrites() {
  test(
    'AutomationPanelController should accept a profile-only restart key',
    () async {
      await expectLater(_createControllerOf(authSection), completes);
    },
  );
}
