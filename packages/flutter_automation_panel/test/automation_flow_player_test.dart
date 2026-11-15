import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

const _fastSettings = AutomationPlayerSettings(
  pollInterval: Duration(milliseconds: 50),
  settleDelay: Duration.zero,
  touchLead: Duration.zero,
  touchHold: Duration.zero,
  touchTrail: Duration.zero,
);
const _buttonKey = 'sample.button.count';
const _fieldKey = 'sample.field.name';
const _lateKey = 'sample.label.late';
const _deepKey = 'sample.label.deep';
const _timeout = 500;
const _dragKey = 'sample.drag.surface';

void main() {
  group('AutomationFlowPlayer Tests', () {
    _automationFlowPlayer_should_tapAnElement();
    _automationFlowPlayer_should_enterTextIntoTheFocusedField();
    _automationFlowPlayer_should_waitForAnElementThatAppearsLater();
    _automationFlowPlayer_should_stopWithAReasonWhenTheTargetNeverAppears();
    _automationFlowPlayer_should_findATextByLocaleKeyAndByDescendant();
    _automationFlowPlayer_should_scrollAnElementIntoView();
    _automationFlowPlayer_should_skipServiceSteps();
    _automationFlowPlayer_should_scrollTheOnstageMatchIntoView();
    _automationFlowPlayer_should_tapWhereTheTargetStandsAfterTheTouchLead();
    _automationFlowPlayer_should_releaseTheFingerWhenStoppedInADrag();
    _automationFlowPlayer_should_moveOnceForADragOfNoDuration();
    _automationFlowPlayer_should_holdTheFingerForAScrollOfNoDrag();
  });
  group('AutomationInputGate Tests', () {
    _automationInputGate_should_blockTheFingerAndPassThePlayer();
    _automationInputPassThrough_should_letThePlayerTapThroughAndKeepTheFinger();
  });
}

class _Sample extends StatefulWidget {
  final bool Function() isBlocked;
  final Widget? layer;

  const _Sample({required this.isBlocked, this.layer});

  @override
  State<_Sample> createState() => _SampleState();
}

