import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart'
    show DriverError, FlutterDriver, ScreenshotFormat, SerializableFinder;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'package:flutter_automation_runner/automation_flow_definition.dart';
import 'package:flutter_automation_runner/src/automation_runner.dart';
import 'package:flutter_automation_runner/src/automation_runner_config.dart';

const _config = AutomationRunnerConfig(packagePrefix: 'package:sample_app/');
const _grace = Duration(milliseconds: 300);
const _readyFrame = _FakeFrame(loadingImages: 0, emptyTexts: 0);
const _loadingImageFrame = _FakeFrame(loadingImages: 2, emptyTexts: 0);
const _emptyTextFrame = _FakeFrame(
  loadingImages: 0,
  emptyTexts: 1,
  emptyTextItems: [
    {
      'rect': [10, 20, 30, 40],
      'target': 'form.title',
    },
  ],
);

void main() {
  tearDown(() => exitCode = 0);
  group('AutomationRunner Frame Defect Tests', () {
    _automationRunner_should_passAReadyFrame();
    _automationRunner_should_failOnAFrameStillAnimating();
    _automationRunner_should_failOnAnImageStillLoading();
    _automationRunner_should_failOnAnEmptyText();
    _automationRunner_should_failOnAnEndFrameDefect();
    _automationRunner_should_reportTheItemsOfAFrameDefect();
    _automationRunner_should_waitForAnImageThatLoadsInTheGrace();
    _automationRunner_should_passAFrameDeclaredAsLoadingState();
    _automationRunner_should_skipTheAnimationOfAFrameDeclaredAsLoadingState();
    _automationRunner_should_checkTheFrameAfterAWaitForAStepThatShowsLoading();
    _automationRunner_should_failOnAFrameThatStartsAnimatingInTheGrace();
    _automationRunner_should_failWhenTheDriverCannotReadTheFrame();
    _automationRunner_should_failWhenTheDriverCannotReadTheEndFrame();
  });
}

void _automationRunner_should_passAReadyFrame() {
  test('AutomationRunner should pass a ready frame', () async {
    final run = await _run(_twoTaps(), frameAfterShots: (_) => _readyFrame);

    expect(run.report['ok'], isTrue);
    expect(run.report.containsKey('frameDefect'), isFalse);
    expect(run.endScreenshot.existsSync(), isTrue);
    expect(run.recording.existsSync(), isTrue);
    expect(exitCode, 0);
  });
}

void _automationRunner_should_failOnAFrameStillAnimating() {
  test('AutomationRunner should fail on a frame still animating', () async {
    final run = await _run(
      _twoTaps(),
      isAnimatingAfterShots: (shots) => shots == 1,
    );

    _expectFailedAtStepTwo(run, 'animating');
  });
}

void _automationRunner_should_failOnAnImageStillLoading() {
  test('AutomationRunner should fail on an image still loading', () async {
    final run = await _run(
      _twoTaps(),
      frameAfterShots: (shots) => shots == 1 ? _loadingImageFrame : _readyFrame,
    );

    _expectFailedAtStepTwo(run, 'loadingImage');
    expect((run.report['frameDefect'] as Map)['count'], 2);
  });
}

void _automationRunner_should_failOnAnEmptyText() {
  test('AutomationRunner should fail on an empty text', () async {
    final run = await _run(
      _twoTaps(),
      frameAfterShots: (shots) => shots == 1 ? _emptyTextFrame : _readyFrame,
    );

    _expectFailedAtStepTwo(run, 'emptyText');
  });
}

void _automationRunner_should_failOnAnEndFrameDefect() {
  test('AutomationRunner should fail on an end frame defect', () async {
    final run = await _run(
      _twoTaps(),
      frameAfterShots: (shots) => shots == 2 ? _emptyTextFrame : _readyFrame,
    );

    expect(run.report['ok'], isFalse);
    expect(run.report['frameDefect'], {
      'step': 'end',
      'kind': 'emptyText',
      'count': 1,
      'items': [
        {
          'rect': [10, 20, 30, 40],
          'target': 'form.title',
        },
      ],
    });
    expect(run.report.containsKey('screenshot'), isFalse);
    expect(run.report.containsKey('error'), isFalse);
    expect(
      (run.report['steps'] as List).last,
      allOf(
        containsPair('label', 'end'),
        containsPair('ok', false),
        containsPair('frameDefect', run.report['frameDefect']),
      ),
    );
    expect(run.endScreenshot.existsSync(), isFalse);
    expect(run.recording.existsSync(), isFalse);
    expect(exitCode, 1);
  });
}

void _automationRunner_should_reportTheItemsOfAFrameDefect() {
  test('AutomationRunner should report the items of a frame defect', () async {
    final run = await _run(
      _twoTaps(),
      frameAfterShots: (shots) => shots == 1 ? _emptyTextFrame : _readyFrame,
    );

    expect((run.report['frameDefect'] as Map)['items'], [
      {
        'rect': [10, 20, 30, 40],
        'target': 'form.title',
      },
    ]);
    expect(
      ((run.report['steps'] as List).last as Map)['error'],
      contains('first at [10, 20, 30, 40], inside form.title'),
    );
  });
}

