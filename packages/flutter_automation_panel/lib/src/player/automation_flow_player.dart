import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/src/pages/automation_catalogue_text.dart';
import 'package:flutter_automation_panel/src/player/automation_player_exception.dart';
import 'package:flutter_automation_panel/src/player/automation_player_finder.dart';
import 'package:flutter_automation_panel/src/player/automation_player_settings.dart';

/// {@category Services}
///
/// Plays the steps of a flow variant inside the running app, with the public
/// API of Flutter and without a driver.
///
/// A tap is a pointer event that enters `GestureBinding`. The text of an
/// `enterText` goes into the focused `EditableText`. A `scrollIntoView` calls
/// `Scrollable.ensureVisible`. A wait polls the element tree on the stage. The
/// player reads the `finder` JSON of a catalogue step itself, so the app needs
/// neither `flutter_driver` nor the runner.
///
/// While the player sends a pointer event or tests where a pointer event
/// lands, [isInjecting] is true. An [AutomationInputGate] lets that event
/// through and blocks the finger.
class AutomationFlowPlayer {
  static const _tapAction = 'tap';
  static const _enterTextAction = 'enterText';
  static const _scrollAction = 'scroll';
  static const _scrollIntoViewAction = 'scrollIntoView';
  static const _waitForAction = 'waitFor';
  static const _waitForAbsentAction = 'waitForAbsent';
  static const _waitForTappableAction = 'waitForTappable';
  static const _scrollIntoViewDuration = Duration(milliseconds: 300);
  static const _defaultScrollDuration = Duration(seconds: 6);
  static const _defaultFrequency = 60;
  static const _firstPointer = 900000;
  static const _device = 0x7A11;

  /// What the project tells the player, and how fast it moves.
  final AutomationPlayerSettings settings;

  /// The catalogue whose date formats and date key templates the player reads
  /// a date finder with.
  final AutomationCatalogue catalogue;

  /// Where the touch circle shows, `null` while it is hidden.
  final ValueNotifier<Offset?> touch = ValueNotifier(null);

  int _pointer = _firstPointer;
  bool _isInjecting = false;
  bool Function() _isStopped = _neverStopped;

  AutomationFlowPlayer({
    this.settings = const AutomationPlayerSettings(),
    this.catalogue = const AutomationCatalogue(),
  });

  /// Whether the player sends a pointer event or tests where one lands right
  /// now.
  bool get isInjecting => _isInjecting;

  /// Whether [step] is something a person does on screen: a tap, typed text,
  /// a scroll into view or a drag.
  static bool isAction(AutomationCatalogueStep step) {
    return switch (step.action) {
      _tapAction || _enterTextAction || _scrollIntoViewAction => true,
      _scrollAction => _hasDistance(step),
      _ => false,
    };
  }

  /// The words that name [step] for the tester: its title, else its label.
  static String describe(AutomationCatalogueStep step) {
    return AutomationCatalogueText.english(step.title, step.label);
  }

  /// Plays [step]. A step that serves the run does nothing.
  ///
  /// Throws an [AutomationPlayerException] that names why the player could not
  /// play the step, for example a target that did not appear in time.
  ///
  /// The [isStopped] parameter tells the player to give up. The player asks it
  /// while it waits and before it touches the screen.
  Future<void> play(
    AutomationCatalogueStep step, {
    bool Function()? isStopped,
  }) async {
    if (step.isService) {
      return;
    }

    _isStopped = isStopped ?? _neverStopped;

    final finder = _readFinder(step);

    switch (step.action) {
      case _tapAction:
        await _tap(step, _requireFinder(step, finder));
      case _enterTextAction:
        _enterText(step.text ?? '');
      case _scrollAction:
        await _scroll(step, _requireFinder(step, finder));
      case _scrollIntoViewAction:
        await _scrollIntoView(step, _requireFinder(step, finder));
      case _waitForAction:
        await _waitFor(step, finder: _requireFinder(step, finder));
      case _waitForAbsentAction:
        await _waitForAbsent(step, _requireFinder(step, finder));
      case _waitForTappableAction:
        await _waitForTappable(step, _requireFinder(step, finder));
      case null:
        throw AutomationPlayerException(
          '"${describe(step)}" carries no action. Build the catalogue again.',
        );
      case final String action:
        throw AutomationPlayerException(
          '"${describe(step)}" is a "$action" step. The player cannot play it.',
        );
    }

    await _delay(settings.settleDelay);
  }

