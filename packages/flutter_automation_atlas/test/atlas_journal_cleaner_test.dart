import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_journal_cleaner.dart';

import 'test_utils/fake_atlas_project.dart';

const _cartId = 7;
const _requestRecords = [
  {'seq': 0, 'kind': 'request', 'path': '/settings'},
  {
    'seq': 1,
    'kind': 'request',
    'path': '/carts',
    'body': {'seq': 'kept inside the body'},
  },
];
const _analyticsRecords = [
  {
    'seq': 2,
    'kind': 'analytics',
    'session_id': 'top',
    'parameters': {
      'screen_name': 'carts-route',
      'visit_ms': 120,
      'items': [
        {'session_id': 'nested', 'name': 'first'},
      ],
    },
  },
];
const _responseRecords = [
  {
    'seq': 3,
    'kind': 'request',
    'path': '/carts/list/by-buyer',
    'response': {
      'data': [
        {
          'id': _cartId,
          'expiredAt': '2026-09-22T09:00:00.000Z',
          'arrivalDate': '2026-03-11T06:00:00.000Z',
          'basket': {'itemStartDate': '2026-09-19T09:00:00.000Z'},
        },
      ],
    },
  },
];

void main() {
  group('AtlasJournalCleaner Tests', () {
    _atlasJournalCleaner_should_dropSequenceOfRecord();
    _atlasJournalCleaner_should_removeVolatileKeysAtEveryDepth();
    _atlasJournalCleaner_should_removeTimestampsSeededFromLaunchTime();
    _atlasJournalCleaner_should_describeLaunchWithoutItsMoments();
    _atlasJournalCleaner_should_dropOnlyMomentsOfLaunch();
  });
}

void _atlasJournalCleaner_should_dropSequenceOfRecord() {
  test('AtlasJournalCleaner should drop sequence of record', () {
    final cleaned = testJournalCleaner.clean(_requestRecords);

    expect(cleaned, [
      {'kind': 'request', 'path': '/settings'},
      {
        'kind': 'request',
        'path': '/carts',
        'body': {'seq': 'kept inside the body'},
      },
    ]);
  });
}

void _atlasJournalCleaner_should_removeVolatileKeysAtEveryDepth() {
  test('AtlasJournalCleaner should remove volatile keys at every depth', () {
    final cleaned = testJournalCleaner.clean(_analyticsRecords);

    expect(cleaned, [
      {
        'kind': 'analytics',
        'parameters': {
          'screen_name': 'carts-route',
          'items': [
            {'name': 'first'},
          ],
        },
      },
    ]);
  });
}

void _atlasJournalCleaner_should_removeTimestampsSeededFromLaunchTime() {
  test(
    'AtlasJournalCleaner should remove timestamps seeded from launch time',
    () {
      final cleaned = testJournalCleaner.clean(_responseRecords);

      expect(cleaned, [
        {
          'kind': 'request',
          'path': '/carts/list/by-buyer',
          'response': {
            'data': [
              {
                'id': _cartId,
                'arrivalDate': '2026-03-11T06:00:00.000Z',
                'basket': <String, Object?>{},
              },
            ],
          },
        },
      ]);
    },
  );
}

void _atlasJournalCleaner_should_describeLaunchWithoutItsMoments() {
  test('AtlasJournalCleaner should describe launch without its moments', () {
    final launch = testJournalCleaner.tryDescribeLaunch(const {
      'kind': 'launch',
      'anchor': '2026-10-06T09:00:00.000Z',
      'launchedAt': '2026-10-06T13:00:44.058Z',
      'session': {'expiredAt': '2026-10-07T09:00:00.000Z', 'role': 'buyer'},
    });
    final noLaunch = testJournalCleaner.tryDescribeLaunch(null);

    expect(launch, {
      'kind': 'launch',
      'session': {'role': 'buyer'},
    });
    expect(noLaunch, isNull);
  });
}

void _atlasJournalCleaner_should_dropOnlyMomentsOfLaunch() {
  test('AtlasJournalCleaner should drop only moments of launch', () {
    final launch = AtlasJournalCleaner.withoutMoments(const {
      'kind': 'launch',
      'anchor': '2026-10-06T09:00:00.000Z',
      'launchedAt': '2026-10-06T13:00:44.058Z',
      'session': {'expiredAt': '2026-10-07T09:00:00.000Z'},
    });

    expect(launch, {
      'kind': 'launch',
      'session': {'expiredAt': '2026-10-07T09:00:00.000Z'},
    });
  });
}
