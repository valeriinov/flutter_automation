import 'package:flutter_driver/flutter_driver.dart' show SerializableFinder;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_automation_runner/src/automation_block_library.dart';
import 'package:flutter_automation_runner/src/automation_finder_kind.dart';
import 'package:flutter_automation_runner/src/automation_flow.dart';
import 'package:flutter_automation_runner/src/automation_host_finders.dart';
import 'package:flutter_automation_runner/src/automation_launch_source.dart';
import 'package:flutter_automation_runner/src/automation_localized_text.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

const _flowName = 'checkout_basket';
const _variantName = 'orderFromExistingBasket';
const _openBlock = 'checkout_open_item_details';
const _itemFinder = {'by': 'text', 'value': '{{author}}'};
const _openItemLabel = 'open a found item';
const _locale = 'uk';
const _subject = 'Step "tap"';
const _openBasketLabel = 'open a free basket';
const _basketDateFinder = {
  'by': 'text',
  'value': {'uk': '11.03.2026 11:00', 'en': '03/11/2026 11:00'},
};
const _library = AutomationBlockLibrary(
  blocks: {
    _openBlock: AutomationBlock(
      name: _openBlock,
      params: {'author': 'Jane Smith'},
      steps: [
        {
          'action': 'tap',
          'label': _openItemLabel,
          'title': {
            'en': 'Open the item of {{author}}',
            'uk': 'Відкрити товар {{author}}',
          },
          'finder': _itemFinder,
        },
      ],
      title: _blockTitle,
    ),
  },
);
const _blockTitle = AutomationLocalizedText({
  'en': 'Open a found item',
  'uk': 'Відкрити знайдену товар',
});
const _title = {
  'en': 'Shopper checks out a basket',
  'uk': 'Покупець оформлює кошик',
};
const _subtitle = {
  'en': 'Found an item — checks out their own basket.',
  'uk': 'Знайшов товар — оформлює власний кошик.',
};
const _variantTitle = {
  'en': 'Checkout of an existing basket',
  'uk': 'Оформлення наявного кошика',
};
const _proves = {
  'en': 'The shopper picks an already published basket.',
  'uk': 'Покупець обирає вже опублікований кошик.',
};
const _mainVariantName = 'orderFromNewBasket';
const _entryTitle = {
  'en': 'Opened by a link to the item',
  'uk': 'Відкрито за посиланням на товар',
};
const _scrollDistance = -900;
const _probeDurationMs = 1000;
const _traceSettleMs = 1500;
const _basketDateTextFinder = {
  'by': 'dateText',
  'dayOffset': 1,
  'time': '11:00',
};
final _finders = AutomationFinderRegistry(
  dateFormats: {'uk': 'dd.MM.yyyy', 'en': 'MM/dd/yyyy'},
  dateValueKeys: {'calendarDay': 'item.day{yyyyMMdd}'},
);
final _dateTextToday = DateTime(2027, 3, 4, 12);
const _nonStringTime = 11;
const _feedProbe = {
  'name': 'feed',
  'finder': {'by': 'valueKey', 'value': 'feed'},
};

