import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_mock_answer_comparison.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replay.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replayer.dart';

const _request = 'GET /items';
const _sameDifference = AtlasMockAnswerDifference(
  anchorShifts: [],
  issuedIds: {},
);
const _threeHours = Duration(hours: 3);
const _answers = [
  AtlasRecordedAnswer(stage: 0, record: {'kind': 'request'}),
  AtlasRecordedAnswer(stage: 1, record: {'kind': 'request'}),
  AtlasRecordedAnswer(stage: 2, record: {'kind': 'request'}),
];
const _capturedMoments = [
  (anchor: '2026-10-06T09:00:00.000Z', launchedAt: '2026-10-06T12:00:00.000Z'),
  (anchor: '2026-10-06T09:00:00.000Z', launchedAt: '2026-10-06T12:00:00.000Z'),
  (anchor: '2026-10-06T09:00:00.000Z', launchedAt: '2026-10-06T12:00:00.000Z'),
];
const _input = AtlasMockReplayInput(
  id: 'shop_flow/shopFromSearch',
  scenario: {},
  answers: _answers,
  locale: 'en',
);

void main() {
  group('AtlasMockReplayer Tests', () {
    _atlasMockReplayer_should_reportSameForAnswersAsRecorded();
    _atlasMockReplayer_should_nameFirstStageAnsweredDifferently();
    _atlasMockReplayer_should_replayOnAnchorShiftedByWholeHours();
  });
}

void _atlasMockReplayer_should_reportSameForAnswersAsRecorded() {
  test('AtlasMockReplayer should report same for answers as recorded', () {
    final outcome = AtlasMockReplayer(
      _input,
      (input, timing) => _answerEveryStage(input, (_) => _sameDifference),
    ).replay();

    expect(outcome.isSame, isTrue);
    expect(outcome.difference, isNull);
  });
}

void _atlasMockReplayer_should_nameFirstStageAnsweredDifferently() {
  test('AtlasMockReplayer should name first stage answered differently', () {
    const input = AtlasMockReplayInput(
      id: 'shop_flow/shopFromSearch',
      scenario: {},
      answers: _answers,
      locale: 'en',
      stageMoments: _capturedMoments,
    );
    final outcome = AtlasMockReplayer(
      input,
      (input, timing) => _answerEveryStage(
        input,
        (stage) => stage >= 1
            ? const AtlasMockAnswerDifference.mismatch('status 404')
            : _sameDifference,
      ),
    ).replay();

    expect(outcome.stage, 1);
    expect(outcome.difference, '$_request status 404');
  });
}

void _atlasMockReplayer_should_replayOnAnchorShiftedByWholeHours() {
  test('AtlasMockReplayer should replay on anchor shifted by whole hours', () {
    final timings = <AtlasReplayTiming>[];
    final outcome = AtlasMockReplayer(_input, (input, timing) {
      timings.add(timing);

      return _answerEveryStage(
        input,
        (_) => timing.anchor.hour == _noonHour + _threeHours.inHours
            ? _sameDifference
            : const AtlasMockAnswerDifference(
                anchorShifts: [_threeHours],
                issuedIds: {},
              ),
      );
    }).replay();

    expect(outcome.isSame, isTrue);
    expect(timings.last.anchor.hour, _noonHour + _threeHours.inHours);
  });
}

const _noonHour = 12;

List<AtlasReplayedAnswer> _answerEveryStage(
  AtlasMockReplayInput input,
  AtlasMockAnswerDifference Function(int stage) differenceOf,
) {
  return [
    for (final answer in input.answers)
      AtlasReplayedAnswer(
        stage: answer.stage,
        request: _request,
        difference: differenceOf(answer.stage),
      ),
  ];
}
