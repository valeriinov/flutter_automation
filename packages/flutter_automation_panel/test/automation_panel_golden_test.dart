import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils/sample_panel.dart';

const _goldenTag = ['golden'];

void main() {
  group('Automation Panel Golden Tests', () {
    _main_should_matchTheGolden();
    _flowMap_should_matchTheGolden();
    _response_should_matchTheGolden();
    _sections_should_matchTheGolden();
    _walk_should_matchTheGolden();
    _walkOpen_should_matchTheGolden();
    _runDone_should_matchTheGolden();
  });
}

Future<void> _expectGolden(String name) async {
  try {
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Future<SamplePanel> _pumpScreen(
  WidgetTester tester,
  Widget Function(SamplePanel sample) build, {
  Future<void> Function(SamplePanel sample)? arrange,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(780, 1688);

  addTearDown(tester.view.reset);

  final sample = await createSamplePanel(tester);

  debugDisableShadows = false;

  await tester.runAsync(() => arrange?.call(sample) ?? Future<void>.value());
  await tester.pumpWidget(hostApp(child: panelHost(sample, build(sample))));
  await tester.pumpAndSettle();

  return sample;
}

Future<void> _overrideRegister(SamplePanel sample) {
  return sample.controller.setFailure(signUpPath, const MockApiFailure());
}

void _main_should_matchTheGolden() {
  testWidgets('Main should match the golden', tags: _goldenTag, (tester) async {
    await _pumpScreen(
      tester,
      (_) => const AutomationPanel(),
      arrange: (sample) async {
        await _overrideRegister(sample);

        sample.controller.outcomeTitle = 'Sign-up needed';
      },
    );
    await _expectGolden('main');
  });
}

void _flowMap_should_matchTheGolden() {
  testWidgets('FlowMap should match the golden', tags: _goldenTag, (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      (_) => AutomationFlowMapPage(flow: sampleCatalogue.flows.first),
      arrange: _overrideRegister,
    );
    await _expectGolden('flow_map');
  });
}

void _response_should_matchTheGolden() {
  testWidgets('Response should match the golden', tags: _goldenTag, (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      (_) => Stack(
        children: [
          const ColoredBox(color: Color(0xFFFFFFFF), child: SizedBox.expand()),
          ColoredBox(color: sampleTheme.scrim, child: const SizedBox.expand()),
          Align(
            alignment: Alignment.bottomCenter,
            child: AutomationResponseSheet(
              method: 'POST',
              path: '/auth/send-code',
              mockStatusCode: 200,
              mockDescription: 'code sent',
              initial: const MockApiFailure(
                statusCode: 429,
                errorCode: 'tooManyRequests',
                message: 'Too many attempts',
              ),
              initialLatency: MockLatencyProfile.slow,
              backendErrorCodes: const ['tooManyRequests', 'invalidPhone'],
              onApply: (_, _) {},
              onClose: () {},
            ),
          ),
        ],
      ),
    );
    await _expectGolden('response');
  });
}

void _sections_should_matchTheGolden() {
  testWidgets('Sections should match the golden', tags: _goldenTag, (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      (_) => const AutomationPanel(initialTab: 1),
      arrange: (sample) async {
        await _overrideRegister(sample);
        await sample.controller.updateScenario(
          MockScenario.fromJson({
            ...sample.mock.scenario.toJson(),
            'latency': 'fast',
            'auth': {'isSignedInOnLaunch': false},
          }),
        );

        sample.controller.outcomeTitle = 'Sign-up needed';
      },
    );
    await _expectGolden('sections');
  });
}

Widget _walkOverApp(SamplePanel sample) {
  return Stack(
    children: [
      const ColoredBox(color: Color(0xFFFFFFFF), child: SizedBox.expand()),
      Positioned(
        left: 12,
        right: 12,
        top: 12,
        child: Material(
          type: MaterialType.transparency,
          child: AutomationWalkStrip(controller: sample.controller),
        ),
      ),
    ],
  );
}

Future<void> _arrangeWalk(SamplePanel sample) async {
  await sample.controller.startWalk('login', 'signUpNeeded');
  await SamplePanel.moveWalk(sample, 1);
  await sample.controller.setFailure(signUpPath, const MockApiFailure());
}

void _walk_should_matchTheGolden() {
  testWidgets('Walk should match the golden', tags: _goldenTag, (tester) async {
    await _pumpScreen(tester, _walkOverApp, arrange: _arrangeWalk);
    await _expectGolden('walk');
  });
}

void _walkOpen_should_matchTheGolden() {
  testWidgets('WalkOpen should match the golden', tags: _goldenTag, (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      _walkOverApp,
      arrange: (sample) async {
        await _arrangeWalk(sample);

        sample.controller.isWalkExpanded = true;
      },
    );
    await _expectGolden('walk_open');
  });
}

void _runDone_should_matchTheGolden() {
  testWidgets('RunDone should match the golden', tags: _goldenTag, (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      (_) => Stack(
        children: [
          const ColoredBox(color: Color(0xFFFFFFFF), child: SizedBox.expand()),
          ColoredBox(color: sampleTheme.scrim, child: const SizedBox.expand()),
          Align(
            alignment: Alignment.bottomCenter,
            child: AutomationRunDoneSheet(
              outcome: 'Sign-up needed',
              stepCount: 6,
              duration: const Duration(seconds: 41),
              requests: const [
                AutomationCatalogueRequest(
                  method: 'POST',
                  path: '/auth/send-code',
                  statusCode: 200,
                ),
                AutomationCatalogueRequest(
                  method: 'POST',
                  path: '/auth/otp',
                  statusCode: 200,
                ),
                AutomationCatalogueRequest(
                  method: 'POST',
                  path: '/auth/sign-up',
                  statusCode: 500,
                ),
                AutomationCatalogueRequest(
                  method: 'GET',
                  path: '/profile/me',
                  statusCode: 200,
                ),
              ],
              onShare: () {},
              onRunAgain: () {},
              onExit: () {},
            ),
          ),
        ],
      ),
    );
    await _expectGolden('run_done');
  });
}