class _SampleState extends State<_Sample> {
  final controller = TextEditingController();
  bool isLateShown = false;
  int count = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    timer = Timer(const Duration(milliseconds: 200), () {
      setState(() => isLateShown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return Stack(
          children: [
            Positioned.fill(
              child: AutomationInputGate(
                isBlocked: widget.isBlocked,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            ?widget.layer,
          ],
        );
      },
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              ElevatedButton(
                key: const ValueKey(_buttonKey),
                onPressed: () => setState(() => count += 1),
                child: Text('count $count'),
              ),
              TextField(key: const ValueKey(_fieldKey), controller: controller),
              if (isLateShown)
                Text(
                  LocaleKeyMarker.mark('lateKey', 'Late'),
                  key: const ValueKey(_lateKey),
                ),
              const SizedBox(height: 2000),
              const Text('Deep', key: ValueKey(_deepKey)),
              const SizedBox(height: 600),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }
}

AutomationCatalogueStep _step(
  String action, {
  Map<String, Object?>? finder,
  String? text,
  int? timeoutMs,
  bool isService = false,
}) {
  return AutomationCatalogueStep(
    label: action,
    action: action,
    finder: finder,
    text: text,
    timeoutMs: timeoutMs,
    isService: isService,
  );
}

Map<String, Object?> _byKey(String key) => {'by': 'valueKey', 'value': key};

Future<void> _play(
  WidgetTester tester,
  AutomationFlowPlayer player,
  AutomationCatalogueStep step,
) async {
  bool isDone = false;
  Object? error;

  unawaited(
    player
        .play(step)
        .then(
          (_) => isDone = true,
          onError: (Object caught) {
            error = caught;
            isDone = true;
          },
        ),
  );

  for (int index = 0; index < 100 && !isDone; index += 1) {
    await tester.pump(const Duration(milliseconds: 50));
  }

  expect(isDone, isTrue);

  if (error case final Object caught) {
    throw caught;
  }
}

Future<AutomationFlowPlayer> _pumpSample(
  WidgetTester tester, {
  bool Function()? isBlocked,
  Widget Function(AutomationFlowPlayer player)? layer,
}) async {
  final player = AutomationFlowPlayer(settings: _fastSettings);
  final isFingerBlocked = isBlocked ?? () => false;

  addTearDown(player.dispose);

  await tester.pumpWidget(
    _Sample(
      isBlocked: () => isFingerBlocked() && !player.isInjecting,
      layer: layer?.call(player),
    ),
  );

  return player;
}

void _automationFlowPlayer_should_tapAnElement() {
  testWidgets('AutomationFlowPlayer should tap an element', (tester) async {
    final player = await _pumpSample(tester);

    await _play(tester, player, _step('tap', finder: _byKey(_buttonKey)));

    expect(find.text('count 1'), findsOneWidget);
  });
}

void _automationFlowPlayer_should_enterTextIntoTheFocusedField() {
  testWidgets('AutomationFlowPlayer should enter text into the focus', (
    tester,
  ) async {
    final player = await _pumpSample(tester);

    await _play(tester, player, _step('tap', finder: _byKey(_fieldKey)));
    await _play(tester, player, _step('enterText', text: 'Kyiv'));

    expect(find.text('Kyiv'), findsOneWidget);
  });
}

void _automationFlowPlayer_should_waitForAnElementThatAppearsLater() {
  testWidgets('AutomationFlowPlayer should wait for a later element', (
    tester,
  ) async {
    final player = await _pumpSample(tester);

    expect(find.byKey(const ValueKey(_lateKey)), findsNothing);

    await _play(tester, player, _step('waitFor', finder: _byKey(_lateKey)));

    expect(find.byKey(const ValueKey(_lateKey)), findsOneWidget);
  });
}

void _automationFlowPlayer_should_stopWithAReasonWhenTheTargetNeverAppears() {
  testWidgets('AutomationFlowPlayer should stop with a reason', (tester) async {
    final player = await _pumpSample(tester);

    final step = _step(
      'waitFor',
      finder: _byKey('missing.key'),
      timeoutMs: _timeout,
    );
    String? reason;

    try {
      await _play(tester, player, step);
    } on AutomationPlayerException catch (error) {
      reason = error.reason;
    }

    expect(reason, contains('did not appear'));
    expect(reason, contains('500 ms'));
  });
}

void _automationFlowPlayer_should_findATextByLocaleKeyAndByDescendant() {
  testWidgets('AutomationFlowPlayer should find by locale key and relation', (
    tester,
  ) async {
    final player = await _pumpSample(tester);

    await _play(
      tester,
      player,
      _step('waitFor', finder: {'by': 'localeKey', 'value': 'lateKey'}),
    );
    await _play(
      tester,
      player,
      _step(
        'waitFor',
        finder: {
          'by': 'descendant',
          'of': _byKey(_buttonKey),
          'matching': {'by': 'text', 'value': 'count 0'},
        },
      ),
    );
  });
}

void _automationFlowPlayer_should_scrollAnElementIntoView() {
  testWidgets('AutomationFlowPlayer should scroll an element into view', (
    tester,
  ) async {
    final player = await _pumpSample(tester);

    expect(find.byKey(const ValueKey(_deepKey)).hitTestable(), findsNothing);

    await _play(
      tester,
      player,
      _step('scrollIntoView', finder: _byKey(_deepKey)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey(_deepKey)).hitTestable(), findsOneWidget);
  });
}

void _automationFlowPlayer_should_skipServiceSteps() {
  testWidgets('AutomationFlowPlayer should skip a service step', (
    tester,
  ) async {
    final player = await _pumpSample(tester);

    await _play(tester, player, _step('traceStart', isService: true));
    await _play(tester, player, _step('probeCenter', isService: true));
  });
}

void _automationInputGate_should_blockTheFingerAndPassThePlayer() {
  testWidgets('AutomationInputGate should block the finger only', (
    tester,
  ) async {
    bool isBlocked = true;

    final player = await _pumpSample(tester, isBlocked: () => isBlocked);

    await tester.tap(
      find.byKey(const ValueKey(_buttonKey)),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(find.text('count 0'), findsOneWidget);

    await _play(tester, player, _step('tap', finder: _byKey(_buttonKey)));

    expect(find.text('count 1'), findsOneWidget);

    isBlocked = false;

    await tester.tap(find.byKey(const ValueKey(_buttonKey)));
    await tester.pump();

    expect(find.text('count 2'), findsOneWidget);
  });
}

void
_automationInputPassThrough_should_letThePlayerTapThroughAndKeepTheFinger() {
  testWidgets('AutomationInputPassThrough should pass the player only', (
    tester,
  ) async {
    int plaqueTaps = 0;
    AutomationFlowPlayer? sharedPlayer;

    final player = await _pumpSample(
      tester,
      isBlocked: () => true,
      layer: (player) {
        sharedPlayer = player;

        return Positioned(
          left: 0,
          top: 0,
          right: 0,
          height: 200,
          child: AutomationInputPassThrough(
            isPassing: () => sharedPlayer?.isInjecting ?? false,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              key: const ValueKey('plaque'),
              onTap: () => plaqueTaps += 1,
            ),
          ),
        );
      },
    );

    await tester.tap(find.byKey(const ValueKey('plaque')));
    await tester.pump();

    expect(plaqueTaps, 1);

    await _play(tester, player, _step('tap', finder: _byKey(_buttonKey)));

    expect(plaqueTaps, 1);
    expect(find.text('count 1'), findsOneWidget);
  });
}

const _slowLeadSettings = AutomationPlayerSettings(
  pollInterval: Duration(milliseconds: 50),
  settleDelay: Duration.zero,
  touchLead: Duration(milliseconds: 100),
  touchHold: Duration.zero,
  touchTrail: Duration.zero,
);

Future<Object?> _playUntilDone(
  WidgetTester tester,
  Future<void> play, {
  VoidCallback? onRound,
}) async {
  bool isDone = false;
  Object? error;

  unawaited(
    play.then(
      (_) => isDone = true,
      onError: (Object caught) {
        error = caught;
        isDone = true;
      },
    ),
  );

  for (int round = 0; round < 100 && !isDone; round += 1) {
    onRound?.call();

    await tester.pump(const Duration(milliseconds: 50));
  }

  expect(isDone, isTrue);

  return error;
}

void _automationFlowPlayer_should_scrollTheOnstageMatchIntoView() {
  testWidgets('AutomationFlowPlayer should scroll the onstage match', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const Offstage(child: Text('Twin')),
                const SizedBox(height: 2000),
                const Text('Twin', key: ValueKey('onstage')),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    );

    final player = AutomationFlowPlayer(settings: _fastSettings);

    addTearDown(player.dispose);

    await _play(
      tester,
      player,
      _step('scrollIntoView', finder: {'by': 'text', 'value': 'Twin'}),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('onstage')).hitTestable(), findsOneWidget);
  });
}