void main() {
  group('AutomationFlow Tests', () {
    _automationFlow_should_carryBlockAndTargetOnSteps();
    _automationFlow_should_readFlowAndVariantTexts();
    _automationFlow_should_describeEntriesOfUseList();
    _automationFlow_should_rejectMalformedProvesNamingVariant();
    _automationFlow_should_rejectFlowTitleWithBlankLanguage();
    _automationFlow_should_substituteBlockArgumentsInsideStepTitle();
    _automationFlow_should_readEntryAndStateOf();
    _automationFlow_should_leaveEntryAndStateOfAbsentWhenUnnamed();
    _automationFlow_should_rejectUnknownLaunchSource();
    _automationFlow_should_rejectEntryWithoutTitle();
    _automationFlow_should_rejectStateOfNamingNoOtherVariant();
  });
  group('AutomationStep Tests', () {
    _automationStep_should_reportBlockAndTarget();
    _automationStep_should_omitBlockAndTargetFromReportWhenAbsent();
    _automationStep_should_tellUserActionsFromWaitsAndHolds();
    _automationStep_should_readTitleOfInlineStep();
    _automationStep_should_leaveTitleOutOfReport();
    _automationStep_should_rejectMalformedTitleNamingStepAndBlock();
    _automationStep_should_rejectRepeatedProbeName();
    _automationStep_should_resolveTextAndTooltipToUnmarkedFinders();
    _automationStep_should_resolveLocaleKeyFindersByKey();
    _automationStep_should_keepStringFinderValueInEveryLocale();
    _automationStep_should_readPerLocaleFinderValueInRunLocale();
    _automationStep_should_rejectPerLocaleFinderValueWithoutRunLocale();
    _automationStep_should_resolveCalendarDayToTheKeyOfTheDate();
    _automationStep_should_rejectCalendarDayWithoutOffset();
    _automationStep_should_startATraceAtOnceWithoutADuration();
    _automationStep_should_readTheDurationATraceStartWaits();
    _automationStep_should_rejectATraceStopWithoutADuration();
    _automationStep_should_resolveDateTextToUnmarkedText();
    _automationStep_should_writeDateTextByThePatternOfTheLocale();
    _automationStep_should_rejectDateTextOfALocaleWithoutFormat();
    _automationStep_should_countCalendarDayFromTheAnchorOfItsKind();
    _automationStep_should_leaveTimeOutOfDateTextWhenUnnamed();
    _automationStep_should_rejectDateTextWithoutOffset();
    _automationStep_should_rejectDateTextWithNonStringTime();
  });
}

void _automationFlow_should_carryBlockAndTargetOnSteps() {
  test('AutomationFlow should carry block and target on steps', () {
    final flow = _readFlow(
      use: [
        {
          'block': _openBlock,
          'with': {'author': 'John Doe'},
        },
        {'action': 'enterText', 'text': 'Київ'},
      ],
    );

    expect(flow.steps.map((step) => step.block).toList(), [_openBlock, null]);
    expect(flow.steps.map((step) => step.target).toList(), [
      {'by': 'text', 'value': 'John Doe'},
      null,
    ]);
  });
}

void _automationFlow_should_readFlowAndVariantTexts() {
  test('AutomationFlow should read flow and variant texts', () {
    final flow = _readFlow(
      use: [_openBlock],
      flowFields: {'title': _title, 'subtitle': _subtitle},
      variantFields: {'title': _variantTitle, 'proves': _proves},
    );

    expect(flow.title?.read('en'), _title['en']);
    expect(flow.title?.read('uk'), _title['uk']);
    expect(flow.subtitle?.read('en'), _subtitle['en']);
    expect(flow.subtitle?.read('uk'), _subtitle['uk']);
    expect(flow.variantTitle?.read('en'), _variantTitle['en']);
    expect(flow.variantTitle?.read('uk'), _variantTitle['uk']);
    expect(flow.proves?.read('en'), _proves['en']);
    expect(flow.proves?.read('uk'), _proves['uk']);
  });
}

void _automationFlow_should_describeEntriesOfUseList() {
  test('AutomationFlow should describe entries of use list', () {
    final flow = _readFlow(
      use: [
        {
          'block': _openBlock,
          'with': {'author': 'John Doe'},
        },
        {
          'action': 'enterText',
          'text': 'Київ',
          'title': {'en': 'Type the address', 'uk': 'Ввести адресу'},
        },
      ],
    );

    expect(
      flow.entries.first,
      isA<AutomationBlockEntry>()
          .having((entry) => entry.name, 'name', _openBlock)
          .having((entry) => entry.stepCount, 'stepCount', 1)
          .having((entry) => entry.arguments, 'arguments', {
            'author': 'John Doe',
          })
          .having(
            (entry) => entry.title?.read('en'),
            'title',
            _blockTitle.read('en'),
          ),
    );
    expect(
      flow.entries.last,
      isA<AutomationStepEntry>()
          .having((entry) => entry.action, 'action', 'enterText')
          .having((entry) => entry.title?.read('uk'), 'title', 'Ввести адресу'),
    );
  });
}

