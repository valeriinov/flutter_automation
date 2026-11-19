import 'package:flutter_test/flutter_test.dart';

import 'test_utils/fake_atlas_project.dart';

const _screenView = {
  'kind': 'analytics',
  'name': 'screen_opened',
  'parameters': {'screen_name': 'settings-route'},
};
const _recordedProfile = {
  'kind': 'request',
  'method': 'GET',
  'path': '/users/current',
  'status': 200,
};
const _walkedProfile = {
  'kind': 'request',
  'method': 'GET',
  'path': '/users/current',
  'acceptLanguage': 'uk',
  'status': 200,
};

const _deviceToken = 'eJ5_v1dAl01Er3JuuQ2GWd:tokG6cwXKTewd4riBO8Zw';
const _walkToken = 'atlas-headless:tok-install';
const _deviceSubscription = {
  'kind': 'request',
  'method': 'POST',
  'path': '/notifications/toggle-subscribe/device',
  'body': {'token': _deviceToken, 'oldToken': _deviceToken},
  'status': 200,
};
const _walkedSubscription = {
  'kind': 'request',
  'method': 'POST',
  'path': '/notifications/toggle-subscribe/device',
  'body': {'token': _walkToken, 'oldToken': _walkToken},
  'status': 200,
};
const _walkedLanguageSubscription = {
  'kind': 'request',
  'method': 'POST',
  'path': '/notifications/toggle-subscribe/device',
  'body': {'token': _walkToken, 'oldToken': _walkToken},
  'acceptLanguage': 'uk',
  'status': 200,
};
const _recordedUuid = '975f305f-aeba-4e77-8109-1c54fd02d19c';
const _walkUuid = '0fb39a87-0a41-441f-990d-13310d8d3d92';
const _walkAttachmentName = 'upload_1791462043267073.jpg';

void main() {
  group('AtlasJournalComparison Tests', () {
    _atlasJournalComparison_should_tellSameRecordsInAnotherOrderSame();
    _atlasJournalComparison_should_tellRecordOfAnotherFieldOther();
    _atlasJournalComparison_should_tellRecordsOfOtherUuidsSame();
    _atlasJournalComparison_should_nameFieldsRecordOfSameIdentity();
    _atlasJournalComparison_should_nameRecordOnlyOneSideHolds();
    _atlasJournalComparison_should_tellRecordsOfOtherInstallValues();
    _atlasJournalComparison_should_tellRecordsOfOtherAttachmentNames();
    _atlasJournalComparison_should_nameWalkInstallValueWithoutRecordedOne();
    _atlasJournalComparison_should_nameUuidRecordedStageDoesNotHold();
    _atlasJournalComparison_should_nameAttachmentNameWalkDrew();
    _atlasJournalComparison_should_nameNoValueOfRecordedUuid();
    _atlasJournalComparison_should_rewriteWalkWithDeviceNamesAndToken();
    _atlasJournalComparison_should_rewriteNoWalkOfOtherNameCount();
    _atlasJournalComparison_should_rewriteNoWalkTokenWithoutDeviceOne();
    _atlasJournalComparison_should_findFirstInstallValue();
    _atlasJournalComparison_should_keepRecordHeldAlikeAsRecorded();
    _atlasJournalComparison_should_writeRecordedInstallValueIntoOtherRecord();
    _atlasJournalComparison_should_hashJournalsItTellsSameAlike();
    _atlasJournalComparison_should_hashJournalsItTellsOtherApart();
  });
}

void _atlasJournalComparison_should_hashJournalsItTellsSameAlike() {
  test('AtlasJournalComparison should hash journals it tells same alike', () {
    final recorded = testJournalComparison.hash([
      _screenView,
      _deviceSubscription,
      _messageWithId(_recordedUuid),
    ]);
    final walked = testJournalComparison.hash([
      _messageWithId(_walkUuid),
      _walkedSubscription,
      _screenView,
    ]);

    expect(walked, recorded);
  });
}

void _atlasJournalComparison_should_hashJournalsItTellsOtherApart() {
  test('AtlasJournalComparison should hash journals it tells other apart', () {
    final recorded = testJournalComparison.hash([_recordedProfile]);
    final walked = testJournalComparison.hash([_walkedProfile]);

    expect(walked, isNot(recorded));
  });
}

