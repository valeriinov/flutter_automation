import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

const signUpPath = '/auth/sign-up';
const verifyPath = '/auth/otp';
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
  path: verifyPath,
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

Map<String, Object?> _byKey(String key) => {'by': 'valueKey', 'value': key};

final _steps = [
  AutomationCatalogueStep(
    label: 'Phone screen',
    action: 'waitFor',
    finder: _byKey('login.phone'),
    requests: const [_sendCode],
  ),
  AutomationCatalogueStep(
    label: 'After code entry',
    action: 'enterText',
    title: const {'en': 'Type the code'},
    text: '123456',
    requests: const [_verifyCode],
  ),
  AutomationCatalogueStep(
    label: 'Sign-up',
    action: 'tap',
    title: const {'en': 'Create the account'},
    finder: _byKey('login.sign_up'),
    requests: const [_signUp],
  ),
  AutomationCatalogueStep(
    label: 'Profile',
    action: 'waitFor',
    finder: _byKey('login.profile'),
    requests: const [_profile],
  ),
  const AutomationCatalogueStep(label: 'trace', isService: true),
];

final sampleCatalogue = AutomationCatalogue(
  groups: const [
    AutomationCatalogueGroup(name: 'account', title: {'en': 'Sign-in'}),
    AutomationCatalogueGroup(name: 'items', title: {'en': 'Catalog'}),
    AutomationCatalogueGroup(name: 'chat', title: {'en': 'Chat'}),
  ],
  flows: [
    AutomationCatalogueFlow(
      name: 'login',
      group: 'account',
      title: const {'en': 'Sign-in and sign-up'},
      defaultVariant: 'signUpNeeded',
      fork: const AutomationCatalogueFork(
        stepIndex: 2,
        branches: [
          AutomationCatalogueBranch(
            variant: 'signUpNeeded',
            label: 'Sign-up needed',
          ),
          AutomationCatalogueBranch(
            variant: 'accountExists',
            label: 'Account exists',
          ),
        ],
      ),
      variants: [
        AutomationCatalogueVariant(
          name: 'signUpNeeded',
          title: const {'en': 'Sign-up needed'},
          entry: const {'en': 'signed out'},
          scenario: const {
            'auth': {'codeDelay': 3},
          },
          steps: _steps,
        ),
        AutomationCatalogueVariant(
          name: 'accountExists',
          title: const {'en': 'Account exists'},
          entry: const {'en': 'signed out'},
          scenario: const {
            'auth': {'codeDelay': 0},
          },
          steps: _steps,
        ),
      ],
    ),
    AutomationCatalogueFlow(
      name: 'itemCreate',
      group: 'items',
      title: const {'en': 'Create an item'},
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
      title: const {'en': 'Support chat'},
      variants: [AutomationCatalogueVariant(name: 'a')],
    ),
  ],
);

final sessionFlow = AutomationCatalogueFlow(
  name: 'session',
  group: 'account',
  title: const {'en': 'Session restore'},
  defaultVariant: 'signedIn',
  fork: const AutomationCatalogueFork(
    stepIndex: 0,
    branches: [
      AutomationCatalogueBranch(
        variant: 'signedIn',
        label: 'Signed in',
        isChosenBeforeStart: true,
      ),
      AutomationCatalogueBranch(
        variant: 'signedOut',
        label: 'Signed out',
        isChosenBeforeStart: true,
      ),
    ],
  ),
  variants: [
    AutomationCatalogueVariant(
      name: 'signedIn',
      title: const {'en': 'Signed in'},
      scenario: const {
        'auth': {'isSignedInOnLaunch': true},
      },
      steps: _steps,
    ),
    AutomationCatalogueVariant(
      name: 'signedOut',
      title: const {'en': 'Signed out'},
      scenario: const {
        'auth': {'isSignedInOnLaunch': false},
      },
      steps: _steps,
    ),
  ],
);

/// The sample catalogue and a flow whose branches need a restart.
final sampleCatalogueWithSession = AutomationCatalogue(
  groups: sampleCatalogue.groups,
  flows: [...sampleCatalogue.flows, sessionFlow],
);

/// Plays no step: it records what the controller asks it to play. It fails
/// the step whose label is [failingLabel], with [failingError] when that is
/// set. It waits for [hold] before it records a step.
class RecordingPlayer extends AutomationFlowPlayer {
  final List<String> played = [];
  String? failingLabel;
  Object? failingError;
  Future<void>? hold;

  RecordingPlayer({this.failingLabel, this.failingError, this.hold});

  @override
  Future<void> play(
    AutomationCatalogueStep step, {
    bool Function()? isStopped,
  }) async {
    await hold;

    if (step.label == failingLabel) {
      throw failingError ??
          AutomationPlayerException('"${step.label}" did not appear.');
    }

    played.add(step.label);
  }
}

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

  /// Moves the walk of [sample] to the step [stepIndex].
  static Future<void> moveWalk(SamplePanel sample, int stepIndex) async {
    final walk = sample.mock.walk;

    if (walk != null) {
      await sample.mock.saveWalk(walk.atStep(stepIndex));
    }
  }

  /// A [restartOf] sample starts a new mock over the folder of that sample,
  /// as a cold start of the app does.
  static Future<SamplePanel> create({
    MockScenario scenario = const MockScenario([]),
    FutureOr<void> Function()? onRestartRequired,
    SamplePanel? restartOf,
    AutomationFlowPlayer? player,
    AutomationCatalogue? catalogue,
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
      catalogue: catalogue ?? sampleCatalogue,
      theme: sampleTheme,
      backendErrorCodes: const ['tooManyRequests', 'invalidPhone'],
      onRestartRequired: onRestartRequired ?? () => events.add('restart'),
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
          builder: (_) => const AutomationAutorunPage(),
        ),
      ],
    );

    return SamplePanel(
      directory: directory,
      mock: mock,
      controller: AutomationPanelController(definition, player: player),
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
  AutomationFlowPlayer? player,
  AutomationCatalogue? catalogue,
}) async {
  final sample = await tester.runAsync(
    () => SamplePanel.create(
      onRestartRequired: onRestartRequired,
      player: player,
      catalogue: catalogue,
    ),
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
