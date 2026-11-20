import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/flutter_automation_runner.dart';

const _catalogueText =
    '{"flows":{"login":{"variants":{}}},"blocks":{"open":{"steps":[]}}}';

const _pubspec = '''
name: sample
flutter_automation:
  defaultLocale: uk
''';

const _finderPubspec = '''
name: sample
flutter_automation:
  finders:
    calendarDay:
      kind: dateValueKey
      template: day.tile.{yyyyMMdd}
''';

const _walkStep = {
  'action': 'tap',
  'label': 'open',
  'finder': {'by': 'valueKey', 'value': 'login.open'},
};

const _probeStep = {
  'action': 'probeSeries',
  'label': 'measure',
  'durationMs': 1000,
  'probes': [
    {
      'name': 'list',
      'finder': {'by': 'valueKey', 'value': 'list'},
    },
  ],
};

void main() {
  group('AutomationFlowCatalogue Tests', () {
    _automationFlowCatalogue_should_decodeFlowsAndBlocks();
    _automationFlowCatalogue_should_nameErrorLineOfRunner();
    _automationFlowCatalogue_should_rejectCatalogueWithoutBlocks();
    _automationFlowCatalogue_should_rejectCatalogueWithoutFlows();
    _automationFlowCatalogue_should_rejectTextThatIsNotJson();
    _automationFlowCatalogue_should_rejectFlowWithoutVariants();
    _automationFlowCatalogue_should_ignoreLaterChangesOfCallerMaps();
    _automationFlowCatalogue_should_answerSeededRootWithoutRunningRunner();
    _automationFlowCatalogue_should_resolveEveryVariantWithProbeSeries();
    _automationFlowCatalogue_should_giveDefaultLocaleOfProject();
    _automationFlowCatalogue_should_giveFindersOfProject();
    _automationFlowCatalogue_should_tellDefaultVariantOfFlow();
  });
}

void _automationFlowCatalogue_should_decodeFlowsAndBlocks() {
  test('AutomationFlowCatalogue should decode flows and blocks', () {
    final catalogue = AutomationFlowCatalogue.decode(
      _catalogueText,
      rootPath: '.',
    );

    expect(catalogue.flows.keys, ['login']);
    expect(catalogue.blocks.keys, ['open']);
  });
}

void _automationFlowCatalogue_should_nameErrorLineOfRunner() {
  test('AutomationFlowCatalogue should name error line of runner', () {
    expect(
      () => AutomationFlowCatalogue.decode(
        '{"error":"declared twice"}',
        rootPath: '.',
      ),
      throwsA(
        isA<AutomationRunnerException>().having(
          (error) => error.message,
          'message',
          'The runner failed: declared twice',
        ),
      ),
    );
  });
}

void _automationFlowCatalogue_should_rejectCatalogueWithoutBlocks() {
  test('AutomationFlowCatalogue should reject catalogue without blocks', () {
    expect(
      () => AutomationFlowCatalogue.decode('{"flows":{}}', rootPath: '.'),
      throwsA(isA<AutomationRunnerException>()),
    );
  });
}

void _automationFlowCatalogue_should_rejectCatalogueWithoutFlows() {
  test('AutomationFlowCatalogue should reject catalogue without flows', () {
    expect(
      () => AutomationFlowCatalogue.decode('{"blocks":{}}', rootPath: '.'),
      throwsA(
        isA<AutomationRunnerException>().having(
          (error) => error.message,
          'message',
          'The flows of the runner catalogue is not a JSON object.',
        ),
      ),
    );
  });
}

void _automationFlowCatalogue_should_rejectTextThatIsNotJson() {
  test('AutomationFlowCatalogue should reject text that is not JSON', () {
    expect(
      () => AutomationFlowCatalogue.decode(
        'Resolving dependencies...',
        rootPath: '.',
      ),
      throwsA(isA<AutomationRunnerException>()),
    );
  });
}

void _automationFlowCatalogue_should_answerSeededRootWithoutRunningRunner() {
  test('AutomationFlowCatalogue should answer seeded root without running '
      'runner', () {
    final catalogue = AutomationFlowCatalogue(
      rootPath: '/seeded/root',
      flows: const {'login': <String, Object?>{}},
      blocks: const {},
    );

    AutomationFlowCatalogue.seed(catalogue);

    final read = AutomationFlowCatalogue.read(
      '/seeded/root',
      'tool/run_flows.dart',
    );

    expect(read, same(catalogue));
  });
}

