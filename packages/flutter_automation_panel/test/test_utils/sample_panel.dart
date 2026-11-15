import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

const signUpPath = '/auth/sign-up';
const sampleTheme = AutomationPanelTheme.light(fontFamily: 'Roboto');

final authSection = MockSection<Map<String, Object?>>(
  name: 'auth',
  fromJson: (json) => json,
  profiles: {
    'signedIn': (settings) => {...settings, 'isSignedInOnLaunch': true},
    'signedOut': (settings) => {...settings, 'isSignedInOnLaunch': false},
    'slowCode': (settings) => {...settings, 'codeDelay': 3},
  },
  restartKeys: {'isSignedInOnLaunch'},
);

final itemsSection = MockSection<Map<String, Object?>>(
  name: 'items',
  fromJson: (json) => json,
  profiles: {
    'threeItems': (settings) => {'count': 3},
  },
);

const _sendCode = AutomationCatalogueRequest(
  method: 'POST',
  path: '/auth/send-code',
  statusCode: 200,
);
const _verifyCode = AutomationCatalogueRequest(
  method: 'POST',
  path: '/auth/otp',
  statusCode: 200,
);
const _signUp = AutomationCatalogueRequest(
  method: 'POST',
  path: signUpPath,
  statusCode: 200,
);
const _profile = AutomationCatalogueRequest(
  method: 'GET',
  path: '/profile/me',
  statusCode: 200,
);

const _steps = [
  AutomationCatalogueStep(label: 'Phone screen', requests: [_sendCode]),
  AutomationCatalogueStep(label: 'After code entry', requests: [_verifyCode]),
  AutomationCatalogueStep(label: 'Sign-up', requests: [_signUp]),
  AutomationCatalogueStep(label: 'Profile', requests: [_profile]),
  AutomationCatalogueStep(label: 'trace', isService: true),
];

const sampleCatalogue = AutomationCatalogue(
  groups: [
    AutomationCatalogueGroup(name: 'account', title: {'en': 'Sign-in'}),
    AutomationCatalogueGroup(name: 'items', title: {'en': 'Catalog'}),
    AutomationCatalogueGroup(name: 'chat', title: {'en': 'Chat'}),
  ],
  flows: [
    AutomationCatalogueFlow(
      name: 'login',
      group: 'account',
      title: {'en': 'Sign-in and sign-up'},
      defaultVariant: 'signUpNeeded',
      fork: AutomationCatalogueFork(
        stepIndex: 1,
        method: 'POST',
        path: '/auth/otp',
        branches: [
          AutomationCatalogueBranch(
            variant: 'signUpNeeded',
            label: 'Sign-up needed',
            statusCode: 200,
          ),
          AutomationCatalogueBranch(
            variant: 'accountExists',
            label: 'Account exists',
            statusCode: 200,
          ),
        ],
      ),
      variants: [
        AutomationCatalogueVariant(
          name: 'signUpNeeded',
          title: {'en': 'sign-up error'},
          entry: {'en': 'signed out'},
          scenario: {
            'auth': {'isSignedInOnLaunch': false},
          },
          steps: _steps,
        ),
        AutomationCatalogueVariant(
          name: 'accountExists',
          title: {'en': 'signed in'},
          entry: {'en': 'signed out'},
          scenario: {
            'auth': {'isSignedInOnLaunch': true},
          },
          steps: _steps,
        ),
      ],
    ),
    AutomationCatalogueFlow(
      name: 'itemCreate',
      group: 'items',
      title: {'en': 'Create an item'},
      variants: [
        AutomationCatalogueVariant(name: 'a'),
        AutomationCatalogueVariant(name: 'b'),
        AutomationCatalogueVariant(name: 'c'),
        AutomationCatalogueVariant(name: 'd'),
        AutomationCatalogueVariant(name: 'e'),
      ],
    ),
    AutomationCatalogueFlow(
      name: 'supportChat',
      group: 'chat',
      title: {'en': 'Support chat'},
      variants: [AutomationCatalogueVariant(name: 'a')],
    ),
  ],
);