void _automationFlow_should_rejectMalformedProvesNamingVariant() {
  test('AutomationFlow should reject malformed proves naming variant', () {
    expect(
      () => _readFlow(
        use: [_openBlock],
        variantFields: {'proves': 'The shopper picks a basket.'},
      ),
      _throwsRunnerException(
        'Variant "$_variantName" of "$_flowName" has a malformed "proves"',
      ),
    );
  });
}

void _automationFlow_should_rejectFlowTitleWithBlankLanguage() {
  test('AutomationFlow should reject flow title with blank language', () {
    expect(
      () => _readFlow(
        use: [_openBlock],
        flowFields: {
          'title': {'en': 'Shopper checks out a basket', 'uk': ' '},
        },
      ),
      _throwsRunnerException('Flow "$_flowName" has a malformed "title"'),
    );
  });
}

void _automationFlow_should_substituteBlockArgumentsInsideStepTitle() {
  test(
    'AutomationFlow should substitute block arguments inside step title',
    () {
      final flow = _readFlow(
        use: [
          {
            'block': _openBlock,
            'with': {'author': 'John Doe'},
          },
        ],
      );
      final title = flow.steps.first.title;

      expect(title?.read('en'), 'Open the item of John Doe');
      expect(title?.read('uk'), 'Відкрити товар John Doe');
    },
  );
}

void _automationStep_should_reportBlockAndTarget() {
  test('AutomationStep should report block and target', () {
    final step = _readFlow(use: [_openBlock]).steps.first;
    final report = step.toReport();

    expect(report, {
      'action': 'tap',
      'label': _openItemLabel,
      'block': _openBlock,
      'target': {'by': 'text', 'value': 'Jane Smith'},
      'timeoutMs': 10000,
    });
  });
}

void _automationStep_should_omitBlockAndTargetFromReportWhenAbsent() {
  test(
    'AutomationStep should omit block and target from report when absent',
    () {
      final step = AutomationStep.fromJson(
        {'action': 'enterText', 'text': 'Київ'},
        block: null,
        finders: _finders,
        locale: _locale,
      );
      final report = step.toReport();

      expect(report.containsKey('block'), isFalse);
      expect(report.containsKey('target'), isFalse);
    },
  );
}

void _automationStep_should_tellUserActionsFromWaitsAndHolds() {
  test('AutomationStep should tell user actions from waits and holds', () {
    const feed = {'by': 'valueKey', 'value': 'order_flow.screen.order'};
    final userActions = [
      {'action': 'tap', 'finder': feed},
      {'action': 'enterText', 'text': '650'},
      {'action': 'scroll', 'finder': feed, 'dx': 0, 'dy': _scrollDistance},
    ];
    final otherSteps = [
      {'action': 'waitFor', 'finder': feed},
      {'action': 'scrollIntoView', 'finder': feed},
      {'action': 'scroll', 'finder': feed, 'dx': 0, 'dy': 0},
      {'action': 'probeCenter', 'finder': feed},
    ];
    final userActionFlags = userActions.map(_readIsUserAction);
    final otherStepFlags = otherSteps.map(_readIsUserAction);

    expect(userActionFlags, everyElement(isTrue));
    expect(otherStepFlags, everyElement(isFalse));
  });
}

void _automationStep_should_readTitleOfInlineStep() {
  test('AutomationStep should read title of inline step', () {
    final step = AutomationStep.fromJson(
      {
        'action': 'enterText',
        'text': '650',
        'title': {'en': 'Type the amount 650', 'uk': 'Ввести суму 650'},
      },
      block: null,
      finders: _finders,
      locale: _locale,
    );

    expect(step.title?.read('en'), 'Type the amount 650');
    expect(step.title?.read('uk'), 'Ввести суму 650');
  });
}

void _automationStep_should_leaveTitleOutOfReport() {
  test('AutomationStep should leave title out of report', () {
    final step = _readFlow(use: [_openBlock]).steps.first;
    final report = step.toReport();

    expect(step.title, isNotNull);
    expect(report.containsKey('title'), isFalse);
  });
}