void _atlasJournalComparison_should_tellSameRecordsInAnotherOrderSame() {
  test(
    'AtlasJournalComparison should tell same records in another order same',
    () {
      final isSame = testJournalComparison.isSame(
        const [_screenView, _recordedProfile],
        const [_recordedProfile, _screenView],
      );
      final difference = testJournalComparison.tryDescribeDifference(
        recorded: const [_screenView, _recordedProfile],
        walked: const [_recordedProfile, _screenView],
      );

      expect(isSame, isTrue);
      expect(difference, isNull);
    },
  );
}

void _atlasJournalComparison_should_tellRecordOfAnotherFieldOther() {
  test('AtlasJournalComparison should tell record of another field other', () {
    final isSame = testJournalComparison.isSame(
      const [_screenView, _recordedProfile],
      const [_screenView, _walkedProfile],
    );

    expect(isSame, isFalse);
  });
}

void _atlasJournalComparison_should_nameFieldsRecordOfSameIdentity() {
  test('AtlasJournalComparison should name fields record of same identity', () {
    final difference = testJournalComparison.tryDescribeDifference(
      recorded: const [_screenView, _recordedProfile],
      walked: const [_walkedProfile, _screenView],
    );

    expect(difference, 'request GET /users/current acceptLanguage');
  });
}

void _atlasJournalComparison_should_nameRecordOnlyOneSideHolds() {
  test('AtlasJournalComparison should name record only one side holds', () {
    final notWalked = testJournalComparison.tryDescribeDifference(
      recorded: const [_screenView, _recordedProfile],
      walked: const [_recordedProfile],
    );
    final notRecorded = testJournalComparison.tryDescribeDifference(
      recorded: const [_recordedProfile],
      walked: const [_recordedProfile, _screenView],
    );

    expect(notWalked, 'analytics screen_opened not walked');
    expect(notRecorded, 'analytics screen_opened not recorded');
  });
}

void _atlasJournalComparison_should_tellRecordsOfOtherUuidsSame() {
  test('AtlasJournalComparison should tell records of other uuids same', () {
    final isSame = testJournalComparison.isSame(
      [_messageWithId('0b8f3c2e-6d1a-4f5b-9c7e-2a4d6e8f0a1b')],
      [_messageWithId('7e2d9a4c-1b3f-4e6a-8d5c-9f0e1a2b3c4d')],
    );

    expect(isSame, isTrue);
  });
}

Map<String, Object?> _messageWithId(String id) {
  return {
    'kind': 'socket',
    'method': 'POST',
    'path': '/carts/mock-cart-9001/message',
    'body': {
      'message': {'id': id, 'text': 'hello'},
    },
  };
}

void _atlasJournalComparison_should_tellRecordsOfOtherInstallValues() {
  test(
    'AtlasJournalComparison should tell records of other install values',
    () {
      final isSame = testJournalComparison.isSame(
        const [_deviceSubscription],
        const [_walkedSubscription],
      );

      expect(isSame, isTrue);
    },
  );
}

void _atlasJournalComparison_should_findFirstInstallValue() {
  test('AtlasJournalComparison should find first install value', () {
    final installValue = testJournalComparison.tryFindInstallValue(const [
      _screenView,
      _deviceSubscription,
      _walkedSubscription,
    ]);
    final missingInstallValue = testJournalComparison.tryFindInstallValue(
      const [_screenView],
    );

    expect(installValue, _deviceToken);
    expect(missingInstallValue, isNull);
  });
}

void _atlasJournalComparison_should_keepRecordHeldAlikeAsRecorded() {
  test('AtlasJournalComparison should keep record held alike as recorded', () {
    final journal = testJournalComparison.keepRecorded(
      walked: const [_walkedSubscription, _walkedProfile],
      recorded: const [_recordedProfile, _deviceSubscription],
      installValue: null,
    );

    expect(journal, [_deviceSubscription, _walkedProfile]);
  });
}

void _atlasJournalComparison_should_writeRecordedInstallValueIntoOtherRecord() {
  test('AtlasJournalComparison should write recorded install value into other '
      'record', () {
    final journal = testJournalComparison.keepRecorded(
      walked: const [_walkedLanguageSubscription],
      recorded: const [_deviceSubscription],
      installValue: _deviceToken,
    );

    expect(journal, [
      {
        ..._walkedLanguageSubscription,
        'body': {'token': _deviceToken, 'oldToken': _deviceToken},
      },
    ]);
  });
}

void _atlasJournalComparison_should_tellRecordsOfOtherAttachmentNames() {
  test(
    'AtlasJournalComparison should tell records of other attachment names',
    () {
      final isSame = testJournalComparison.isSame(
        const [
          {'kind': 'socket', 'title': 'upload_1791287569553676.jpg'},
        ],
        const [
          {'kind': 'socket', 'title': 'upload_1791462043267073.jpg'},
        ],
      );

      expect(isSame, isTrue);
    },
  );
}

