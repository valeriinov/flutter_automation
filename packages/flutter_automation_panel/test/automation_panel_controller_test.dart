import 'dart:async';

import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils/sample_panel.dart';

const _verifyPath = '/auth/otp';
const _launchKeyScenario = {
  'auth': {'isSignedInOnLaunch': false},
};

void main() {
  group('Automation Panel Controller Tests', () {
    _applyOutcome_should_dropTheFailuresOfThePreviousOutcome();
    _applyOutcome_should_mergeOutcomeFailuresWithTesterOverrides();
    _applyOutcome_should_saveTheWalkBeforeTheRestartAsk();
    _applyOutcome_should_reportThatARestartIsNeeded();
    _setFailure_should_notAskForARestartAgain();
    _failureOf_should_matchTheParentPathOfAPathId();
    _setFailure_should_clearTheOverrideOfTheParentPath();
    _applyOutcome_should_keepTheOutcomeFailuresAcrossARestart();
    _journal_should_moveTheWalkOnANewRequest();
    _journal_should_notMoveTheWalkOnAResponse();
  });
}

Future<SamplePanel> _createSample({
  FutureOr<void> Function()? onRestartRequired,
  SamplePanel? restartOf,
}) async {
  final sample = await SamplePanel.create(
    onRestartRequired: onRestartRequired,
    restartOf: restartOf,
  );

  addTearDown(() => _disposeAfterWrites(sample));

  return sample;
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
    final sample = await _createSample(
      onRestartRequired: () => Completer<void>().future,
    );

    unawaited(
      sample.controller.applyOutcome(
        _launchKeyScenario,
        walk: const AutomationWalkProgress(
          flow: 'login',
          variant: 'signUpNeeded',
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 100));

    final state = await sample.mock.stateStore?.read();

    expect(sample.mock.walk?.flow, 'login');
    expect(state?.walk?.variant, 'signUpNeeded');
    expect(state?.scenario, _launchKeyScenario);
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

void _setFailure_should_notAskForARestartAgain() {
  test('setFailure should not ask for a restart again', () async {
    final sample = await _createSample();

    await sample.controller.applyOutcome(_launchKeyScenario);
    await sample.controller.setFailure('/b', const MockApiFailure());

    expect(sample.events.where((event) => event == 'restart'), hasLength(1));
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

void _setFailure_should_clearTheOverrideOfTheParentPath() {
  test('setFailure should clear the override of the parent path', () async {
    final sample = await _createSample();

    await sample.controller.setFailure('/items', const MockApiFailure());
    await sample.controller.setFailure('/items/7', null);

    expect(sample.controller.failureOf('/items/7'), isNull);
    expect(sample.controller.failures, isEmpty);
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

void _journal_should_moveTheWalkOnANewRequest() {
  test('the controller should move the walk on a new request', () async {
    final sample = await _createSample();

    await sample.controller.startWalk('login', 'signUpNeeded');

    sample.mock.journal.addRequest({'method': 'POST', 'path': _verifyPath});
    expect(sample.mock.walk?.stepIndex, 2);
  });
}

void _journal_should_notMoveTheWalkOnAResponse() {
  test('the controller should not move the walk on a response', () async {
    final sample = await _createSample();

    await sample.controller.startWalk('login', 'signUpNeeded');

    final record = sample.mock.journal.addRequest({
      'method': 'POST',
      'path': _verifyPath,
    });

    await sample.controller.moveWalk(0);

    sample.mock.journal.attachResponse(record, statusCode: 200, body: {});
    expect(sample.mock.walk?.stepIndex, 0);
  });
}
