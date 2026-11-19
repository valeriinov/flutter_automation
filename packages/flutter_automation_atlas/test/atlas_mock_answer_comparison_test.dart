import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_mock_answer_comparison.dart';

import 'test_utils/fake_atlas_project.dart';

const _recordedId = '0b60e351-2efe-4781-9e73-4411d8438bf7';
const _issuedId = '9b271088-07f8-410e-8a54-b605d489098b';
const _okStatus = 200;

void main() {
  group('AtlasMockAnswerComparison Tests', () {
    _atlasMockAnswerComparison_should_findSameAnswers();
    _atlasMockAnswerComparison_should_reportDifferentStatus();
    _atlasMockAnswerComparison_should_reportFirstDifferentValue();
    _atlasMockAnswerComparison_should_compareStatusOnlyWithoutResponse();
    _atlasMockAnswerComparison_should_readWholeHourDatesAsAnchorShift();
    _atlasMockAnswerComparison_should_ignoreDatesOffTheLaunch();
    _atlasMockAnswerComparison_should_reportWholeMinuteDateShift();
    _atlasMockAnswerComparison_should_pairIssuedIds();
    _atlasMockAnswerComparison_should_substituteIssuedIds();
    _atlasMockAnswerComparison_should_reportDifferentSignInResult();
    _atlasMockAnswerComparison_should_reportFieldTheRecordingLacks();
  });
}

void _atlasMockAnswerComparison_should_findSameAnswers() {
  test('AtlasMockAnswerComparison should find same answers', () {
    const answer = {
      'status': 200,
      'response': {
        'data': [1, 2],
      },
    };
    final difference = testMockAnswerComparison.compare(
      recorded: answer,
      replayed: answer,
    );

    expect(difference.isSame, isTrue);
  });
}

void _atlasMockAnswerComparison_should_reportDifferentStatus() {
  test('AtlasMockAnswerComparison should report different status', () {
    final difference = testMockAnswerComparison.compare(
      recorded: const {'status': 200},
      replayed: const {'status': 500},
    );

    expect(difference.isSame, isFalse);
    expect(difference.describe(), 'status 200, now 500');
  });
}

void _atlasMockAnswerComparison_should_reportFirstDifferentValue() {
  test('AtlasMockAnswerComparison should report first different value', () {
    final difference = testMockAnswerComparison.compare(
      recorded: const {
        'status': 200,
        'response': {
          'data': {'status': 'new', 'count': 1},
        },
      },
      replayed: const {
        'status': 200,
        'response': {
          'data': {'status': 'confirmed', 'count': 2},
        },
      },
    );

    expect(difference.mismatch, 'response.data.status "new", now "confirmed"');
  });
}

void _atlasMockAnswerComparison_should_compareStatusOnlyWithoutResponse() {
  test(
    'AtlasMockAnswerComparison should compare status only without response',
    () {
      final difference = testMockAnswerComparison.compare(
        recorded: const {'kind': 'request', 'status': 200},
        replayed: const {
          'kind': 'request',
          'status': 200,
          'response': {'bytes': 512},
        },
      );

      expect(difference.isSame, isTrue);
    },
  );
}

void _atlasMockAnswerComparison_should_readWholeHourDatesAsAnchorShift() {
  test(
    'AtlasMockAnswerComparison should read whole hour dates as anchor shift',
    () {
      final difference = testMockAnswerComparison.compare(
        recorded: _createDatedAnswer('2026-10-02T09:00:00.000Z'),
        replayed: _createDatedAnswer('2026-10-04T09:00:00.000Z'),
      );

      expect(difference.isSame, isFalse);
      expect(difference.mismatch, isNull);
      expect(difference.modalAnchorShift, const Duration(days: -2));
    },
  );
}

void _atlasMockAnswerComparison_should_ignoreDatesOffTheLaunch() {
  test('AtlasMockAnswerComparison should ignore dates off the launch', () {
    final difference = testMockAnswerComparison.compare(
      recorded: _createDatedAnswer('2026-10-02T09:17:42.315Z'),
      replayed: _createDatedAnswer('2026-10-02T09:00:00.000Z'),
    );

    expect(difference.isSame, isTrue);
  });
}

void _atlasMockAnswerComparison_should_reportWholeMinuteDateShift() {
  test('AtlasMockAnswerComparison should report whole minute date shift', () {
    final difference = testMockAnswerComparison.compare(
      recorded: _createDatedAnswer('2026-10-02T09:30:00.000Z'),
      replayed: _createDatedAnswer('2026-10-02T09:00:00.000Z'),
    );

    expect(difference.mismatch, startsWith('response.createdAt'));
  });
}

void _atlasMockAnswerComparison_should_pairIssuedIds() {
  test('AtlasMockAnswerComparison should pair issued ids', () {
    final difference = testMockAnswerComparison.compare(
      recorded: const {
        'status': 200,
        'response': {
          'url': 'https://files.example.invalid/original/$_recordedId',
        },
      },
      replayed: const {
        'status': 200,
        'response': {
          'url': 'https://files.example.invalid/original/$_issuedId',
        },
      },
    );

    expect(difference.isSame, isTrue);
    expect(difference.issuedIds, {_recordedId: _issuedId});
  });
}

void _atlasMockAnswerComparison_should_substituteIssuedIds() {
  test('AtlasMockAnswerComparison should substitute issued ids', () {
    final substituted = AtlasMockAnswerComparison.substituteIssuedIds(
      const {
        'path': '/files/complete/$_recordedId',
        'body': {
          'ids': [_recordedId],
        },
      },
      const {_recordedId: _issuedId},
    );

    expect(substituted, {
      'path': '/files/complete/$_issuedId',
      'body': {
        'ids': [_issuedId],
      },
    });
  });
}

void _atlasMockAnswerComparison_should_reportDifferentSignInResult() {
  test('AtlasMockAnswerComparison should report different sign in result', () {
    final difference = testMockAnswerComparison.compare(
      recorded: const {'kind': 'session', 'via': 'link', 'hasIdentity': true},
      replayed: const {'kind': 'session', 'via': 'link', 'hasIdentity': false},
    );

    expect(difference.describe(), 'hasIdentity true, now false');
  });
}

void _atlasMockAnswerComparison_should_reportFieldTheRecordingLacks() {
  test('AtlasMockAnswerComparison should report field the recording lacks', () {
    final difference = testMockAnswerComparison.compare(
      recorded: const {'kind': 'session', 'hasIdentity': true},
      replayed: const {'kind': 'session', 'via': 'link', 'hasIdentity': true},
    );

    expect(difference.describe(), 'via null, now "link"');
  });
}

Map<String, Object?> _createDatedAnswer(String createdAt) {
  return {
    'status': _okStatus,
    'response': {'createdAt': createdAt},
  };
}
