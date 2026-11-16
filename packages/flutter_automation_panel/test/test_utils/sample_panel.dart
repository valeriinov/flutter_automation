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
const sampleStrings = AutomationPanelStrings();

final authSection = MockSection<Map<String, Object?>>(
  name: 'auth',
  title: const AutomationLocalizedText({'en': 'Auth', 'uk': 'Авторизація'}),
  description: const AutomationLocalizedText({
    'en': 'The sign-in screens and the session.',
  }),
  fromJson: (json) => json,
  profiles: {
    'signedIn': MockProfile(
      (settings) => {...settings, 'isSignedInOnLaunch': true},
      title: const AutomationLocalizedText({
        'en': 'Signed in',
        'uk': 'Увійшов',
      }),
      description: const AutomationLocalizedText({
        'en': 'The app starts with a signed-in user.',
      }),
    ),
    'signedOut': MockProfile(
      (settings) => {...settings, 'isSignedInOnLaunch': false},
      title: const AutomationLocalizedText({'en': 'Sign-up needed'}),
    ),
    'slowCode': MockProfile(
      (settings) => {...settings, 'codeDelay': 3},
      title: const AutomationLocalizedText({'en': 'Slow code'}),
    ),
  },
  restartKeys: {'isSignedInOnLaunch'},
);

final itemsSection = MockSection<Map<String, Object?>>(
  name: 'items',
  title: const AutomationLocalizedText({'en': 'Items'}),
  fromJson: (json) => json,
  profiles: {
    'threeItems': MockProfile(
      (settings) => {'count': 3},
      title: const AutomationLocalizedText({'en': 'Three items'}),
    ),
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
  final ValueNotifier<bool> isRestartRequired;

  const SamplePanel({
    required this.directory,
    required this.mock,
    required this.controller,
    required this.isRestartRequired,
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
    SamplePanel? restartOf,
    AutomationFlowPlayer? player,
    AutomationCatalogue? catalogue,
    FutureOr<void> Function(BuildContext context, File report)? onShare,
    AutomationPanelStrings strings = sampleStrings,
  }) async {
    final directory =
        restartOf?.directory ?? Directory.systemTemp.createTempSync('sample');
    final isRestartRequired = ValueNotifier(false);

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
      strings: strings,
      backendErrorCodes: const ['tooManyRequests', 'invalidPhone'],
      readEndpointResolver: () => _sampleEndpointResolver,
      sections: _sampleSections,
      isRestartRequired: isRestartRequired,
      onShare: onShare,
      pages: [
        AutomationPanelPage(
          label: 'Flows',
          builder: (_) => const AutomationFlowsPage(),
        ),
        AutomationPanelPage(
          label: 'Sections',
          builder: (_) => AutomationSectionsPage(sections: _sampleSections),
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
      isRestartRequired: isRestartRequired,
    );
  }

  void dispose() {
    controller.dispose();
    isRestartRequired.dispose();

    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }
}

final _sampleSections = [
  AutomationSectionPanel.fromSection(authSection, api: _SampleApi()),
  AutomationSectionPanel.fromSection(itemsSection),
];

final _sampleEndpointResolver = MockApiEndpointResolver([
  _SampleApi(),
  _ItemsApi(),
]);

class _ItemsApi implements MockApi {
  @override
  List<MockApiEndpoint> get endpoints {
    return [
      MockApiEndpoint(path: '/items', respond: _respondEmpty, hasPathId: true),
      MockApiEndpoint(path: '/items/list', respond: _respondEmpty),
    ];
  }

  static MockApiResponse _respondEmpty(MockApiRequest _) {
    return const MockApiResponse(body: {});
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
  AutomationFlowPlayer? player,
  AutomationCatalogue? catalogue,
  FutureOr<void> Function(BuildContext context, File report)? onShare,
  AutomationPanelStrings strings = sampleStrings,
  MockScenario scenario = const MockScenario([]),
}) async {
  final sample = await tester.runAsync(
    () => SamplePanel.create(
      player: player,
      catalogue: catalogue,
      onShare: onShare,
      strings: strings,
      scenario: scenario,
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
