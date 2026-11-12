import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_finder_kind.dart';
import 'package:flutter_automation_runner/src/automation_frame_summary.dart';
import 'package:flutter_automation_runner/src/automation_runner_config.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

const _fullPubspec = '''
name: sample_app
flutter_automation:
  defaultLocale: uk
  dateFormats:
    uk: dd.MM.yyyy
    en: MM/dd/yyyy
  frameBudgetMs: 8
  splashScreen: splash
  launchHint: --dart-define=MODE=full
  finders:
    calendarDay:
      kind: dateValueKey
      template: item.day{yyyyMMdd}
''';
const _barePubspec = 'name: sample_app\n';
const _unknownKindPubspec = '''
name: sample_app
flutter_automation:
  finders:
    calendarDay:
      kind: unknown
''';
const _wrongTypePubspecs = {
  'frameBudgetMs': 'frameBudgetMs: 16.5',
  'dateFormats': 'dateFormats: {uk: 5}',
  'finders': 'finders: [calendarDay]',
};
const _builtInNamePubspec = '''
name: sample_app
flutter_automation:
  finders:
    text:
      kind: dateValueKey
      template: item.day{yyyyMMdd}
''';

void main() {
  group('AutomationRunnerConfig Tests', () {
    _automationRunnerConfig_should_readSectionOfPubspec();
    _automationRunnerConfig_should_fallBackToDefaultsWithoutSection();
    _automationRunnerConfig_should_rejectFinderOfUnknownKind();
    _automationRunnerConfig_should_rejectPubspecWithoutName();
    _automationRunnerConfig_should_rejectKeyOfWrongTypeNamingIt();
    _automationRunnerConfig_should_rejectSectionThatIsNotMapNamingIt();
    _automationRunnerConfig_should_rejectFinderNamedLikeBuiltInKind();
    _automationRunnerConfig_should_takeFrameGoalOfFrameSummaryByDefault();
  });
}

void _automationRunnerConfig_should_readSectionOfPubspec() {
  test('AutomationRunnerConfig should read section of pubspec', () {
    final config = AutomationRunnerConfig.fromPubspec(_fullPubspec);

    expect(config.packagePrefix, 'package:sample_app/');
    expect(config.defaultLocale, 'uk');
    expect(config.dateFormats, {'uk': 'dd.MM.yyyy', 'en': 'MM/dd/yyyy'});
    expect(config.frameBudgetMs, 8);
    expect(config.splashScreen, 'splash');
    expect(config.launchHint, '--dart-define=MODE=full');
    expect(config.dateValueKeys, {'calendarDay': 'item.day{yyyyMMdd}'});
  });
}

void _automationRunnerConfig_should_fallBackToDefaultsWithoutSection() {
  test(
    'AutomationRunnerConfig should fall back to defaults without section',
    () {
      final config = AutomationRunnerConfig.fromPubspec(_barePubspec);

      expect(config.defaultLocale, 'en');
      expect(config.frameBudgetMs, 16);
      expect(config.splashScreen, isNull);
      expect(config.launchHint, isNull);
      expect(config.dateFormats, isEmpty);
      expect(config.dateValueKeys, isEmpty);
    },
  );
}

void _automationRunnerConfig_should_rejectFinderOfUnknownKind() {
  test('AutomationRunnerConfig should reject finder of unknown kind', () {
    expect(
      () => AutomationRunnerConfig.fromPubspec(_unknownKindPubspec),
      throwsA(isA<AutomationRunnerException>()),
    );
  });
}

void _automationRunnerConfig_should_rejectPubspecWithoutName() {
  test('AutomationRunnerConfig should reject pubspec without name', () {
    expect(
      () => AutomationRunnerConfig.fromPubspec('flutter_automation: {}'),
      throwsA(isA<AutomationRunnerException>()),
    );
  });
}

void _automationRunnerConfig_should_rejectKeyOfWrongTypeNamingIt() {
  test('AutomationRunnerConfig should reject key of wrong type naming it', () {
    for (final MapEntry(:key, :value) in _wrongTypePubspecs.entries) {
      expect(
        () => AutomationRunnerConfig.fromPubspec(
          'name: sample_app\nflutter_automation:\n  $value\n',
        ),
        throwsA(
          isA<AutomationRunnerException>().having(
            (error) => error.message,
            'message',
            contains('"$key"'),
          ),
        ),
      );
    }
  });
}

void _automationRunnerConfig_should_rejectSectionThatIsNotMapNamingIt() {
  test(
    'AutomationRunnerConfig should reject section that is not map naming it',
    () {
      expect(
        () => AutomationRunnerConfig.fromPubspec(
          'name: sample_app\nflutter_automation: [flows]\n',
        ),
        throwsA(
          isA<AutomationRunnerException>().having(
            (error) => error.message,
            'message',
            contains('flutter_automation section'),
          ),
        ),
      );
    },
  );
}

void _automationRunnerConfig_should_rejectFinderNamedLikeBuiltInKind() {
  test(
    'AutomationRunnerConfig should reject finder named like built-in kind',
    () {
      final config = AutomationRunnerConfig.fromPubspec(_builtInNamePubspec);

      expect(
        () => config.finderRegistry,
        throwsA(
          isA<AutomationRunnerException>().having(
            (error) => error.message,
            'message',
            contains('"text"'),
          ),
        ),
      );
      expect(AutomationFinderRegistry.new, returnsNormally);
    },
  );
}

void _automationRunnerConfig_should_takeFrameGoalOfFrameSummaryByDefault() {
  test(
    'AutomationRunnerConfig should take frame goal of frame summary by default',
    () {
      final config = AutomationRunnerConfig.fromPubspec(_barePubspec);

      expect(config.frameBudgetMs, AutomationFrameSummary.defaultGoalMillis);
    },
  );
}
