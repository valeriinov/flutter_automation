import 'dart:convert';

import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

const _json = <String, Object?>{
  'groups': [
    {
      'name': 'account',
      'title': {'en': 'Sign-in', 'uk': 'Вхід'},
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
    _automationCatalogue_should_readAnEmptyObject();
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

void _automationCatalogue_should_readAnEmptyObject() {
  test('AutomationCatalogue should read an empty object', () {
    final catalogue = AutomationCatalogue.fromJson(const {});

    expect(catalogue.flows, isEmpty);
    expect(catalogue.groups, isEmpty);
  });
}
