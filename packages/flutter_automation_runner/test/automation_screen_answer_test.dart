import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_screen_answer.dart';

const _screen = {'screenName': 'settings-route', 'layoutName': 'settings/main'};
const _splashScreen = 'start-screen';
const _platform = 'iOS';
const _inset = 336.4;
const _viewWidth = 390;
const _viewHeight = 844;
const _fractionalViewWidth = 411.4;

void main() {
  group('AutomationScreenAnswer Tests', () {
    _automationScreenAnswer_should_readScreenViewPlatformAndInset();
    _automationScreenAnswer_should_readAnswerWithoutScreenOrView();
    _automationScreenAnswer_should_dropViewOfNoPositiveSize();
    _automationScreenAnswer_should_rejectMalformedAnswers();
    _automationScreenAnswer_should_tellScreenPastSplash();
    _automationScreenAnswer_should_readTextsOfTheFrame();
    _automationScreenAnswer_should_readWidgetsOfTheFrame();
  });
}

void _automationScreenAnswer_should_readScreenViewPlatformAndInset() {
  test(
    'AutomationScreenAnswer should read screen, view, platform and inset',
    () {
      final answer = AutomationScreenAnswer.fromJson(
        _answer(view: {'width': _fractionalViewWidth, 'height': _viewHeight}),
      );

      expect(answer.screen, _screen);
      expect(answer.platform, _platform);
      expect(answer.keyboardInset, 336);
      expect(answer.view, (
        width: _fractionalViewWidth,
        height: _viewHeight.toDouble(),
      ));
    },
  );
}

void _automationScreenAnswer_should_readAnswerWithoutScreenOrView() {
  test('AutomationScreenAnswer should read answer without screen or view', () {
    final answer = AutomationScreenAnswer.fromJson(
      _answer(screen: null, view: null),
    );

    expect(answer.screen, isNull);
    expect(answer.view, isNull);
  });
}

void _automationScreenAnswer_should_dropViewOfNoPositiveSize() {
  test('AutomationScreenAnswer should drop view of no positive size', () {
    const views = [
      {'width': 0, 'height': _viewHeight},
      {'width': _viewWidth, 'height': -1},
      {'width': _viewWidth},
    ];

    for (final view in views) {
      expect(AutomationScreenAnswer.fromJson(_answer(view: view)).view, isNull);
    }
  });
}

void _automationScreenAnswer_should_rejectMalformedAnswers() {
  test('AutomationScreenAnswer should reject malformed answers', () {
    const malformedAnswers = [
      null,
      <Object?>[],
      {'screen': _screen},
      {'platform': _platform, 'inset': 'high'},
    ];

    for (final malformed in malformedAnswers) {
      expect(
        () => AutomationScreenAnswer.fromJson(malformed),
        throwsA(isA<StateError>()),
      );
    }
  });
}

void _automationScreenAnswer_should_tellScreenPastSplash() {
  test('AutomationScreenAnswer should tell screen past splash', () {
    final pastSplash = AutomationScreenAnswer.fromJson(_answer());
    final onSplash = AutomationScreenAnswer.fromJson(
      _answer(screen: {'screenName': _splashScreen}),
    );
    final beforeAnyScreen = AutomationScreenAnswer.fromJson(
      _answer(screen: null),
    );

    expect(pastSplash.isPastSplash(_splashScreen), isTrue);
    expect(pastSplash.isPastSplash(null), isTrue);
    expect(onSplash.isPastSplash(_splashScreen), isFalse);
    expect(beforeAnyScreen.isPastSplash(_splashScreen), isFalse);
  });
}

void _automationScreenAnswer_should_readTextsOfTheFrame() {
  test('AutomationScreenAnswer should read texts of the frame', () {
    const texts = ['Деталі кошика', 'Надіслати запит'];
    final answer = AutomationScreenAnswer.fromJson({
      ..._answer(),
      'texts': texts,
    });
    final answerWithoutTexts = AutomationScreenAnswer.fromJson(_answer());

    expect(answer.texts, texts);
    expect(answerWithoutTexts.texts, isEmpty);
  });
}

void _automationScreenAnswer_should_readWidgetsOfTheFrame() {
  test('AutomationScreenAnswer should read widgets of the frame', () {
    const widgets = ['BasketDetailsView', 'BasketDetailsScreen'];
    final answer = AutomationScreenAnswer.fromJson({
      ..._answer(),
      'widgets': widgets,
    });
    final answerWithoutWidgets = AutomationScreenAnswer.fromJson(_answer());

    expect(answer.widgets, widgets);
    expect(answerWithoutWidgets.widgets, isEmpty);
  });
}

Map<String, Object?> _answer({
  Map<String, Object?>? screen = _screen,
  Object? view = const {'width': _viewWidth, 'height': _viewHeight},
}) {
  return {
    'screen': screen,
    'view': view,
    'inset': _inset,
    'platform': _platform,
  };
}
