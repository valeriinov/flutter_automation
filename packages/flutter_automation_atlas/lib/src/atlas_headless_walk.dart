import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_driver/flutter_automation_driver.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';
import 'package:flutter_automation_runner/widget_tester_finders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_app.dart';
import 'package:flutter_automation_atlas/src/atlas_headless_frames.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_cleaner.dart';

/// Walks the steps of one headless input through a [WidgetTester] and
/// answers its report.
///
/// The report holds the hash of what the app shows before each user action,
/// one per stage, and at the end. It holds the journal records up to each.
///
/// The walk applies the locale of the input once the app is past its splash,
/// as a capture does. It reads the journal after each step and right after
/// each frame, as a capture's reads do. It reads a frame when the app has no
/// animation and the mock answered each request. A finder op first waits
/// until the frame has no animation, as the frame sync of the driver does.
/// The first step that fails ends the walk. The report holds the stages
/// before it and names it under `error`.
final class AtlasHeadlessWalk {
  static const _minTimeout = Duration(seconds: 10);
  static const _pollStep = Duration(milliseconds: 100);
  static const _stillFrameTimeout = Duration(seconds: 5);
  static const _stillPolls = 2;
  static const _timersRunOut = Duration(minutes: 10);
  static const _pastSplashTimeout = Duration(seconds: 30);

  final WidgetTester _tester;
  final AtlasHeadlessInput _input;
  final AtlasHeadlessApp _app;
  final AtlasJournalCleaner _journalCleaner;

  bool _isKeyboardShown = false;
  DateTime _launchedAt = DateTime.now();

  AtlasHeadlessWalk(this._tester, this._input, this._app)
    : _journalCleaner = AtlasJournalCleaner(_app.schema);

  /// Launches the app and walks each step.
  Future<AtlasHeadlessReport> walk() async {
    await _launch();
    await _applyLocale(_input.locale);

    _readJournal();

    final finders = AutomationRunnerConfig.read().finderRegistry;
    final frameHashes = <String?>[];
    final journals = <List<Object?>>[];
    final pendingRecords = <Object?>[];

    for (final json in _input.steps) {
      final step = AutomationStep.fromJson(
        json,
        block: null,
        finders: finders,
        locale: _input.locale,
        anchorOf: _readAnchor,
      );

      try {
        if (step.isUserAction) {
          frameHashes.add(await _readStillFrame('${frameHashes.length}'));
          journals.add(_takeRecords(pendingRecords));
        }

        await _walkStep(step);

        pendingRecords.addAll(_readJournal());
      } on Object catch (error) {
        return _report(
          frameHashes,
          journals,
          endFrameHash: null,
          error: 'Step "${step.label}" failed: $error',
        );
      }
    }

    final endFrameHash = await _readStillFrame(AtlasHeadless.endFrameName);

    journals.add(_takeRecords(pendingRecords));

    return _report(
      frameHashes,
      journals,
      endFrameHash: endFrameHash,
      error: null,
    );
  }

  /// Unmounts the app, disposes what it leaves active and runs out the
  /// timers that remain, because a widget test refuses to end with them.
  Future<void> close() async {
    await _tester.pumpWidget(const SizedBox.shrink());

    _app.close?.call();

    await _tester.pump(_timersRunOut);
  }

  Future<void> _launch() async {
    final device = _app.device;

    _sizeView(device);

    _isKeyboardShown = false;

    // A future the asset bundle cached in an earlier test completes in that
    // test's fake zone, which no pump of this test flushes.
    rootBundle.clear();

    final launch = AtlasHeadlessLaunch(
      scenario: _input.scenario,
      moments: _tryReadMoments(),
      recordedValues: _input.recordedValues,
    );

    final root = await _app.launch(_tester, launch);

    _launchedAt = launch.launchedAt;

    await _tester.pumpWidget(
      RepaintBoundary(key: AtlasHeadlessFrames.key, child: root),
    );
  }

  void _sizeView(AtlasHeadlessDevice device) {
    final padding = FakeViewPadding(
      top: device.topInset * device.pixelRatio,
      bottom: device.bottomInset * device.pixelRatio,
    );

    _tester.view
      ..physicalSize = device.size * device.pixelRatio
      ..devicePixelRatio = device.pixelRatio
      ..padding = padding
      ..viewPadding = padding;

    addTearDown(_tester.view.reset);
  }

