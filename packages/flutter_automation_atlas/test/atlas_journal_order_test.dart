import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_journal_order.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';

import 'test_utils/create_atlas_snapshot.dart';

const _label = 'open cart details';
const _okStatus = 200;
const _targetRect = {'left': 0.05, 'top': 0.4, 'right': 0.95, 'bottom': 0.55};
const _screenViewRecord = {
  'kind': 'analytics',
  'target': 'tracker',
  'name': 'screen_opened',
  'parameters': {'screen_name': 'cart-details-route'},
};
const _cartRecord = {
  'kind': 'request',
  'method': 'GET',
  'path': '/carts/available/by-id/304',
  'status': _okStatus,
};
const _cartRecordInOtherKeyOrder = {
  'status': _okStatus,
  'path': '/carts/available/by-id/304',
  'method': 'GET',
  'kind': 'request',
};
const _settingsRecord = {
  'kind': 'request',
  'method': 'GET',
  'path': '/settings',
  'status': _okStatus,
};

void main() {
  group('AtlasJournalOrder Tests', () {
    _atlasJournalOrder_should_keepPreviousOrderOfSameRecords();
    _atlasJournalOrder_should_keepCapturedOrderOfOtherRecords();
    _atlasJournalOrder_should_keepCapturedOrderOfAnotherAction();
    _atlasJournalOrder_should_keepCapturedOrderWithoutPrevious();
  });
}

void _atlasJournalOrder_should_keepPreviousOrderOfSameRecords() {
  test('AtlasJournalOrder should keep previous order of same records', () {
    final ordered = AtlasJournalOrder.keepPreviousOrder(
      captured: _createSnapshot(
        label: _label,
        journal: [_cartRecordInOtherKeyOrder, _screenViewRecord],
      ),
      previous: _createSnapshot(
        label: _label,
        journal: [_screenViewRecord, _cartRecord],
      ),
    );

    expect(ordered.stages.single.journal, [_screenViewRecord, _cartRecord]);
    expect(ordered.stages.single.targetRect, _targetRect);
  });
}

void _atlasJournalOrder_should_keepCapturedOrderOfOtherRecords() {
  test('AtlasJournalOrder should keep captured order of other records', () {
    final ordered = AtlasJournalOrder.keepPreviousOrder(
      captured: _createSnapshot(
        label: _label,
        journal: [_cartRecord, _settingsRecord],
      ),
      previous: _createSnapshot(
        label: _label,
        journal: [_settingsRecord, _cartRecord, _cartRecord],
      ),
    );

    expect(ordered.stages.single.journal, [_cartRecord, _settingsRecord]);
  });
}

void _atlasJournalOrder_should_keepCapturedOrderOfAnotherAction() {
  test('AtlasJournalOrder should keep captured order of another action', () {
    final ordered = AtlasJournalOrder.keepPreviousOrder(
      captured: _createSnapshot(
        label: _label,
        journal: [_cartRecord, _screenViewRecord],
      ),
      previous: _createSnapshot(
        label: 'open item details',
        journal: [_screenViewRecord, _cartRecord],
      ),
    );

    expect(ordered.stages.single.journal, [_cartRecord, _screenViewRecord]);
  });
}

void _atlasJournalOrder_should_keepCapturedOrderWithoutPrevious() {
  test('AtlasJournalOrder should keep captured order without previous', () {
    final captured = _createSnapshot(
      label: _label,
      journal: [_cartRecord, _screenViewRecord],
    );
    final ordered = AtlasJournalOrder.keepPreviousOrder(
      captured: captured,
      previous: null,
    );

    expect(ordered.stages.single.journal, [_cartRecord, _screenViewRecord]);
    expect(ordered.end, captured.end);
  });
}

AtlasSnapshot _createSnapshot({
  required String label,
  required List<Object?> journal,
}) {
  return createAtlasSnapshot(
    flow: 'shop_flow',
    variant: 'shopFromExistingItem',
    stages: [
      AtlasStage(
        label: label,
        action: 'tap',
        journal: journal,
        ok: true,
        target: const {'by': 'valueKey', 'value': 'cart_search.card'},
        block: null,
        targetRect: _targetRect,
        screen: 'carts-route',
        designScreen: 'home/buyer',
        shot: '0123456789ab',
        error: null,
      ),
    ],
    end: const AtlasEnd(
      screen: 'cart-details-route',
      designScreen: 'cart/details',
      shot: 'ba9876543210',
    ),
  );
}