void _automationStep_should_rejectMalformedTitleNamingStepAndBlock() {
  test(
    'AutomationStep should reject malformed title naming step and block',
    () {
      expect(
        () => AutomationStep.fromJson(
          {
            'action': 'tap',
            'label': _openItemLabel,
            'title': 'Open the item',
            'finder': _itemFinder,
          },
          block: _openBlock,
          finders: _finders,
          locale: _locale,
        ),
        _throwsRunnerException(
          'Step "$_openItemLabel" of block "$_openBlock" has a malformed '
          '"title"',
        ),
      );
    },
  );
}

void _automationStep_should_rejectRepeatedProbeName() {
  test('AutomationStep should reject repeated probe name', () {
    expect(
      () => AutomationStep.fromJson(
        {
          'action': 'probeSeries',
          'durationMs': _probeDurationMs,
          'probes': [_feedProbe, _feedProbe],
        },
        block: null,
        finders: _finders,
        locale: _locale,
      ),
      _throwsRunnerException('repeats probe "feed"'),
    );
  });
}

void _automationStep_should_resolveTextAndTooltipToUnmarkedFinders() {
  test(
    'AutomationStep should resolve text and tooltip to unmarked finders',
    () {
      final text = _resolveFinder(
        {'by': 'text', 'value': 'Київ'},
        locale: _locale,
        subject: _subject,
      );
      final tooltip = _resolveFinder(
        {'by': 'tooltip', 'value': 'Назад'},
        locale: _locale,
        subject: _subject,
      );

      expect(text.serialize(), {'finderType': 'UnmarkedText', 'text': 'Київ'});
      expect(tooltip.serialize(), {
        'finderType': 'UnmarkedTooltip',
        'text': 'Назад',
      });
    },
  );
}

void _automationStep_should_resolveLocaleKeyFindersByKey() {
  test('AutomationStep should resolve locale key finders by key', () {
    final text = _resolveFinder(
      {'by': 'localeKey', 'value': 'profileMenuLogout'},
      locale: _locale,
      subject: _subject,
    );
    final tooltip = _resolveFinder(
      {'by': 'localeKeyTooltip', 'value': 'backLabel'},
      locale: _locale,
      subject: _subject,
    );

    expect(text.serialize(), {
      'finderType': 'LocaleKeyText',
      'key': 'profileMenuLogout',
    });
    expect(tooltip.serialize(), {
      'finderType': 'LocaleKeyTooltip',
      'key': 'backLabel',
    });
  });
}

void _automationStep_should_keepStringFinderValueInEveryLocale() {
  test('AutomationStep should keep string finder value in every locale', () {
    final step = AutomationStep.fromJson(
      {
        'action': 'tap',
        'finder': {'by': 'text', 'value': 'Київ'},
      },
      block: null,
      finders: _finders,
      locale: 'en',
    );

    expect(step.finder?.serialize(), {
      'finderType': 'UnmarkedText',
      'text': 'Київ',
    });
  });
}

void _automationStep_should_readPerLocaleFinderValueInRunLocale() {
  test('AutomationStep should read per locale finder value in run locale', () {
    final ukStep = _readBasketDateStep('uk');
    final enStep = _readBasketDateStep('en');

    expect(ukStep.finder?.serialize(), {
      'finderType': 'UnmarkedText',
      'text': '11.03.2026 11:00',
    });
    expect(enStep.finder?.serialize(), {
      'finderType': 'UnmarkedText',
      'text': '03/11/2026 11:00',
    });
    expect(enStep.target, _basketDateFinder);
  });
}

void _automationStep_should_rejectPerLocaleFinderValueWithoutRunLocale() {
  test(
    'AutomationStep should reject per locale finder value without run locale',
    () {
      expect(
        () => _readBasketDateStep('de'),
        _throwsRunnerException(
          'Step "$_openBasketLabel" has no "de" finder value. '
          'It holds [uk, en]',
        ),
      );
    },
  );
}

void _automationFlow_should_readEntryAndStateOf() {
  test('AutomationFlow should read entry and stateOf', () {
    final flow = _readFlow(
      use: [_openBlock],
      variantFields: {
        'entry': {'title': _entryTitle, 'launchedBy': 'link'},
        'stateOf': _mainVariantName,
      },
    );

    expect(flow.entry?.title.read('uk'), _entryTitle['uk']);
    expect(flow.entry?.launchedBy, AutomationLaunchSource.link);
    expect(flow.stateOf, _mainVariantName);
    expect(flow.entry?.toJson(), {'title': _entryTitle, 'launchedBy': 'link'});
  });
}

