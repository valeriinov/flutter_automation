import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_cleaner.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_comparison.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_split.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_answer_comparison.dart';
import 'package:flutter_automation_atlas/src/atlas_source_hash.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';

const fakeAtlasLocales = ['uk', 'en'];

final fakeFlutterCommand = _writeFakeFlutter();

const fakeSignInPath = '/session/start';
const fakeSignInKind = 'session';

Map<String, Object?>? implyFakeSignIn(
  List<Map<String, Object?>> earlierAnswers,
  Map<String, Object?> answer,
) {
  if (!_isSignInRequest(answer)) {
    return null;
  }

  final lastSignIn = earlierAnswers.lastWhereOrNull(
    (earlier) => _isSignInRecord(earlier) || _isSignInRequest(earlier),
  );

  if (lastSignIn != null && !_isSignInRequest(lastSignIn)) {
    return null;
  }

  return {
    'kind': fakeSignInKind,
    'via': ?switch (answer['body']) {
      {'via': final String via} => via,
      _ => null,
    },
    'hasIdentity': true,
  };
}

bool _isSignInRecord(Map<String, Object?> record) {
  return record['kind'] == fakeSignInKind;
}

bool _isSignInRequest(Map<String, Object?> record) {
  return record['kind'] == 'request' && record['path'] == fakeSignInPath;
}

final fakeAtlasJournalSchema = AtlasJournalSchema(
  analyticsKind: 'analytics',
  stateKind: 'state',
  requestKinds: {'request', 'socket'},
  launchKind: 'launch',
  answerKinds: {'request', 'socket', 'session', 'launch', 'device', 'cart'},
  stateKey: 'owner',
  createdKey: 'created',
  parametersKey: 'parameters',
  screenNameParameter: 'screen_name',
  screenViewName: 'screen_opened',
  volatileKeys: {
    'session_id',
    'visit_ms',
    'expiredAt',
    'itemStartDate',
    'created_at',
    'updated_at',
    'last_active',
    'seen_at',
  },
  tryImplyAnswer: implyFakeSignIn,
  installValue: AtlasJournalPlaceholder(
    pattern: r'[\w-]+:tok[\w-]+',
    placeholder: '<install>',
  ),
  generatedValue: AtlasJournalPlaceholder(
    pattern: r'upload_\d+\.jpg',
    placeholder: '<generated>',
  ),
);

const fakeAtlasStaleSettings = AtlasStaleSettings(
  mockDirectory: 'lib/support/mock/',
  targetsDirectory: 'lib/support/automation/targets/',
  automationDirectory: 'lib/support/automation/',
  routes: AtlasRouteSettings(
    routesPath: 'lib/app/router.g.dart',
    routerPath: 'lib/app/router.dart',
    routePattern: r'^/// \[(\w+)\]\s*\nclass (\w+)\s+extends GeneratedRoute',
  ),
  stopPaths: ['lib/app/router.dart', 'lib/app/registry.dart'],
  uncomparedPaths: [
    'lib/app/data/api_paths.dart',
    'lib/app/data/analytics/',
    'lib/app/diagnostics/',
    'lib/app/diagnostics_service.dart',
  ],
  themeClassPattern:
      r'^(?:Ui\w*Ext|_Ui\w*(?:Styles|Colors|Sizes|Shadows|Overlays|Durations)|'
      r'Ui\w*Factory|_\$Ui\w*ExtMixin)$',
  themeValueClassPattern:
      r'^_Ui\w*(?:Styles|Colors|Sizes|Shadows|Overlays|Durations)$',
  themeExtensionPattern: r'^Ui\w*Ext$',
  themeFactorySuffix: 'Factory',
  excludedSuffix: '.config.dart',
  registrationAnnotations: {'Register', 'Provide'},
  selfRegistrationAnnotations: {
    'Register',
    'Provide',
    'Single',
    'register',
    'provide',
    'single',
  },
  moduleAnnotation: 'bundle',
  registrationArgument: 'as',
);

const fakeAtlasHeadlessSettings = AtlasHeadlessSettings(
  copiedDirectories: ['scripts', 'test/headless'],
  entryImports: [
    'test/headless/headless_app.dart',
    'test/headless/headless_suite.dart',
  ],
  entryMain: 'void main() => runHeadlessSuite(_runAppMain);',
  mainPath: 'lib/main.dart',
  mainPatch: [
    (
      'void main(List<String> args) async {',
      'Future<void> _runAppMain(List<String> args) async {',
    ),
    ('await Boot.initialize(flavor);', 'await HeadlessApp.initialize(flavor);'),
    ('  runApp(', '  HeadlessApp.runApp('),
    ('Boot.afterFirstFrame();', ''),
  ],
  stubbedPaths: [
    'lib/entries/',
    'lib/app/adapters/device_adapter.dart',
    'lib/app/adapters/storage_adapter.dart',
    'lib/app/diagnostics/',
    'lib/app/diagnostics_service.dart',
    'lib/app/notifications_service.dart',
    'lib/app/modules/tracker_',
    'lib/app/modules/cache_module.dart',
    'lib/app/modules/image_cache_module.dart',
  ],
  keptDeclarations: {
    'lib/app/boot.dart': {'Boot', 'Boot.resolveLanguage'},
  },
  stubbedDeclarations: {
    'lib/app/input_validator.dart': {'InputValidator.parse'},
  },
  defines: ['APP_SCENARIO=base', 'ENABLE_AUTOMATION=true'],
  tryReadRecordedValues: readFakeRecordedValues,
);