  Future<void> _applyLocale(String locale) async {
    final isPastSplash = await _pumpUntil(_isPastSplash, _pastSplashTimeout);

    if (!isPastSplash) {
      throw StateError('The app logged no screen past the splash.');
    }

    bool isDone = false;
    Object? failure;

    Future<void> handleLocaleCommand() async {
      try {
        await AutomationCommandRegistry.handle(
          jsonEncode({
            'command': AutomationProtocol.localeApplyCommand,
            AutomationProtocol.localeKey: locale,
          }),
        );
      } catch (error) {
        failure = error;
      } finally {
        isDone = true;
      }
    }

    handleLocaleCommand();

    await _pumpUntil(() => isDone, _pastSplashTimeout);

    if (!isDone || failure != null) {
      throw StateError('The app did not apply the locale "$locale": $failure');
    }
  }

  bool _isPastSplash() {
    final screenName = _app.readScreenName();

    return screenName != null && screenName != _app.splashScreen;
  }

  List<Object?> _readJournal() {
    return _journalCleaner.clean(_app.mock().journal.readAndClear());
  }

  DateTime _readAnchor(String kindName) {
    final moments = _tryReadMoments();
    final anchor = kindName == AutomationFinderRegistry.dateTextName
        ? moments?.anchor
        : moments?.launchedAt;

    return anchor ?? DateTime.now();
  }

  Future<void> _walkStep(AutomationStep step) async {
    await _send(step);
    await _tester.pump();

    _syncKeyboard();

    await _pumpUntilAnswered();
  }

  Future<String?> _readStillFrame(String frameName) async {
    await _pumpUntilStill();

    return AtlasHeadlessFrames.read(
      _tester,
      framePath: p.join(_input.framesDirectory, '$frameName.png'),
      recordedTexts: _input.recordedTexts.toSet(),
      launchedAt: _launchedAt,
    );
  }

  List<Object?> _takeRecords(List<Object?> pendingRecords) {
    final records = [...pendingRecords, ..._readJournal()];

    pendingRecords.clear();

    return records;
  }

  AtlasHeadlessReport _report(
    List<String?> frameHashes,
    List<List<Object?>> journals, {
    required String? endFrameHash,
    required String? error,
  }) {
    return AtlasHeadlessReport(
      frameHashes: frameHashes,
      journals: journals,
      launch: _journalCleaner.tryDescribeLaunch(_app.mock().journal.launch),
      endFrameHash: endFrameHash,
      error: error,
    );
  }

  // `DateTime.tryParse` reads a `Z`-suffixed string as UTC; the mock seeds its
  // dates from local time.
  ({DateTime anchor, DateTime launchedAt})? _tryReadMoments() {
    final anchor = DateTime.tryParse(_input.anchor ?? '');
    final launchedAt = DateTime.tryParse(_input.launchedAt ?? '');

    if (anchor == null || launchedAt == null) {
      return null;
    }

    return (anchor: anchor.toLocal(), launchedAt: launchedAt.toLocal());
  }

  // Pumps frames, letting real time pass between them for the file and
  // asset reads, until [isDone] answers `true` or [timeout] is spent,
  // answering whether it did.
  Future<bool> _pumpUntil(bool Function() isDone, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);

    while (!isDone()) {
      if (DateTime.now().isAfter(deadline)) {
        return false;
      }

      await _pumpStep();
    }