void _automationFlow_should_leaveEntryAndStateOfAbsentWhenUnnamed() {
  test('AutomationFlow should leave entry and stateOf absent when unnamed', () {
    final flow = _readFlow(
      use: [_openBlock],
      variantFields: {
        'entry': {'title': _entryTitle},
      },
    );

    expect(flow.entry?.launchedBy, isNull);
    expect(flow.entry?.toJson(), {'title': _entryTitle});
    expect(flow.stateOf, isNull);
  });
}

void _automationFlow_should_rejectUnknownLaunchSource() {
  test('AutomationFlow should reject unknown launch source', () {
    expect(
      () => _readFlow(
        use: [_openBlock],
        variantFields: {
          'entry': {'title': _entryTitle, 'launchedBy': 'email'},
        },
      ),
      _throwsRunnerException('has an unknown "launchedBy" "email"'),
    );
  });
}

void _automationFlow_should_rejectEntryWithoutTitle() {
  test('AutomationFlow should reject entry without title', () {
    expect(
      () => _readFlow(
        use: [_openBlock],
        variantFields: {
          'entry': {'launchedBy': 'push'},
        },
      ),
      _throwsRunnerException('has an "entry" without a "title"'),
    );
  });
}

void _automationFlow_should_rejectStateOfNamingNoOtherVariant() {
  test('AutomationFlow should reject stateOf naming no other variant', () {
    expect(
      () => _readFlow(
        use: [_openBlock],
        variantFields: {'stateOf': _variantName},
      ),
      _throwsRunnerException('has a "stateOf" "$_variantName" naming no other'),
    );
  });
}

void _automationStep_should_resolveCalendarDayToTheKeyOfTheDate() {
  test('AutomationStep should resolve calendar day to the key of the date', () {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day + 3);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final finder = _resolveFinder(
      {'by': 'calendarDay', 'dayOffset': 3},
      locale: _locale,
      subject: _subject,
    );

    expect(finder.serialize(), {
      'finderType': 'ByValueKey',
      'keyValueString': 'item.day${date.year}$month$day',
      'keyValueType': 'String',
    });
  });
}

void _automationStep_should_rejectCalendarDayWithoutOffset() {
  test('AutomationStep should reject calendar day without offset', () {
    expect(
      () => _resolveFinder(
        {'by': 'calendarDay'},
        locale: _locale,
        subject: _subject,
      ),
      _throwsRunnerException('takes an int "dayOffset"'),
    );
  });
}

void _automationStep_should_startATraceAtOnceWithoutADuration() {
  test('AutomationStep should start a trace at once without a duration', () {
    final step = AutomationStep.fromJson(
      {'action': 'traceStart'},
      block: null,
      finders: _finders,
      locale: _locale,
    );

    expect(step.duration, Duration.zero);
  });
}

void _automationStep_should_readTheDurationATraceStartWaits() {
  test('AutomationStep should read the duration a trace start waits', () {
    final step = AutomationStep.fromJson(
      {'action': 'traceStart', 'durationMs': _traceSettleMs},
      block: null,
      finders: _finders,
      locale: _locale,
    );

    expect(step.duration, const Duration(milliseconds: _traceSettleMs));
  });
}

void _automationStep_should_rejectATraceStopWithoutADuration() {
  test('AutomationStep should reject a trace stop without a duration', () {
    expect(
      () => AutomationStep.fromJson(
        {'action': 'traceStop'},
        block: null,
        finders: _finders,
        locale: _locale,
      ),
      _throwsRunnerException('A "traceStop" step needs a "durationMs"'),
    );
  });
}

void _automationStep_should_resolveDateTextToUnmarkedText() {
  test('AutomationStep should resolve date text to unmarked text', () {
    final finder = _resolveFinder(
      _basketDateTextFinder,
      locale: _locale,
      subject: _subject,
      anchor: _dateTextToday,
    );

    expect(finder.serialize(), {
      'finderType': 'UnmarkedText',
      'text': '05.03.2027 11:00',
    });
  });
}

