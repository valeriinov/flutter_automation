import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_block_library.dart';
import 'package:flutter_automation_runner/src/automation_localized_text.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

const _feedBlock = 'order_feed_excursion';
const _decideBlock = 'order_decide';
const _decisionButton = 'order_flow.button.{{decision}}';
const _feedFinder = {'by': 'valueKey', 'value': 'order_flow.screen.order'};
const _feedSteps = [
  {'action': 'waitFor', 'finder': _feedFinder},
];
const _decideSteps = [
  {
    'action': 'waitForTappable',
    'finder': {'by': 'valueKey', 'value': _decisionButton},
  },
  {
    'action': 'tap',
    'finder': {'by': 'valueKey', 'value': _decisionButton},
  },
];
const _decideTitle = AutomationLocalizedText({
  'en': 'Decide on the coupon amount',
  'uk': 'Вирішити щодо суми купона',
});
const _library = AutomationBlockLibrary(
  blocks: {
    _feedBlock: AutomationBlock(
      name: _feedBlock,
      params: {},
      steps: _feedSteps,
      title: null,
    ),
    _decideBlock: AutomationBlock(
      name: _decideBlock,
      params: {'decision': 'accept'},
      steps: _decideSteps,
      title: _decideTitle,
    ),
  },
);

void main() {
  group('AutomationBlockLibrary Tests', () {
    _automationBlockLibrary_should_pairStepsWithDeclaringBlock();
    _automationBlockLibrary_should_substituteArgumentsInsideFinder();
    _automationBlockLibrary_should_describeBlockWithTitleAndArguments();
    _automationBlockLibrary_should_describeInlineStepWithItsAction();
  });
  group('AutomationBlock Tests', () {
    _automationBlock_should_readTitle();
    _automationBlock_should_rejectMalformedTitleNamingBlock();
  });
}

void _automationBlockLibrary_should_pairStepsWithDeclaringBlock() {
  test('AutomationBlockLibrary should pair steps with declaring block', () {
    final inlineStep = {'action': 'tap', 'finder': _feedFinder};
    final expanded = _library.expand([_feedBlock, _decideBlock, inlineStep]);

    expect(expanded.map((entry) => entry.block).toList(), [
      _feedBlock,
      _decideBlock,
      _decideBlock,
      null,
    ]);
    expect(expanded.last.step, inlineStep);
  });
}

void _automationBlockLibrary_should_substituteArgumentsInsideFinder() {
  test('AutomationBlockLibrary should substitute arguments inside finder', () {
    final expanded = _library.expand([
      {
        'block': _decideBlock,
        'with': {'decision': 'decline'},
      },
    ]);

    expect(expanded.map((entry) => entry.step).toList(), [
      {
        'action': 'waitForTappable',
        'finder': {'by': 'valueKey', 'value': 'order_flow.button.decline'},
      },
      {
        'action': 'tap',
        'finder': {'by': 'valueKey', 'value': 'order_flow.button.decline'},
      },
    ]);
  });
}

void _automationBlockLibrary_should_describeBlockWithTitleAndArguments() {
  test(
    'AutomationBlockLibrary should describe block with title and arguments',
    () {
      final described = _library.describe([
        _feedBlock,
        {
          'block': _decideBlock,
          'with': {'decision': 'decline'},
        },
      ]);

      expect(described, [
        _isBlockEntry(_feedBlock, 1, const {}, null),
        _isBlockEntry(_decideBlock, 2, const {
          'decision': 'decline',
        }, _decideTitle.read('en')),
      ]);
    },
  );
}

void _automationBlockLibrary_should_describeInlineStepWithItsAction() {
  test(
    'AutomationBlockLibrary should describe inline step with its action',
    () {
      final described = _library.describe([
        {
          'action': 'enterText',
          'text': '650',
          'title': {'en': 'Type the amount 650', 'uk': 'Ввести суму 650'},
        },
      ]);

      expect(
        described.single,
        isA<AutomationStepItem>()
            .having((entry) => entry.action, 'action', 'enterText')
            .having(
              (entry) => entry.title?.read('uk'),
              'title',
              'Ввести суму 650',
            ),
      );
    },
  );
}

void _automationBlock_should_readTitle() {
  test('AutomationBlock should read title', () {
    final block = AutomationBlock.fromJson(_decideBlock, {
      'steps': _decideSteps,
      'title': {'en': _decideTitle.read('en'), 'uk': _decideTitle.read('uk')},
    });

    expect(block.title?.read('en'), _decideTitle.read('en'));
    expect(block.title?.read('uk'), _decideTitle.read('uk'));
  });
}

void _automationBlock_should_rejectMalformedTitleNamingBlock() {
  test('AutomationBlock should reject malformed title naming block', () {
    expect(
      () => AutomationBlock.fromJson(_decideBlock, {
        'steps': _decideSteps,
        'title': _decideTitle.read('en'),
      }),
      throwsA(
        isA<AutomationRunnerException>().having(
          (error) => error.message,
          'message',
          contains('Block "$_decideBlock" has a malformed "title"'),
        ),
      ),
    );
  });
}

Matcher _isBlockEntry(
  String name,
  int stepCount,
  Map<String, Object?> arguments,
  String? title,
) {
  return isA<AutomationBlockItem>()
      .having((entry) => entry.name, 'name', name)
      .having((entry) => entry.stepCount, 'stepCount', stepCount)
      .having((entry) => entry.arguments, 'arguments', arguments)
      .having((entry) => entry.title?.read('en'), 'title', title);
}