void _automationRunner_should_waitForAnImageThatLoadsInTheGrace() {
  test(
    'AutomationRunner should wait for an image that loads in the grace',
    () async {
      final run = await _run(
        _twoTaps(),
        frameAfterShots: (_) => _readyFrame,
        loadingReadsBeforeReady: 2,
      );

      expect(run.report['ok'], isTrue);
      expect(run.report.containsKey('frameDefect'), isFalse);
    },
  );
}

void _automationRunner_should_passAFrameDeclaredAsLoadingState() {
  test(
    'AutomationRunner should pass a frame declared as loading state',
    () async {
      final run = await _run(
        [const Tap(ByText('A'), showsLoading: true), const Tap(ByText('B'))],
        frameAfterShots: (shots) => shots == 1 ? _emptyTextFrame : _readyFrame,
      );

      expect(run.report['ok'], isTrue);
      expect(run.report.containsKey('frameDefect'), isFalse);
      expect(run.recording.existsSync(), isTrue);
    },
  );
}

void _automationRunner_should_skipTheAnimationOfAFrameDeclaredAsLoadingState() {
  test('AutomationRunner should skip the animation of a frame declared as '
      'loading state', () async {
    final run = await _run([
      const Tap(ByText('A'), showsLoading: true),
      const Tap(ByText('B')),
    ], isAnimatingAfterShots: (shots) => shots == 1);

    expect(run.report['ok'], isTrue);
    expect(run.report.containsKey('frameDefect'), isFalse);
  });
}

void
_automationRunner_should_checkTheFrameAfterAWaitForAStepThatShowsLoading() {
  test('AutomationRunner should check the frame after a wait for a step that '
      'shows loading', () async {
    final run = await _run([
      const Tap(ByText('A'), showsLoading: true),
      const WaitFor(ByText('Loader')),
      const Tap(ByText('B')),
    ], frameAfterShots: (shots) => shots == 1 ? _emptyTextFrame : _readyFrame);

    expect(run.report['ok'], isFalse);
    expect((run.report['frameDefect'] as Map)['step'], 3);
    expect((run.report['frameDefect'] as Map)['kind'], 'emptyText');
  });
}

void _automationRunner_should_failOnAFrameThatStartsAnimatingInTheGrace() {
  test('AutomationRunner should fail on a frame that starts animating in the '
      'grace', () async {
    final run = await _run(
      _twoTaps(),
      loadingReadsBeforeReady: 1,
      isAnimatingOnWait: (waits) => waits == 2,
    );

    expect((run.report['frameDefect'] as Map)['step'], 1);
    expect((run.report['frameDefect'] as Map)['kind'], 'animating');
    expect(run.endScreenshot.existsSync(), isFalse);
    expect(exitCode, 1);
  });
}

void _automationRunner_should_failWhenTheDriverCannotReadTheFrame() {
  test(
    'AutomationRunner should fail when the driver cannot read the frame',
    () async {
      final run = await _run(_twoTaps(), frameReadFailsAfterShots: (_) => true);

      expect(run.report['ok'], isFalse);
      expect(run.report.containsKey('frameDefect'), isFalse);

      final failedStep = (run.report['steps'] as List).firstWhere(
        (step) => (step as Map)['ok'] == false,
      );

      expect(
        (failedStep as Map)['error'],
        allOf(
          contains('Could not read the frame before step 1'),
          contains('frame.read'),
        ),
      );
      expect(run.endScreenshot.existsSync(), isFalse);
      expect(exitCode, 1);
    },
  );
}

void _automationRunner_should_failWhenTheDriverCannotReadTheEndFrame() {
  test(
    'AutomationRunner should fail when the driver cannot read the end frame',
    () async {
      final run = await _run(
        _twoTaps(),
        frameReadFailsAfterShots: (shots) => shots == 2,
      );

      expect(run.report['ok'], isFalse);
      expect(run.report.containsKey('error'), isFalse);
      expect(
        ((run.report['steps'] as List).last as Map)['error'],
        contains('Could not read the frame before step end'),
      );
      expect(exitCode, 1);
    },
  );
}

List<FlowStep> _twoTaps() => const [Tap(ByText('A')), Tap(ByText('B'))];

void _expectFailedAtStepTwo(_Run run, String kind) {
  expect(run.report['ok'], isFalse);
  expect((run.report['frameDefect'] as Map)['step'], 2);
  expect((run.report['frameDefect'] as Map)['kind'], kind);
  expect(
    (run.report['steps'] as List).last,
    containsPair('frameDefect', run.report['frameDefect']),
  );
  expect(run.endScreenshot.existsSync(), isFalse);
  expect(run.recording.existsSync(), isFalse);
  expect(exitCode, 1);
}

