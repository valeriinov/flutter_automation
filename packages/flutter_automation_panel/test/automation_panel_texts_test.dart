import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils/sample_panel.dart';

const _strings = _UkrainianStrings();
const _authTitle = 'Авторизація';
const _changedScenario = {
  'latency': 'slow',
  'auth': {'isSignedInOnLaunch': true},
  'items': {'count': 3},
};

void main() {
  group('Automation Panel Texts Tests', () {
    _automationSectionsPage_should_readTheTextsInTheStringsLanguage();
    _automationSectionsPage_should_fallBackToEnglishWithoutTheLanguage();
    _automationPanel_should_countTheChangesWithTheWordsOfTheStrings();
    _automationPanelDefinition_should_labelTheTabsWithTheStrings();
    _automationSectionsPage_should_titleTheRequestsByTheirEndpoints();
    _automationRestartOverlay_should_showTheTextsOfItsStrings();
    _automationMockModeTile_should_showTheTextsOfItsStrings();
    _automationConfirmSheet_should_takeTheStringsOfThePanel();
    _showAutomationRestartSheet_should_takeTheStringsOfThePanel();
    _automationFlowPlayer_should_wordTheFailureWithTheStrings();
  });
}

void _automationSectionsPage_should_readTheTextsInTheStringsLanguage() {
  testWidgets(
    'AutomationSectionsPage should read the texts in the strings language',
    (tester) async {
      await _pumpPage(tester, const AutomationPanel(initialTab: 1));

      expect(find.text(_authTitle), findsOneWidget);
      expect(find.text('Auth'), findsNothing);

      await tester.tap(find.text(_strings.profile).first);
      await tester.pumpAndSettle();

      expect(find.text(_strings.profileSheetTitle(_authTitle)), findsOneWidget);
      expect(find.text('Увійшов'), findsOneWidget);
    },
  );
}

void _automationSectionsPage_should_fallBackToEnglishWithoutTheLanguage() {
  testWidgets(
    'AutomationSectionsPage should fall back to English without the language',
    (tester) async {
      await _pumpPage(tester, const AutomationPanel(initialTab: 1));
      await tester.tap(find.text(_strings.profile).first);
      await tester.pumpAndSettle();

      expect(find.text('Sign-up needed'), findsOneWidget);
      expect(find.text('Signed in'), findsNothing);
    },
  );
}

void _automationPanel_should_countTheChangesWithTheWordsOfTheStrings() {
  testWidgets(
    'AutomationPanel should count the changes with the words of the strings',
    (tester) async {
      await _pumpPage(
        tester,
        const AutomationPanel(),
        scenario: MockScenario.fromJson(_changedScenario),
      );

      expect(
        find.textContaining('3 зміни', findRichText: true),
        findsOneWidget,
      );
    },
  );
}

void _automationPanelDefinition_should_labelTheTabsWithTheStrings() {
  testWidgets(
    'AutomationPanelDefinition should label the tabs with the strings',
    (tester) async {
      final sample = await createSamplePanel(tester);

      final definition = AutomationPanelDefinition.standard(
        mock: sample.mock,
        catalogue: sample.controller.definition.catalogue,
        isRestartRequired: sample.isRestartRequired,
        strings: _strings,
      );

      expect(definition.pages.map((page) => page.label), [
        'Потоки',
        'Autorun',
        'Sections',
        'Log',
      ]);
    },
  );
}

void _automationSectionsPage_should_titleTheRequestsByTheirEndpoints() {
  testWidgets(
    'AutomationSectionsPage should title the requests by their endpoints',
    (tester) async {
      final section = AutomationSectionPanel(
        title: const AutomationLocalizedText({'en': 'Orders'}),
        api: _TitledApi(),
      );

      final sample = await createSamplePanel(tester);

      await tester.pumpWidget(
        hostApp(
          child: panelHost(
            sample,
            _panelNavigator(AutomationSectionsPage(sections: [section])),
          ),
        ),
      );
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      expect(find.text('Place an order'), findsOneWidget);
      expect(find.text('/orders/untitled'), findsWidgets);
    },
  );
}

void _automationRestartOverlay_should_showTheTextsOfItsStrings() {
  testWidgets('AutomationRestartOverlay should show the texts of its strings', (
    tester,
  ) async {
    final isRestartRequired = ValueNotifier(true);

    addTearDown(isRestartRequired.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AutomationRestartOverlay(
          isRestartRequired: isRestartRequired,
          strings: _strings,
          child: const SizedBox(),
        ),
      ),
    );

    expect(find.text(_strings.restartScreenTitle), findsOneWidget);
    expect(find.text('Close and open the app'), findsNothing);
  });
}