final fakeAtlasGroups = [
  AutomationFlowGroup(name: 'other', title: _title('Other')),
  AutomationFlowGroup(name: 'basket', title: _title('Basket')),
];

final class FakeAtlasProject implements AtlasProject {
  final Set<String> acceptedEvents = {};
  final Map<String, Map<String, Object?>> translationsByLocale = {};
  final List<AtlasStoreReader> reportedStores = [];
  final List<AtlasTable> tablesToReturn = [];
  final Map<String, Map<String, String>> descriptions = {};
  final Map<String, String> designLinks = {};
  AtlasShotStorage? storage;
  final List<String> commandPrefix;
  final AtlasStaleSettings? staleSettingsOverride;
  final AtlasPaths? pathsOverride;
  RegExp? usagePattern;

  @override
  final List<String> locales;

  @override
  final List<AutomationFlowGroup> groupOrder;

  FakeAtlasProject({
    this.locales = fakeAtlasLocales,
    List<AutomationFlowGroup>? groupOrder,
    List<String>? commandPrefix,
    this.staleSettingsOverride,
    this.pathsOverride,
  }) : groupOrder = groupOrder ?? fakeAtlasGroups,
       commandPrefix = commandPrefix ?? [fakeFlutterCommand];

  @override
  AtlasPaths get paths {
    return pathsOverride ??
        const AtlasPaths(
          runnerEntry: 'tool/run_flows.dart',
          output: 'atlas_store',
          build: 'build/atlas',
          recordings: 'assets/recordings',
          publishedVariants: 'scripts/published_variants.json',
        );
  }

  @override
  AtlasLaunchSettings get launchSettings => AtlasLaunchSettings(
    entry: 'lib/main.dart',
    flavor: 'dev',
    defines: const ['ENABLE_AUTOMATION=true'],
    commandPrefix: commandPrefix,
  );

  @override
  AtlasJournalSchema get journalSchema => fakeAtlasJournalSchema;

  @override
  AtlasStaleSettings get staleSettings {
    return staleSettingsOverride ?? fakeAtlasStaleSettings;
  }

  @override
  AtlasHeadlessSettings get headlessSettings => fakeAtlasHeadlessSettings;

  @override
  String get mockReplayEntry => 'test/mock_replay_test.dart';

  @override
  String get designScreenKey => 'designScreenName';

  @override
  List<AtlasTable> tables(AtlasStoreReader store) => tablesToReturn;

  @override
  Map<String, Object?> translations(String locale) {
    return translationsByLocale[locale] ?? const {};
  }

  @override
  RegExp? get localeKeyUsagePattern => usagePattern;

  @override
  Map<String, Map<String, String>> get screenDescriptions => descriptions;

  @override
  String? designLink(String screen) => designLinks[screen];

  @override
  String get projectName => 'Sample';

  @override
  AutomationFlowGroup get defaultGroup => fakeAtlasGroups.first;

  @override
  List<String> get sourceDirtyIgnores => const ['local.env'];

  @override
  void writeReports(AtlasStoreReader store) {
    reportedStores.add(store);
  }

  @override
  AtlasShotStorage? get shotStorage => storage;

  @override
  bool isCataloguedAnalytics(Map<String, Object?> record) {
    return acceptedEvents.contains(record['name']);
  }
}

AutomationLocalizedText _title(String text) {
  return AutomationLocalizedText({'uk': text, 'en': text});
}

final testJournalComparison = AtlasJournalComparison(fakeAtlasJournalSchema);

final testSourceHash = AtlasSourceHash(fakeAtlasStaleSettings);

final testJournalCleaner = AtlasJournalCleaner(fakeAtlasJournalSchema);

final testJournalSplit = AtlasJournalSplit(fakeAtlasJournalSchema);

final testMockAnswerComparison = AtlasMockAnswerComparison(
  fakeAtlasJournalSchema,
);

const _filesPath = '/files';

Map<String, Object?>? readFakeRecordedValues(List<Object?> records) {
  final sizes = [
    for (final record in records)
      if (record case {'path': _filesPath, 'body': {'size': final int size}})
        size,
  ];

  return sizes.isEmpty ? null : {'fileSizes': sizes};
}

String _writeFakeFlutter() {
  final directory = Directory.systemTemp.createTempSync('atlas-fake-flutter-');
  final file = File('${directory.path}/fake_flutter')
    ..writeAsStringSync(r'''
#!/bin/sh
version=$(sed -n 's/.*"flutter"[^"]*"\([^"]*\)".*/\1/p' .fvmrc 2>/dev/null)
printf '{"frameworkVersion": "%s"}\n' "$version"
''');

  Process.runSync('chmod', ['+x', file.path]);

  return file.path;
}