    return true;
  }

  Future<void> _pumpStep() async {
    await _tester.runAsync(() => Future<void>.delayed(_pollStep));
    await _tester.pump(_pollStep);
  }

  // Pumps until no animation runs and the mock answered every request,
  // what a device run waits for before it reads a frame, and a little past
  // it, as long as an image takes to decode.
  Future<void> _pumpUntilStill() async {
    final journal = _app.mock().journal;
    int stillPolls = 0;

    await _pumpUntil(() {
      stillPolls = _isStill(journal) && !AtlasHeadlessFrames.hasUndecodedImage()
          ? stillPolls + 1
          : 0;

      return stillPolls > _stillPolls;
    }, _stillFrameTimeout);
  }

  Future<void> _pumpUntilAnswered() async {
    final automationMock = _app.mock();
    final journal = automationMock.journal;

    await _pumpUntil(
      () => journal.requestsAwaitingResponse.isEmpty,
      automationMock.journalResponseTimeout,
    );
  }

  bool _isStill(MockJournal journal) {
    return _tester.binding.transientCallbackCount == 0 &&
        journal.requestsAwaitingResponse.isEmpty;
  }

  void _syncKeyboard() {
    final isShown = _tester.testTextInput.isVisible;

    if (isShown == _isKeyboardShown) {
      return;
    }

    _isKeyboardShown = isShown;

    final device = _app.device;

    _tester.view
      ..padding = FakeViewPadding(
        top: device.topInset * device.pixelRatio,
        bottom: isShown ? 0 : device.bottomInset * device.pixelRatio,
      )
      ..viewInsets = FakeViewPadding(
        bottom: isShown ? device.keyboardHeight * device.pixelRatio : 0,
      );

    device.onKeyboardVisibilityChanged?.call(_tester, isShown: isShown);
  }

  Future<void> _send(AutomationStep step) async {
    switch (step.action) {
      case 'waitFor':
        await _waitFor(step, _resolveFinder(step));
      case 'waitForTappable':
        await _waitFor(step, _resolveFinder(step).hitTestable());
      case 'waitForAbsent':
        await _waitForAbsent(step);
      case 'tap':
        await _tester.tap(
          await _waitFor(step, _resolveFinder(step).hitTestable()),
        );
      case 'enterText':
        await _enterText(step);
      case 'scroll':
        await _scroll(step);
      case 'scrollIntoView':
        await _tester.ensureVisible(await _waitFor(step, _resolveFinder(step)));
      case _:
        throw StateError('A headless walk takes no "${step.action}" step.');
    }
  }

  Future<void> _waitForAbsent(AutomationStep step) async {
    final finder = _resolveFinder(step);

    final isAbsent = await _pumpUntil(
      () => finder.evaluate().isEmpty,
      _resolveTimeout(step),
    );

    if (!isAbsent) {
      throw StateError('$finder stayed.');
    }
  }

  Future<void> _enterText(AutomationStep step) async {
    final fieldContext = FocusManager.instance.primaryFocus?.context;

    _tester.testTextInput.enterText(step.text ?? '');

    if (fieldContext == null) {
      return;
    }

    await _tester.pump(_app.textEntryPause(fieldContext));
  }

  // None of the pointer events of the driver scroll carries a time stamp,
  // so the drag ends without a fling.
  Future<void> _scroll(AutomationStep step) async {
    final finder = await _waitFor(step, _resolveFinder(step));

    final moveCount =
        step.duration.inMicroseconds *
        step.frequency ~/
        Duration.microsecondsPerSecond;
    final delta = Offset(step.dx, step.dy) / moveCount.toDouble();
    final pause = step.duration ~/ moveCount;
    final pointer = TestPointer();
    Offset location = _tester.getCenter(finder);

    _tester.binding.handlePointerEvent(pointer.down(location));

    for (int move = 0; move < moveCount; move++) {
      location += delta;

      _tester.binding.handlePointerEvent(pointer.move(location));

      await _tester.pump(pause);
    }

    _tester.binding.handlePointerEvent(pointer.up());
  }

  Future<Finder> _waitFor(AutomationStep step, Finder finder) async {
    await _pumpUntil(
      () => _tester.binding.transientCallbackCount == 0,
      _resolveTimeout(step),
    );

    final isFound = await _pumpUntil(
      () => finder.evaluate().isNotEmpty,
      _resolveTimeout(step),
    );

    if (!isFound) {
      throw StateError('Nothing matched $finder.');
    }

    return finder;
  }

  Finder _resolveFinder(AutomationStep step) {
    final spec = step.spec;

    if (spec == null) {
      throw StateError('Step "${step.label}" names no target.');
    }

    return AutomationWidgetTesterFinders.build(spec);
  }

  Duration _resolveTimeout(AutomationStep step) {
    return step.timeout < _minTimeout ? _minTimeout : step.timeout;
  }
}