Future<_Run> _run(
  List<FlowStep> steps, {
  _FakeFrame Function(int shots)? frameAfterShots,
  bool Function(int shots)? isAnimatingAfterShots,
  bool Function(int waits)? isAnimatingOnWait,
  bool Function(int shots)? frameReadFailsAfterShots,
  int loadingReadsBeforeReady = 0,
}) async {
  final directory = Directory.systemTemp.createTempSync('frame_defect_');

  addTearDown(() => directory.deleteSync(recursive: true));

  final driver = _FakeDriver(
    frameAfterShots: frameAfterShots ?? (_) => _readyFrame,
    isAnimatingAfterShots: isAnimatingAfterShots ?? (_) => false,
    isAnimatingOnWait: isAnimatingOnWait ?? (_) => false,
    frameReadFailsAfterShots: frameReadFailsAfterShots ?? (_) => false,
    loadingReadsBeforeReady: loadingReadsBeforeReady,
  );
  final lines = <String>[];
  final sut = AutomationRunner.fromDefinitions(
    [
      'demo',
      'main',
      '--uri',
      'ws://sample',
      '--capture',
      '${directory.path}/capture',
      '--record',
      '${directory.path}/recordings',
    ],
    config: _config,
    flows: [
      AutomationFlowDefinition(
        name: 'demo',
        variants: [FlowVariant('main', items: steps)],
      ),
    ],
    driverConnector: (_) async => driver,
    frameReadyGrace: _grace,
  );

  await IOOverrides.runZoned(
    sut.run,
    stdout: () => _LineStdout(lines),
    stderr: () => _LineStdout([]),
  );

  return _Run(
    report: jsonDecode(lines.single) as Map<String, Object?>,
    endScreenshot: File('${directory.path}/capture/demo_main_end.png'),
    recording: File('${directory.path}/recordings/demo/main.json'),
  );
}

final class _Run {
  final Map<String, Object?> report;
  final File endScreenshot;
  final File recording;

  const _Run({
    required this.report,
    required this.endScreenshot,
    required this.recording,
  });
}

final class _FakeFrame {
  final int loadingImages;
  final int emptyTexts;

  final List<Map<String, Object?>> emptyTextItems;

  const _FakeFrame({
    required this.loadingImages,
    required this.emptyTexts,
    this.emptyTextItems = const [],
  });
}

final class _FakeDriver implements FlutterDriver {
  final _FakeFrame Function(int shots) frameAfterShots;
  final bool Function(int shots) isAnimatingAfterShots;
  final bool Function(int waits) isAnimatingOnWait;
  final bool Function(int shots) frameReadFailsAfterShots;
  int loadingReadsBeforeReady;
  int _shots = 0;
  int _waits = 0;

  _FakeDriver({
    required this.frameAfterShots,
    required this.isAnimatingAfterShots,
    required this.isAnimatingOnWait,
    required this.frameReadFailsAfterShots,
    required this.loadingReadsBeforeReady,
  });

  @override
  Future<String> requestData(String? message, {Duration? timeout}) async {
    final command = (jsonDecode(message!) as Map<String, Object?>)['command'];

    return jsonEncode(switch (command) {
      'frame.read' => _answerFrame(),
      'screen.read' => {'platform': 'android', 'inset': 0},
      _ => {'records': <Object?>[]},
    });
  }

  Map<String, Object?> _answerFrame() {
    if (frameReadFailsAfterShots(_shots)) {
      throw DriverError('no frame.read');
    }

    if (loadingReadsBeforeReady > 0) {
      loadingReadsBeforeReady -= 1;

      return {'loadingImages': 1, 'emptyTexts': 0};
    }

    final frame = frameAfterShots(_shots);

    return {
      'loadingImages': frame.loadingImages,
      'emptyTexts': frame.emptyTexts,
      'emptyTextItems': frame.emptyTextItems,
    };
  }

  @override
  Future<void> waitUntilNoTransientCallbacks({Duration? timeout}) async {
    _waits += 1;

    if (isAnimatingAfterShots(_shots) || isAnimatingOnWait(_waits)) {
      throw DriverError('still animating');
    }
  }

  @override
  Future<List<int>> screenshot({
    ScreenshotFormat format = ScreenshotFormat.png,
  }) async {
    _shots += 1;

    return image.encodePng(image.Image(width: 8, height: 8));
  }

  @override
  Future<void> waitFor(SerializableFinder finder, {Duration? timeout}) async {}

  @override
  Future<void> tap(SerializableFinder finder, {Duration? timeout}) async {}

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName}');
  }
}

final class _LineStdout implements Stdout {
  final List<String> lines;

  _LineStdout(this.lines);

  @override
  void writeln([Object? object = '']) => lines.add('$object');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