final class SamplePanel {
  final Directory directory;
  final AutomationMock mock;
  final AutomationPanelController controller;
  final List<String> events;

  const SamplePanel({
    required this.directory,
    required this.mock,
    required this.controller,
    required this.events,
  });

  /// A [restartOf] sample starts a new mock over the folder of that sample,
  /// as a cold start of the app does.
  static Future<SamplePanel> create({
    MockScenario scenario = const MockScenario([]),
    FutureOr<void> Function()? onRestartRequired,
    SamplePanel? restartOf,
  }) async {
    final directory =
        restartOf?.directory ?? Directory.systemTemp.createTempSync('sample');
    final events = <String>[];

    final mock = await AutomationMock.init(
      isEnabled: true,
      scenarioDirectory: directory.path,
      stateStore: AutomationStateStore(directory.path),
      sections: [authSection, itemsSection],
    );

    if (restartOf == null) {
      await mock.updateScenario(scenario);
    }

    final definition = AutomationPanelDefinition(
      mock: mock,
      catalogue: sampleCatalogue,
      theme: sampleTheme,
      backendErrorCodes: const ['tooManyRequests', 'invalidPhone'],
      onRestartRequired: onRestartRequired ?? () => events.add('restart'),
      onStart: (flow, variant) => events.add('start $flow $variant'),
      pages: [
        AutomationPanelPage(
          label: 'Flows',
          builder: (_) => const AutomationFlowsPage(),
        ),
        AutomationPanelPage(
          label: 'Sections',
          builder: (_) => AutomationSectionsPage(
            sections: [
              AutomationSectionPanel(
                title: 'Auth',
                section: authSection,
                api: _SampleApi(),
                profileTitles: const {
                  'signedIn': 'Signed in',
                  'signedOut': 'Sign-up needed',
                  'slowCode': 'Slow code',
                },
              ),
              AutomationSectionPanel(
                title: 'Items',
                section: itemsSection,
                profileTitles: const {'threeItems': 'Three items'},
              ),
            ],
          ),
        ),
        AutomationPanelPage(
          label: 'Log',
          builder: (_) => const AutomationJournalPage(),
        ),
        AutomationPanelPage(
          label: 'Autorun',
          builder: (_) => const SizedBox.shrink(),
        ),
      ],
    );

    return SamplePanel(
      directory: directory,
      mock: mock,
      controller: AutomationPanelController(definition),
      events: events,
    );
  }

  void dispose() {
    controller.dispose();

    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }
}

class _SampleApi implements MockApi {
  @override
  List<MockApiEndpoint> get endpoints {
    return [
      for (final path in ['/auth/send-code', '/auth/otp', signUpPath])
        MockApiEndpoint(
          path: path,
          respond: (request) async => const MockApiResponse(body: {}),
        ),
    ];
  }
}

/// Creates a [SamplePanel] on real IO and removes it when the test ends.
Future<SamplePanel> createSamplePanel(
  WidgetTester tester, {
  FutureOr<void> Function()? onRestartRequired,
}) async {
  final sample = await tester.runAsync(
    () => SamplePanel.create(onRestartRequired: onRestartRequired),
  );

  if (sample == null) {
    fail('runAsync returned no sample panel');
  }

  addTearDown(sample.dispose);

  return sample;
}

/// Hosts [child] in an app whose own theme differs from the panel theme.
Widget hostApp({required Widget child, ThemeData? theme}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: Scaffold(body: child),
  );
}

/// A page of the panel inside its scope and its own theme.
Widget panelHost(SamplePanel sample, Widget child) {
  return Theme(
    data: sampleTheme.toThemeData(),
    child: AutomationPanelScope(controller: sample.controller, child: child),
  );
}
