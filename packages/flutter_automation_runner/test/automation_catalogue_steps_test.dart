import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_mock/mock_section.dart';
import 'package:flutter_automation_runner/automation_flow_definition.dart';
import 'package:flutter_automation_runner/automation_recording.dart';

const _signInFinder = {'by': 'valueKey', 'value': 'login.sign_in'};
const _signUpFinder = {'by': 'valueKey', 'value': 'login.sign_up'};
const _launchSection = 'launch';
const _flowName = 'login';

final _launch = MockSection<Map<String, Object?>>(
  name: _launchSection,
  title: const AutomationLocalizedText({'en': 'Launch'}),
  fromJson: (json) => json,
  restartKeys: {'isSignedIn'},
);
final _flow = AutomationFlowDefinition(
  name: _flowName,
  isInQaCatalogue: true,
  variants: [
    FlowVariant(
      'signedIn',
      title: const AutomationLocalizedText({'en': 'Signed in'}),
      items: const [WaitFor(ByText('Hello'))],
      scenario: [
        _launch.override((settings) => {...settings, 'isSignedIn': true}),
      ],
    ),
    FlowVariant(
      'signedOut',
      title: const AutomationLocalizedText({'en': 'Signed out'}),
      items: const [WaitFor(ByText('Hello'))],
    ),
  ],
);

AutomationRecording _recording(String variant, Map<String, Object?> second) {
  return AutomationRecording.fromReport({
    'flow': _flowName,
    'variant': variant,
    'ok': true,
    'steps': [
      {
        'label': 'wait',
        'action': 'waitFor',
        'ok': true,
        'step': {'action': 'waitFor', 'finder': _signInFinder},
      },
      {'label': 'next', 'ok': true, ...second},
    ],
  });
}

Map<String, Object?> _tap(Map<String, Object?> finder) {
  return {
    'action': 'tap',
    'step': {
      'action': 'tap',
      'label': 'next',
      'title': {'en': 'Press it'},
      'timeoutMs': 5000,
      'finder': finder,
    },
  };
}

AutomationCatalogue _build({List<MockSection<Object?>> sections = const []}) {
  return AutomationCatalogueBuilder(
    flows: {_flowName: _flow.toJson()},
    recordings: [
      _recording('signedIn', _tap(_signInFinder)),
      _recording('signedOut', _tap(_signUpFinder)),
    ],
    sections: sections,
  ).build();
}

void main() {
  group('AutomationCatalogueBuilder Player Tests', () {
    _builder_should_carryTheFinderAndTheTitleOfAStep();
    _builder_should_standTheForkAtTheFirstPartingStep();
    _builder_should_labelABranchByTheTitleOfItsVariant();
    _builder_should_chooseBeforeStartTheBranchThatChangesARestartKey();
    _builder_should_standTheForkAtTheEarlierOfStepAndRequest();
    _builder_should_keepTheRequestForkForVariantsOfOtherLengthWithoutSteps();
    _builder_should_carryTheDragOfAScrollStep();
    _builder_should_carryTheDateSettingsOfTheProject();
  });
}

void _builder_should_carryTheFinderAndTheTitleOfAStep() {
  test('AutomationCatalogueBuilder should carry the finder and the title', () {
    final step = _build().flows.single.variants.first.steps[1];

    expect(step.action, 'tap');
    expect(step.finder, _signInFinder);
    expect(step.title, {'en': 'Press it'});
    expect(step.timeoutMs, 5000);
  });
}

void _builder_should_standTheForkAtTheFirstPartingStep() {
  test('AutomationCatalogueBuilder should stand the fork at the parting', () {
    final fork = _build().flows.single.fork;

    expect(fork?.stepIndex, 1);
    expect(fork?.path, isNull);
  });
}

void _builder_should_labelABranchByTheTitleOfItsVariant() {
  test('AutomationCatalogueBuilder should label a branch by the title', () {
    final fork = _build().flows.single.fork;

    expect(fork?.branches.map((branch) => branch.label), [
      'Signed in',
      'Signed out',
    ]);
  });
}

