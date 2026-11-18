import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_mock_replay.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';

const _variantId = 'login_atlas signedInForInbox';
final _loginRecord = {
  'kind': 'request',
  'method': 'POST',
  'path': fakeSignInPath,
  'body': {'via': 'email', 'code': 'sample-code'},
  'status': 200,
};
final _signInRecord = {
  'kind': fakeSignInKind,
  'via': 'link',
  'hasIdentity': true,
};
const _stateRecord = {'kind': 'state', 'owner': 'LoginOwner', 'created': true};
final _impliedSignInRecord = {
  'kind': fakeSignInKind,
  'via': 'email',
  'hasIdentity': true,
};

void main() {
  group('AtlasMockReplayInput Tests', () {
    _atlasMockReplayInput_should_takeAnswerRecordsWithTheirStages();
    _atlasMockReplayInput_should_implySignInBeforeUnrecordedLogin();
    _atlasMockReplayInput_should_keepRecordedSignInBeforeLogin();
    _atlasMockReplayInput_should_readBackWhatItWrites();
  });
}

void _atlasMockReplayInput_should_takeAnswerRecordsWithTheirStages() {
  test('AtlasMockReplayInput should take answer records with their stages', () {
    final input = _createInput([
      [_stateRecord, _signInRecord],
      [_loginRecord],
    ]);

    expect(input.answers.map((answer) => answer.stage), [0, 1]);
    expect(input.answers.map((answer) => answer.record), [
      _signInRecord,
      _loginRecord,
    ]);
  });
}

void _atlasMockReplayInput_should_implySignInBeforeUnrecordedLogin() {
  test('AtlasMockReplayInput should imply sign in before unrecorded login', () {
    final input = _createInput([
      [_loginRecord],
      [_loginRecord],
    ]);

    expect(input.answers.map((answer) => answer.stage), [0, 0, 1, 1]);
    expect(input.answers.map((answer) => answer.record), [
      _impliedSignInRecord,
      _loginRecord,
      _impliedSignInRecord,
      _loginRecord,
    ]);
  });
}

void _atlasMockReplayInput_should_keepRecordedSignInBeforeLogin() {
  test('AtlasMockReplayInput should keep recorded sign in before login', () {
    final input = _createInput([
      [_signInRecord],
      [_loginRecord],
    ]);

    expect(input.answers.map((answer) => answer.record), [
      _signInRecord,
      _loginRecord,
    ]);
  });
}

void _atlasMockReplayInput_should_readBackWhatItWrites() {
  test('AtlasMockReplayInput should read back what it writes', () {
    final input = _createInput([
      [_signInRecord, _loginRecord],
    ]);
    final readInput = AtlasMockReplayInput.fromJson(input.toJson());

    expect(readInput.id, _variantId);
    expect(readInput.answers.map((answer) => answer.record), [
      _signInRecord,
      _loginRecord,
    ]);
  });
}

AtlasMockReplayInput _createInput(List<List<Object?>> journals) {
  return AtlasMockReplayInput.fromSnapshot(
    id: _variantId,
    scenario: const {},
    schema: fakeAtlasJournalSchema,
    snapshot: createAtlasSnapshot(
      flow: 'login_atlas',
      variant: 'signedInForInbox',
      stages: [
        for (final journal in journals)
          AtlasStage(
            label: 'sign in',
            action: 'tap',
            journal: journal,
            ok: true,
            target: null,
            block: null,
            targetRect: null,
            screen: null,
            designScreen: null,
            shot: null,
            error: null,
          ),
      ],
    ),
  );
}