  /// Frees the touch circle.
  void dispose() {
    touch.dispose();
  }

  static bool _neverStopped() => false;

  static bool _hasDistance(AutomationCatalogueStep step) {
    return (step.dx ?? 0) != 0 || (step.dy ?? 0) != 0;
  }

  static bool _isDragOrHold(AutomationCatalogueStep step) {
    return _hasDistance(step) || step.durationMs != null;
  }

  AutomationPlayerFinder? _readFinder(AutomationCatalogueStep step) {
    final json = step.finder;

    if (json == null) {
      return null;
    }

    return AutomationPlayerFinder(
      json,
      settings,
      dateFormats: catalogue.dateFormats,
      dateValueKeys: catalogue.dateValueKeys,
    );
  }

  AutomationPlayerFinder _requireFinder(
    AutomationCatalogueStep step,
    AutomationPlayerFinder? finder,
  ) {
    if (finder == null) {
      throw AutomationPlayerException(
        '"${describe(step)}" names no element to act on.',
      );
    }

    return finder;
  }

  Duration _timeoutOf(AutomationCatalogueStep step) {
    final timeoutMs = step.timeoutMs;

    return timeoutMs == null
        ? settings.defaultTimeout
        : Duration(milliseconds: timeoutMs);
  }

  Future<void> _waitFor(
    AutomationCatalogueStep step, {
    required AutomationPlayerFinder finder,
  }) {
    return _waitUntil(step, () => finder.findFirst() != null, 'did not appear');
  }

  Future<void> _waitForAbsent(
    AutomationCatalogueStep step,
    AutomationPlayerFinder finder,
  ) {
    return _waitUntil(step, () => finder.findFirst() == null, 'did not go');
  }

  Future<void> _waitForTappable(
    AutomationCatalogueStep step,
    AutomationPlayerFinder finder,
  ) {
    return _waitUntil(
      step,
      () => _findTappableCenter(finder) != null,
      'did not become tappable',
    );
  }

  Future<void> _waitUntil(
    AutomationCatalogueStep step,
    bool Function() isMet,
    String failure,
  ) async {
    final timeout = _timeoutOf(step);
    final watch = clock.stopwatch()..start();

    while (!isMet()) {
      _throwIfStopped();

      if (watch.elapsed >= timeout) {
        throw AutomationPlayerException(
          '"${describe(step)}" $failure in ${_describeTimeout(timeout)}.',
        );
      }

      await _delay(settings.pollInterval);
    }
  }

  String _describeTimeout(Duration timeout) {
    if (timeout < const Duration(seconds: 1)) {
      return '${timeout.inMilliseconds} ms';
    }

    return '${timeout.inSeconds} s';
  }

  Future<void> _tap(
    AutomationCatalogueStep step,
    AutomationPlayerFinder finder,
  ) async {
    await _waitForTappable(step, finder);

    final first = _requireTappable(step, finder);

    touch.value = first.center;

    await _delay(settings.touchLead);

    _throwIfStopped();

    final target = _requireTappable(step, finder);
    final pointer = _nextPointer();

    touch.value = target.center;

    _send(
      PointerDownEvent(
        viewId: target.viewId,
        pointer: pointer,
        device: _device,
        position: target.center,
      ),
    );

    await _delay(settings.touchHold);

    _send(
      PointerUpEvent(
        viewId: target.viewId,
        pointer: pointer,
        device: _device,
        position: target.center,
      ),
    );

    await _delay(settings.touchTrail);

    touch.value = null;
  }

  ({Offset center, int viewId}) _requireTappable(
    AutomationCatalogueStep step,
    AutomationPlayerFinder finder,
  ) {
    final target = _findTappable(finder);

    if (target == null) {
      throw AutomationPlayerException('"${describe(step)}" cannot be tapped.');
    }

    return target;
  }