void _automationMockModeTile_should_showTheTextsOfItsStrings() {
  testWidgets('AutomationMockModeTile should show the texts of its strings', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('mode_tile_texts');
    final isRestartRequired = ValueNotifier(false);
    final controller = AutomationModeController(
      store: AutomationStateStore(directory.path),
      mode: AutomationMode.server,
      isRestartRequired: isRestartRequired,
    );

    addTearDown(() => directory.deleteSync(recursive: true));
    addTearDown(controller.dispose);
    addTearDown(isRestartRequired.dispose);

    await tester.pumpWidget(
      hostApp(
        child: AutomationMockModeTile(
          controller: controller,
          strings: _strings,
        ),
      ),
    );

    expect(find.text(_strings.mockMode), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text(_strings.restartQuestion), findsOneWidget);
    expect(find.text(_strings.cancel), findsOneWidget);
    expect(find.byTooltip(_strings.close), findsOneWidget);
  });
}

void _automationConfirmSheet_should_takeTheStringsOfThePanel() {
  testWidgets('AutomationConfirmSheet should take the strings of the panel', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      Builder(
        builder: (context) {
          return TextButton(
            onPressed: () => showAutomationConfirmSheet(
              context: context,
              title: 'Title',
              message: 'Message',
              confirmLabel: 'Confirm',
              onConfirmPressed: () {},
            ),
            child: const Text('Open'),
          );
        },
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text(_strings.cancel), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.byTooltip(_strings.close), findsOneWidget);
  });
}

void _showAutomationRestartSheet_should_takeTheStringsOfThePanel() {
  testWidgets(
    'showAutomationRestartSheet should take the strings of the panel',
    (tester) async {
      await _pumpPage(
        tester,
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showAutomationRestartSheet(
                context: context,
                onConfirmPressed: () {},
              ),
              child: const Text('Open'),
            );
          },
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(_strings.restartQuestion), findsOneWidget);
      expect(find.text(sampleStrings.restartQuestion), findsNothing);
    },
  );
}

void _automationFlowPlayer_should_wordTheFailureWithTheStrings() {
  test(
    'AutomationFlowPlayer should word the failure with the strings',
    () async {
      final player = AutomationFlowPlayer(strings: _strings);

      addTearDown(player.dispose);

      await expectLater(
        player.play(const AutomationCatalogueStep(label: 'Tap', action: 'tap')),
        throwsA(
          isA<AutomationPlayerException>().having(
            (error) => error.reason,
            'reason',
            _strings.stepHasNoTarget('Tap'),
          ),
        ),
      );
    },
  );
}

Future<SamplePanel> _pumpPage(
  WidgetTester tester,
  Widget page, {
  MockScenario scenario = const MockScenario([]),
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(780, 1688);

  addTearDown(tester.view.reset);

  final sample = await createSamplePanel(
    tester,
    scenario: scenario,
    strings: _strings,
  );

  await tester.pumpWidget(
    hostApp(child: panelHost(sample, _panelNavigator(page))),
  );

  return sample;
}

Widget _panelNavigator(Widget page) {
  return Navigator(
    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => page),
  );
}

class _UkrainianStrings extends AutomationPanelStrings {
  const _UkrainianStrings();

  @override
  String get languageCode => 'uk';

  @override
  String get mockMode => 'Режим мока';

  @override
  String get restartQuestion => 'Застосувати й перезапустити?';

  @override
  String stepHasNoTarget(String step) => '"$step" не вказує елемент.';

  @override
  String get restartScreenTitle => 'Закрийте й відкрийте застосунок';

  @override
  String get flowsTab => 'Потоки';

  @override
  String get cancel => 'Скасувати';

  @override
  String get close => 'Закрити';

  @override
  String get profile => 'Профіль';

  @override
  String profileSheetTitle(String sectionTitle) => 'Профіль: $sectionTitle';

  @override
  String changeCount(int count) => '$count зміни';
}

class _TitledApi implements MockApi {
  @override
  List<MockApiEndpoint> get endpoints {
    return [
      MockApiEndpoint(
        path: '/orders',
        title: const AutomationLocalizedText({'en': 'Place an order'}),
        respond: (request) async => const MockApiResponse(body: {}),
      ),
      MockApiEndpoint(
        path: '/orders/untitled',
        respond: (request) async => const MockApiResponse(body: {}),
      ),
    ];
  }
}
