import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/automation_recording.dart';

const _request = {
  'seq': 0,
  'kind': 'request',
  'method': 'POST',
  'path': '/auth/otp',
  'status': 400,
  'response': {'code': 'wrong'},
};

const _plainReport = {
  'flow': 'login',
  'variant': 'otp',
  'ok': true,
  'totalMs': 120,
  'steps': [
    {
      'label': 'tap send',
      'action': 'tap',
      'ms': 40,
      'ok': true,
      'journal': [_request],
    },
    {'label': 'wait', 'action': 'waitFor', 'ms': 80, 'ok': true},
  ],
};

const _captureReport = {
  'flow': 'login',
  'variant': 'otp',
  'ok': true,
  'totalMs': 120,
  'endScreenshot': 'login_otp_end.png',
  'steps': [
    {
      'label': 'tap send',
      'action': 'tap',
      'ms': 40,
      'ok': true,
      'screenshot': 'login_otp_1.png',
      'journalBeforeAction': <Object?>[],
      'journal': [_request],
    },
    {
      'label': 'wait',
      'action': 'waitFor',
      'ms': 80,
      'ok': true,
      'screenshot': null,
      'journalBeforeAction': [
        {'kind': 'request', 'method': 'GET', 'path': '/late', 'status': 200},
      ],
      'journal': <Object?>[],
    },
  ],
};

const _lateRequest = {
  'kind': 'request',
  'method': 'GET',
  'path': '/late',
  'status': 200,
};
const _trailingRequest = {
  'kind': 'request',
  'method': 'GET',
  'path': '/trailing',
  'status': 200,
};

const _plainRecordReport = {
  'flow': 'login',
  'variant': 'otp',
  'ok': true,
  'totalMs': 120,
  'endJournal': [_trailingRequest],
  'steps': [
    {
      'label': 'tap send',
      'action': 'tap',
      'ms': 40,
      'ok': true,
      'journalBeforeAction': <Object?>[],
      'journal': [_request],
    },
    {
      'label': 'wait',
      'action': 'waitFor',
      'ms': 80,
      'ok': true,
      'journalBeforeAction': [_lateRequest],
      'journal': <Object?>[],
    },
  ],
};

void main() {
  group('AutomationRecording Tests', () {
    _automationRecording_should_readRequestsOfAPlainRun();
    _automationRecording_should_giveACaptureRunAndAPlainRunOneSchema();
    _automationRecording_should_joinLateRequestsToThePreviousStep();
    _automationRecording_should_assignRequestsOfAPlainRecordRunAsACapture();
    _automationRecording_should_roundTripThroughJson();
    _automationRecording_should_markServiceSteps();
    _automationRecording_should_keepTheStepJson();
  });
}

void _automationRecording_should_readRequestsOfAPlainRun() {
  test('AutomationRecording should read requests of a plain run', () {
    final recording = AutomationRecording.fromReport(_plainReport);
    final request = recording.steps.first.requests.single;

    expect(request.method, 'POST');
    expect(request.path, '/auth/otp');
    expect(request.statusCode, 400);
    expect(request.response, {'code': 'wrong'});
    expect(recording.steps.last.requests, isEmpty);
  });
}

void _automationRecording_should_giveACaptureRunAndAPlainRunOneSchema() {
  test(
    'AutomationRecording should give a capture run and a plain run one schema',
    () {
      final plain = AutomationRecording.fromReport(_plainReport).toJson();
      final capture = AutomationRecording.fromReport(_captureReport).toJson();
      final plainStep = (plain['steps'] as List<Object?>).first;
      final captureStep = (capture['steps'] as List<Object?>).first;

      expect(
        plain.keys,
        containsAll(['flow', 'variant', 'ok', 'totalMs', 'steps']),
      );
      expect(
        (captureStep as Map<String, Object?>).keys.toSet().difference(
          (plainStep as Map<String, Object?>).keys.toSet(),
        ),
        {'screenshot'},
      );
      expect(capture['endScreenshot'], 'login_otp_end.png');
    },
  );
}

void _automationRecording_should_joinLateRequestsToThePreviousStep() {
  test(
    'AutomationRecording should join late requests to the previous step',
    () {
      final recording = AutomationRecording.fromReport(_captureReport);

      expect(recording.steps.first.requests.map((r) => r.path), [
        '/auth/otp',
        '/late',
      ]);
    },
  );
}

void _automationRecording_should_assignRequestsOfAPlainRecordRunAsACapture() {
  test('AutomationRecording should assign the requests of a plain record run '
      'as a capture does', () {
    final plain = AutomationRecording.fromReport(_plainRecordReport);
    final capture = AutomationRecording.fromReport(_captureReport);

    expect(
      plain.steps.first.requests.map((request) => request.path),
      capture.steps.first.requests.map((request) => request.path),
    );
    expect(plain.steps.last.requests.map((request) => request.path), [
      '/trailing',
    ]);
  });
}

void _automationRecording_should_roundTripThroughJson() {
  test('AutomationRecording should round trip through json', () {
    final recording = AutomationRecording.fromReport(_captureReport);

    expect(
      AutomationRecording.fromJson(recording.toJson()).toJson(),
      recording.toJson(),
    );
  });
}

void _automationRecording_should_markServiceSteps() {
  test('AutomationRecording should mark service steps', () {
    final recording = AutomationRecording.fromReport({
      'flow': 'f',
      'variant': 'v',
      'steps': [
        {'label': 'trace', 'action': 'traceStart', 'ok': true},
        {'label': 'tap', 'action': 'tap', 'ok': true},
      ],
    });

    expect(recording.steps.map((step) => step.isService), [true, false]);
  });
}

void _automationRecording_should_keepTheStepJson() {
  test('AutomationRecording should keep the step JSON', () {
    const step = {
      'action': 'tap',
      'finder': {'by': 'valueKey', 'value': 'login.sign_in'},
    };
    final recording = AutomationRecording.fromReport({
      'flow': 'login',
      'variant': 'otp',
      'ok': true,
      'steps': [
        {'label': 'tap', 'action': 'tap', 'ok': true, 'step': step},
      ],
    });
    final restored = AutomationRecording.fromJson(recording.toJson());

    expect(restored.steps.single.step, step);
  });
}