void _builder_should_chooseBeforeStartTheBranchThatChangesARestartKey() {
  test(
    'AutomationCatalogueBuilder should mark a branch that needs restart',
    () {
      final withSection = _build(sections: [_launch]);
      final without = _build();

      expect(
        withSection.flows.single.fork?.branches.map(
          (branch) => branch.isChosenBeforeStart,
        ),
        [true, true],
      );
      expect(
        without.flows.single.fork?.branches.map(
          (branch) => branch.isChosenBeforeStart,
        ),
        [false, false],
      );
    },
  );
}

AutomationRecording _fourStepRecording(
  String variant, {
  required String thirdStep,
}) {
  return AutomationRecording.fromReport({
    'flow': _flowName,
    'variant': variant,
    'ok': true,
    'steps': [
      for (int index = 0; index < 4; index += 1)
        {
          'label': 'step $index',
          'action': 'tap',
          'ok': true,
          'step': {
            'action': 'tap',
            'finder': {
              'by': 'valueKey',
              'value': index == 3 ? thirdStep : 'same.$index',
            },
          },
          'journal': [
            if (index == 1)
              {
                'method': 'GET',
                'path': '/items',
                'status': variant == 'signedIn' ? 200 : 500,
              },
          ],
        },
    ],
  });
}

void _builder_should_standTheForkAtTheEarlierOfStepAndRequest() {
  test('AutomationCatalogueBuilder should stand the fork at the earlier', () {
    final catalogue = AutomationCatalogueBuilder(
      flows: {_flowName: _flow.toJson()},
      recordings: [
        _fourStepRecording('signedIn', thirdStep: 'a'),
        _fourStepRecording('signedOut', thirdStep: 'b'),
      ],
    ).build();
    final fork = catalogue.flows.single.fork;

    expect(fork?.stepIndex, 1);
    expect(fork?.path, '/items');
  });
}

void _builder_should_keepTheRequestForkForVariantsOfOtherLengthWithoutSteps() {
  test('AutomationCatalogueBuilder should keep the request fork', () {
    AutomationRecording recording(String variant, int length) {
      return AutomationRecording.fromReport({
        'flow': _flowName,
        'variant': variant,
        'ok': true,
        'steps': [
          for (int index = 0; index < length; index += 1)
            {
              'label': 'step $index',
              'action': 'tap',
              'ok': true,
              'journal': [
                if (index == 0)
                  {
                    'method': 'GET',
                    'path': '/items',
                    'status': variant == 'signedIn' ? 200 : 500,
                  },
              ],
            },
        ],
      });
    }

    final fork = AutomationCatalogueBuilder(
      flows: {_flowName: _flow.toJson()},
      recordings: [recording('signedIn', 2), recording('signedOut', 4)],
    ).build().flows.single.fork;

    expect(fork?.stepIndex, 0);
    expect(fork?.path, '/items');
  });
}

void _builder_should_carryTheDragOfAScrollStep() {
  test('AutomationCatalogueBuilder should carry the drag of a scroll', () {
    final recording = AutomationRecording.fromReport({
      'flow': _flowName,
      'variant': 'signedIn',
      'ok': true,
      'steps': [
        {
          'label': 'scroll',
          'action': 'scroll',
          'ok': true,
          'step': {
            'action': 'scroll',
            'dx': 0.0,
            'dy': -300.0,
            'durationMs': 6000,
            'frequency': 60,
            'finder': _signInFinder,
          },
        },
      ],
    });
    final step = AutomationCatalogueBuilder(
      flows: {_flowName: _flow.toJson()},
      recordings: [recording],
    ).build().flows.single.variants.first.steps.single;

    expect(step.dy, -300);
    expect(step.durationMs, 6000);
    expect(step.frequency, 60);
  });
}

void _builder_should_carryTheDateSettingsOfTheProject() {
  test('AutomationCatalogueBuilder should carry the date settings', () {
    final catalogue = AutomationCatalogueBuilder(
      flows: {_flowName: _flow.toJson()},
      recordings: const [],
      dateFormats: const {'en': 'MM/dd/yyyy'},
      dateValueKeys: const {'calendarDay': 'day.{yyyyMMdd}'},
    ).build();
    final read = AutomationCatalogue.fromJson(catalogue.toJson());

    expect(read.dateFormats, {'en': 'MM/dd/yyyy'});
    expect(read.dateValueKeys, {'calendarDay': 'day.{yyyyMMdd}'});
  });
}
