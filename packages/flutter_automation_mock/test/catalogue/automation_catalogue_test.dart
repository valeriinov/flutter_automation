import 'dart:convert';

import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_mock/src/catalogue/automation_catalogue_tables.dart';
import 'package:flutter_test/flutter_test.dart';

const _json = <String, Object?>{
  'version': 2,
  'areas': [
    {
      'name': 'access',
      'title': {'en': 'Access'},
    },
  ],
  'groups': [
    {
      'name': 'account',
      'title': {'en': 'Sign-in', 'uk': 'Вхід'},
      'area': 'access',
    },
  ],
  'flows': [
    {
      'name': 'login',
      'group': 'account',
      'title': {'en': 'Sign-in'},
      'defaultVariant': 'otp',
      'variants': [
        {
          'name': 'otp',
          'scenario': {'latency': 'fast'},
          'items': ['authVerifyPhone'],
          'steps': [
            {
              'label': 'tap send',
              'requests': [
                {'method': 'POST', 'path': '/auth/otp', 'statusCode': 200},
              ],
            },
            {'label': 'trace', 'isService': true, 'requests': []},
          ],
        },
      ],
      'fork': {
        'stepIndex': 0,
        'method': 'POST',
        'path': '/auth/otp',
        'branches': [
          {'variant': 'otp', 'statusCode': 200, 'label': 'default'},
        ],
      },
    },
  ],
};

void main() {
  group('AutomationCatalogue Tests', () {
    _automationCatalogue_should_roundTripThroughJson();
    _automationCatalogue_should_throwForAMissingOrUnknownVersion();
    _automationCatalogue_should_storeEachResponseAndLongStringOnce();
    _automationCatalogue_should_readTheTablesBack();
    _automationCatalogueTables_should_keyResponsesByFixedWidthHex();
    _automationCatalogueTables_should_shareOneKeyForAnotherKeyOrder();
    _automationCatalogueTables_should_suffixACollidingKey();
  });
}

void _automationCatalogue_should_roundTripThroughJson() {
  test('AutomationCatalogue should round trip through json', () {
    final catalogue = AutomationCatalogue.fromJson(_json);

    expect(jsonEncode(catalogue.toJson()), jsonEncode(_json));
    expect(catalogue.flows.first.variants.first.steps.last.isService, isTrue);
    expect(catalogue.flows.first.fork?.branches.first.label, 'default');
  });
}

void _automationCatalogue_should_throwForAMissingOrUnknownVersion() {
  test('AutomationCatalogue should throw for a missing or unknown version', () {
    expect(
      () => AutomationCatalogue.fromJson(const {}),
      throwsA(
        isA<AutomationCatalogueVersionException>().having(
          (error) => error.message,
          'message',
          allOf(contains('no version'), contains('Regenerate')),
        ),
      ),
    );
    expect(
      () => AutomationCatalogue.fromJson(const {'version': 3}),
      throwsA(
        isA<AutomationCatalogueVersionException>().having(
          (error) => error.message,
          'message',
          allOf(contains('version 3'), contains('Regenerate')),
        ),
      ),
    );
  });
}

AutomationCatalogue _repeating() {
  final avatar = 'a' * 2000;
  final request = AutomationCatalogueRequest(
    method: 'GET',
    path: '/profile',
    statusCode: 200,
    response: {'name': 'Ann', 'avatar': avatar},
  );

  return AutomationCatalogue(
    flows: [
      AutomationCatalogueFlow(
        name: 'login',
        variants: [
          AutomationCatalogueVariant(
            name: 'first',
            steps: [
              AutomationCatalogueStep(label: 'one', requests: [request]),
              AutomationCatalogueStep(label: 'two', requests: [request]),
            ],
          ),
          AutomationCatalogueVariant(
            name: 'second',
            steps: [
              AutomationCatalogueStep(
                label: 'one',
                requests: [
                  AutomationCatalogueRequest(
                    method: 'GET',
                    path: '/other',
                    statusCode: 200,
                    response: {'note': avatar},
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void _automationCatalogue_should_storeEachResponseAndLongStringOnce() {
  test(
    'AutomationCatalogue should store each response and long string once',
    () {
      final json = _repeating().toJson();
      final text = jsonEncode(json);

      expect(json['version'], 2);
      expect((json['responses'] as Map).length, 2);
      expect((json['blobs'] as List), ['a' * 2000]);
      expect(RegExp('a{2000}').allMatches(text).length, 1);
      expect(text, isNot(contains('"response":')));
    },
  );
}

void _automationCatalogue_should_readTheTablesBack() {
  test('AutomationCatalogue should read the tables back', () {
    final catalogue = AutomationCatalogue.fromJson(
      jsonDecode(jsonEncode(_repeating().toJson())) as Map<String, Object?>,
    );
    final steps = catalogue.flows.single.variants.first.steps;

    expect(steps.first.requests.single.response, {
      'name': 'Ann',
      'avatar': 'a' * 2000,
    });
    expect(
      steps.last.requests.single.response,
      steps.first.requests.single.response,
    );
    expect(
      catalogue
          .flows
          .single
          .variants
          .last
          .steps
          .single
          .requests
          .single
          .response,
      {'note': 'a' * 2000},
    );
  });
}

void _automationCatalogueTables_should_keyResponsesByFixedWidthHex() {
  test('AutomationCatalogueTables should key responses by fixed width hex', () {
    final keys = <String>[
      for (int index = 0; index < 200; index += 1)
        AutomationCatalogueTables.hashResponse({'id': index}),
    ];

    expect(keys, everyElement(matches(RegExp(r'^[0-9a-f]{16}$'))));
    expect(keys.toSet().length, keys.length);
  });
}

void _automationCatalogueTables_should_shareOneKeyForAnotherKeyOrder() {
  test(
    'AutomationCatalogueTables should share one key for another key order',
    () {
      final responses = <String, Object?>{};
      final first = AutomationCatalogueTables.store(responses, {
        'id': 1,
        'inner': {'a': 1, 'b': 2},
      });
      final second = AutomationCatalogueTables.store(responses, {
        'inner': {'b': 2, 'a': 1},
        'id': 1,
      });

      expect(second, first);
      expect(responses.length, 1);
    },
  );
}

void _automationCatalogueTables_should_suffixACollidingKey() {
  test('AutomationCatalogueTables should suffix a colliding key', () {
    final responses = <String, Object?>{};

    String sameHash(Object response) => '00000000000000ff';

    final first = AutomationCatalogueTables.store(responses, {
      'id': 1,
    }, hashOf: sameHash);
    final second = AutomationCatalogueTables.store(responses, {
      'id': 2,
    }, hashOf: sameHash);
    final again = AutomationCatalogueTables.store(responses, {
      'id': 2,
    }, hashOf: sameHash);

    expect(first, '00000000000000ff');
    expect(second, '00000000000000ff-1');
    expect(again, second);
    expect(responses.length, 2);
  });
}