void _atlasJournalComparison_should_nameWalkInstallValueWithoutRecordedOne() {
  test('AtlasJournalComparison should name walk install value without recorded '
      'one', () {
    final walkValue = testJournalComparison.tryDescribeWalkValue(
      walked: const [_walkedLanguageSubscription],
      recorded: const [],
      installValue: null,
    );
    final keptValue = testJournalComparison.tryDescribeWalkValue(
      walked: const [_walkedLanguageSubscription],
      recorded: const [],
      installValue: _deviceToken,
    );

    expect(
      walkValue,
      'request POST /notifications/toggle-subscribe/device holds $_walkToken',
    );
    expect(keptValue, isNull);
  });
}

void _atlasJournalComparison_should_nameUuidRecordedStageDoesNotHold() {
  test(
    'AtlasJournalComparison should name uuid recorded stage does not hold',
    () {
      final walkValue = testJournalComparison.tryDescribeWalkValue(
        walked: const [
          {
            'kind': 'request',
            'method': 'GET',
            'path': '/files/$_walkUuid',
            'acceptLanguage': 'uk',
          },
        ],
        recorded: const [
          {'kind': 'request', 'method': 'GET', 'path': '/files/$_recordedUuid'},
        ],
        installValue: null,
      );

      expect(walkValue, 'request GET /files/$_walkUuid holds $_walkUuid');
    },
  );
}

void _atlasJournalComparison_should_nameAttachmentNameWalkDrew() {
  test('AtlasJournalComparison should name attachment name walk drew', () {
    final walkValue = testJournalComparison.tryDescribeWalkValue(
      walked: const [
        {'kind': 'socket', 'title': _walkAttachmentName, 'size': 2},
      ],
      recorded: const [
        {'kind': 'socket', 'title': 'upload_1791287569553676.jpg'},
      ],
      installValue: null,
    );

    expect(walkValue, 'socket holds $_walkAttachmentName');
  });
}

void _atlasJournalComparison_should_nameNoValueOfRecordedUuid() {
  test('AtlasJournalComparison should name no value of recorded uuid', () {
    final walkValue = testJournalComparison.tryDescribeWalkValue(
      walked: const [
        {
          'kind': 'request',
          'method': 'DELETE',
          'path': '/items/$_recordedUuid',
          'acceptLanguage': 'uk',
        },
      ],
      recorded: const [
        {
          'kind': 'request',
          'method': 'DELETE',
          'path': '/items/$_recordedUuid',
        },
      ],
      installValue: null,
    );

    expect(walkValue, isNull);
  });
}

void _atlasJournalComparison_should_rewriteWalkWithDeviceNamesAndToken() {
  test(
    'AtlasJournalComparison should rewrite walk with device names and token',
    () {
      final journals = testJournalComparison.tryRewriteWalk(
        walked: const [
          [
            {'kind': 'socket', 'title': _walkAttachmentName, 'id': _walkUuid},
          ],
          [_walkedSubscription],
        ],
        recorded: const [
          [
            {
              'kind': 'socket',
              'title': 'upload_1791287569553676.jpg',
              'id': _recordedUuid,
            },
          ],
          [_deviceSubscription],
        ],
        installValue: _deviceToken,
      );

      expect(journals, [
        [
          {
            'kind': 'socket',
            'title': 'upload_1791287569553676.jpg',
            'id': _walkUuid,
          },
        ],
        [_deviceSubscription],
      ]);
    },
  );
}

void _atlasJournalComparison_should_rewriteNoWalkOfOtherNameCount() {
  test('AtlasJournalComparison should rewrite no walk of other name count', () {
    final journals = testJournalComparison.tryRewriteWalk(
      walked: const [
        [
          {'kind': 'socket', 'title': _walkAttachmentName},
        ],
      ],
      recorded: const [[]],
      installValue: null,
    );

    expect(journals, isNull);
  });
}

void _atlasJournalComparison_should_rewriteNoWalkTokenWithoutDeviceOne() {
  test(
    'AtlasJournalComparison should rewrite no walk token without device one',
    () {
      final journals = testJournalComparison.tryRewriteWalk(
        walked: const [
          [_walkedSubscription],
        ],
        recorded: const [[]],
        installValue: null,
      );

      expect(journals, isNull);
    },
  );
}