void _automationFlowPlayer_should_tapWhereTheTargetStandsAfterTheTouchLead() {
  testWidgets('AutomationFlowPlayer should tap where the target stands after '
      'the touch lead', (tester) async {
    int count = 0;
    bool isMoved = false;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;

              return Stack(
                children: [
                  Positioned(
                    left: isMoved ? 200 : 0,
                    top: 100,
                    child: ElevatedButton(
                      key: const ValueKey(_buttonKey),
                      onPressed: () => count += 1,
                      child: const Text('Tap'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    final player = AutomationFlowPlayer(settings: _slowLeadSettings);

    addTearDown(player.dispose);

    int rounds = 0;

    final error = await _playUntilDone(
      tester,
      player.play(_step('tap', finder: _byKey(_buttonKey))),
      onRound: () {
        rounds += 1;

        if (rounds == 1) {
          update(() => isMoved = true);
        }
      },
    );

    expect(error, isNull);
    expect(count, 1);
  });
}

void _automationFlowPlayer_should_releaseTheFingerWhenStoppedInADrag() {
  testWidgets('AutomationFlowPlayer should release the finger when stopped in '
      'a drag', (tester) async {
    int ups = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Listener(
            onPointerUp: (_) => ups += 1,
            child: const SingleChildScrollView(child: _DragSurface()),
          ),
        ),
      ),
    );

    final player = AutomationFlowPlayer(settings: _fastSettings);
    bool isStopped = false;
    int rounds = 0;

    addTearDown(player.dispose);

    final error = await _playUntilDone(
      tester,
      player.play(
        AutomationCatalogueStep(
          label: 'scroll',
          action: 'scroll',
          finder: _byKey(_dragKey),
          dy: -300,
          durationMs: 1000,
          frequency: 10,
        ),
        isStopped: () => isStopped,
      ),
      onRound: () {
        rounds += 1;
        isStopped = rounds > 4;
      },
    );

    expect(error, isA<AutomationPlayerException>());
    expect(ups, 1);
  });
}

void _automationFlowPlayer_should_moveOnceForADragOfNoDuration() {
  testWidgets('AutomationFlowPlayer should move once for a drag of no '
      'duration', (tester) async {
    final controller = ScrollController();

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: const _DragSurface(),
          ),
        ),
      ),
    );

    final player = AutomationFlowPlayer(settings: _fastSettings);

    addTearDown(player.dispose);

    await _play(
      tester,
      player,
      AutomationCatalogueStep(
        label: 'scroll',
        action: 'scroll',
        finder: _byKey(_dragKey),
        dy: -300,
        durationMs: 0,
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
  });
}

class _DragSurface extends StatelessWidget {
  const _DragSurface();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ColoredBox(
          key: ValueKey(_dragKey),
          color: Colors.blue,
          child: SizedBox(width: double.infinity, height: 400),
        ),
        SizedBox(height: 3000),
      ],
    );
  }
}

void _automationFlowPlayer_should_holdTheFingerForAScrollOfNoDrag() {
  testWidgets('AutomationFlowPlayer should hold the finger for a scroll of no '
      'drag', (tester) async {
    DateTime? downAt;
    Duration? held;
    int moves = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Listener(
            onPointerDown: (_) => downAt = clock.now(),
            onPointerMove: (_) => moves += 1,
            onPointerUp: (_) =>
                held = clock.now().difference(downAt ?? clock.now()),
            child: const SingleChildScrollView(child: _DragSurface()),
          ),
        ),
      ),
    );

    final player = AutomationFlowPlayer(settings: _fastSettings);

    addTearDown(player.dispose);

    await _play(
      tester,
      player,
      AutomationCatalogueStep(
        label: 'scroll',
        action: 'scroll',
        finder: _byKey(_dragKey),
        durationMs: 1000,
        frequency: 10,
      ),
    );

    expect(held?.inMilliseconds ?? 0, greaterThan(900));
    expect(moves, 0);
  });
}