void _automationFlowCatalogue_should_resolveEveryVariantWithProbeSeries() {
  test('AutomationFlowCatalogue should resolve every variant with probe '
      'series', () {
    final directory = Directory.systemTemp.createTempSync('catalogue-');

    try {
      File('${directory.path}/pubspec.yaml').writeAsStringSync(_pubspec);

      final catalogue = AutomationFlowCatalogue(
        rootPath: directory.path,
        flows: {
          'login': {
            'variants': {
              'ok': {
                'items': ['open'],
              },
              'refused': {
                'items': [_walkStep],
              },
            },
          },
          'motion': {
            'variants': {
              'main': {
                'items': [_probeStep],
              },
            },
          },
        },
        blocks: {
          'open': {
            'steps': [_walkStep],
          },
        },
      );

      expect(catalogue.resolveFlows().map((flow) => flow.id), [
        'login ok',
        'login refused',
        'motion main',
      ]);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}

void _automationFlowCatalogue_should_rejectFlowWithoutVariants() {
  test('AutomationFlowCatalogue should reject flow without variants', () {
    final directory = Directory.systemTemp.createTempSync('catalogue-');

    try {
      File('${directory.path}/pubspec.yaml').writeAsStringSync(_pubspec);

      final catalogue = AutomationFlowCatalogue(
        rootPath: directory.path,
        flows: {'login': <String, Object?>{}},
        blocks: const {},
      );

      expect(catalogue.resolveFlows, throwsA(isA<AutomationRunnerException>()));
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}

void _automationFlowCatalogue_should_ignoreLaterChangesOfCallerMaps() {
  test('AutomationFlowCatalogue should ignore later changes of caller '
      'maps', () {
    final flows = <String, Object?>{};
    final blocks = <String, Object?>{};
    final catalogue = AutomationFlowCatalogue(
      rootPath: '.',
      flows: flows,
      blocks: blocks,
    );

    flows['login'] = <String, Object?>{};
    blocks['open'] = <String, Object?>{};

    expect(catalogue.flows, isEmpty);
    expect(catalogue.blocks, isEmpty);
    expect(() => catalogue.flows['x'] = 1, throwsUnsupportedError);
  });
}

void _automationFlowCatalogue_should_giveDefaultLocaleOfProject() {
  test('AutomationFlowCatalogue should give default locale of project', () {
    _withProject(_pubspec, (directory) {
      final catalogue = AutomationFlowCatalogue(
        rootPath: directory.path,
        flows: const {},
        blocks: const {},
      );

      expect(catalogue.defaultLocale, 'uk');
    });
  });
}

void _automationFlowCatalogue_should_giveFindersOfProject() {
  test('AutomationFlowCatalogue should give finders of project', () {
    _withProject(_finderPubspec, (directory) {
      final catalogue = AutomationFlowCatalogue(
        rootPath: directory.path,
        flows: const {},
        blocks: const {},
      );
      final spec = catalogue.finders.resolve(
        {'by': 'calendarDay', 'dayOffset': 0},
        locale: 'uk',
        subject: 'Flow "login"',
      );

      expect(spec, isA<AutomationFinderSpec>());
    });
  });
}

void _automationFlowCatalogue_should_tellDefaultVariantOfFlow() {
  test('AutomationFlowCatalogue should tell default variant of flow', () {
    final catalogue = AutomationFlowCatalogue(
      rootPath: '.',
      flows: {
        'declared': {
          'defaultVariant': 'refused',
          'variants': {'ok': {}, 'refused': {}},
        },
        'single': {
          'variants': {'main': {}},
        },
        'undeclared': {
          'variants': {'ok': {}, 'refused': {}},
        },
      },
      blocks: const {},
    );

    expect(catalogue.isDefaultVariant('declared', 'refused'), isTrue);
    expect(catalogue.isDefaultVariant('declared', 'ok'), isFalse);
    expect(catalogue.isDefaultVariant('single', 'main'), isTrue);
    expect(catalogue.isDefaultVariant('undeclared', 'ok'), isFalse);
  });
}

void _withProject(String pubspec, void Function(Directory directory) body) {
  final directory = Directory.systemTemp.createTempSync('catalogue-');

  try {
    File('${directory.path}/pubspec.yaml').writeAsStringSync(pubspec);
    body(directory);
  } finally {
    directory.deleteSync(recursive: true);
  }
}