  Future<void> _scroll(
    AutomationCatalogueStep step,
    AutomationPlayerFinder finder,
  ) async {
    await _waitForTappable(step, finder);

    final target = _findTappable(finder);

    if (target == null || !_isDragOrHold(step)) {
      return;
    }

    final frequency = step.frequency ?? _defaultFrequency;
    final duration = Duration(
      milliseconds: step.durationMs ?? _defaultScrollDuration.inMilliseconds,
    );
    final moves = max(1, (duration.inMilliseconds * frequency / 1000).ceil());
    final pointer = _nextPointer();
    final distance = Offset(step.dx ?? 0, step.dy ?? 0);

    touch.value = target.center;

    _send(
      PointerDownEvent(
        viewId: target.viewId,
        pointer: pointer,
        device: _device,
        position: target.center,
      ),
    );

    Offset last = target.center;

    for (int move = 1; move <= moves; move += 1) {
      await _delay(duration ~/ moves);

      if (_isStopped()) {
        _release(target.viewId, pointer, last);
      }

      _throwIfStopped();

      final position = target.center + distance * (move / moves);

      touch.value = position;
      last = position;

      if (_hasDistance(step)) {
        _send(
          PointerMoveEvent(
            viewId: target.viewId,
            pointer: pointer,
            device: _device,
            position: position,
            delta: distance / moves.toDouble(),
          ),
        );
      }
    }

    _send(
      PointerUpEvent(
        viewId: target.viewId,
        pointer: pointer,
        device: _device,
        position: target.center + distance,
      ),
    );

    touch.value = null;
  }

  Future<void> _scrollIntoView(
    AutomationCatalogueStep step,
    AutomationPlayerFinder finder,
  ) async {
    await _waitUntil(
      step,
      () => _findForScroll(finder) != null,
      'did not appear',
    );

    final element = _findForScroll(finder);

    if (element != null && element.mounted) {
      await Scrollable.ensureVisible(
        element,
        duration: _scrollIntoViewDuration,
      );
    }
  }

  Element? _findForScroll(AutomationPlayerFinder finder) {
    return finder.findFirst() ?? finder.findFirst(isOnstage: false);
  }

  void _enterText(String text) {
    final state = _findFocusedEditableText();

    if (state == null) {
      throw const AutomationPlayerException(
        'No text field has the focus. Tap the field before the text.',
      );
    }

    state.userUpdateTextEditingValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
      SelectionChangedCause.keyboard,
    );
  }

  EditableTextState? _findFocusedEditableText() {
    final context = FocusManager.instance.primaryFocus?.context;
    final ancestor = context?.findAncestorStateOfType<EditableTextState>();

    if (ancestor != null || context is! Element) {
      return ancestor;
    }

    EditableTextState? found;

    void visit(Element element) {
      if (found != null) {
        return;
      }

      if (element is StatefulElement && element.state is EditableTextState) {
        found = element.state as EditableTextState;

        return;
      }

      element.visitChildren(visit);
    }

    visit(context);

    return found;
  }

  ({Offset center, int viewId})? _findTappable(AutomationPlayerFinder finder) {
    for (final element in finder.findAll()) {
      final target = _tappableCenterOf(element);

      if (target != null) {
        return target;
      }
    }

    return null;
  }

  Offset? _findTappableCenter(AutomationPlayerFinder finder) {
    return _findTappable(finder)?.center;
  }

  ({Offset center, int viewId})? _tappableCenterOf(Element element) {
    final box = element.findRenderObject();

    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return null;
    }

    final viewId = View.maybeOf(element)?.viewId;

    if (viewId == null) {
      return null;
    }

    final center = box.localToGlobal(box.size.center(Offset.zero));
    final result = HitTestResult();

    _isInjecting = true;

    try {
      WidgetsBinding.instance.hitTestInView(result, center, viewId);
    } finally {
      _isInjecting = false;
    }

    final isHit = result.path.any((entry) => entry.target == box);

    return isHit ? (center: center, viewId: viewId) : null;
  }

  void _release(int viewId, int pointer, Offset position) {
    _send(
      PointerUpEvent(
        viewId: viewId,
        pointer: pointer,
        device: _device,
        position: position,
      ),
    );
  }

  void _send(PointerEvent event) {
    _isInjecting = true;

    try {
      GestureBinding.instance.handlePointerEvent(event);
    } finally {
      _isInjecting = false;
    }
  }

  void _throwIfStopped() {
    if (_isStopped()) {
      touch.value = null;

      throw const AutomationPlayerException('The walk stopped.');
    }
  }

  int _nextPointer() {
    _pointer += 1;

    return _pointer;
  }

  Future<void> _delay(Duration duration) {
    if (duration <= Duration.zero) {
      return Future<void>.value();
    }

    return Future<void>.delayed(duration);
  }
}