void _automationStep_should_writeDateTextByThePatternOfTheLocale() {
  test(
    'AutomationStep should write date text by the pattern of the locale',
    () {
      final texts = {
        for (final locale in ['uk', 'en'])
          locale: _resolveFinder(
            _basketDateTextFinder,
            locale: locale,
            subject: _subject,
            anchor: _dateTextToday,
          ).serialize()['text'],
      };

      expect(texts, {'uk': '05.03.2027 11:00', 'en': '03/05/2027 11:00'});
    },
  );
}

void _automationStep_should_leaveTimeOutOfDateTextWhenUnnamed() {
  test('AutomationStep should leave time out of date text when unnamed', () {
    final finder = _resolveFinder(
      {'by': 'dateText', 'dayOffset': 1},
      locale: 'en',
      subject: _subject,
      anchor: _dateTextToday,
    );

    expect(finder.serialize()['text'], '03/05/2027');
  });
}

void _automationStep_should_rejectDateTextOfALocaleWithoutFormat() {
  test('AutomationStep should reject date text of a locale without format', () {
    expect(
      () => _resolveFinder(
        _basketDateTextFinder,
        locale: 'de',
        subject: _subject,
      ),
      _throwsRunnerException('"dateFormats" entry for the locale "de"'),
    );
  });
}

void _automationStep_should_countCalendarDayFromTheAnchorOfItsKind() {
  test(
    'AutomationStep should count calendar day from the anchor of its kind',
    () {
      final finder = _resolveFinder(
        {'by': 'calendarDay', 'dayOffset': 1},
        locale: _locale,
        subject: _subject,
        anchor: _dateTextToday,
      );

      expect(finder.serialize()['keyValueString'], 'item.day20270305');
    },
  );
}

void _automationStep_should_rejectDateTextWithoutOffset() {
  test('AutomationStep should reject date text without offset', () {
    expect(
      () => _resolveFinder(
        {'by': 'dateText', 'time': '11:00'},
        locale: _locale,
        subject: _subject,
      ),
      _throwsRunnerException('takes an int "dayOffset"'),
    );
  });
}

void _automationStep_should_rejectDateTextWithNonStringTime() {
  test('AutomationStep should reject date text with non-string time', () {
    expect(
      () => _resolveFinder(
        {'by': 'dateText', 'dayOffset': 1, 'time': _nonStringTime},
        locale: _locale,
        subject: _subject,
      ),
      _throwsRunnerException('takes a string "time"'),
    );
  });
}

AutomationFlow _readFlow({
  required List<Object?> use,
  Map<String, Object?> flowFields = const {},
  Map<String, Object?> variantFields = const {},
}) {
  return AutomationFlow.fromJson(
    name: _flowName,
    variant: _variantName,
    json: {
      ...flowFields,
      'defaultVariant': _variantName,
      'variants': {
        _variantName: {...variantFields, 'use': use},
        _mainVariantName: {
          'use': [_openBlock],
        },
      },
    },
    blocks: _library,
    finders: _finders,
    locale: _locale,
  );
}

AutomationStep _readBasketDateStep(String locale) {
  return AutomationStep.fromJson(
    {'action': 'tap', 'label': _openBasketLabel, 'finder': _basketDateFinder},
    block: null,
    finders: _finders,
    locale: locale,
  );
}

Matcher _throwsRunnerException(String message) {
  return throwsA(
    isA<AutomationRunnerException>().having(
      (error) => error.message,
      'message',
      contains(message),
    ),
  );
}

bool _readIsUserAction(Map<String, Object?> json) {
  return AutomationStep.fromJson(
    json,
    block: null,
    finders: _finders,
    locale: _locale,
  ).isUserAction;
}

SerializableFinder _resolveFinder(
  Object? json, {
  required String locale,
  required String subject,
  DateTime? anchor,
}) {
  final spec = _finders.resolve(
    json,
    locale: locale,
    subject: subject,
    anchorOf: (_) => anchor ?? DateTime.now(),
  );

  return AutomationHostFinders.build(spec);
}
