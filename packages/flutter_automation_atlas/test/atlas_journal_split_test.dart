import 'package:flutter_test/flutter_test.dart';

import 'test_utils/fake_atlas_project.dart';

const _okStatus = 200;
const _itemsScreen = 'items-route';
const _cartSearchScreen = 'cart-search-content-route';
const _itemDetailsScreen = 'quote-item-details-content-route';
const _successScreen = 'quote-item-success-route';
const _cartScreen = 'cart-route';
const _amountQuoteScreen = 'cart-quote-route';

const _findCartsTapRecord = {
  'kind': 'analytics',
  'target': 'tracker',
  'name': 'search_all_carts_tap',
  'parameters': {'screen_name': _itemsScreen},
};
const _cartSearchCreatedRecord = {
  'kind': 'state',
  'owner': 'CartSearchOwner',
  'created': true,
};
const _cartSearchLoadingRecord = {
  'kind': 'state',
  'owner': 'CartSearchOwner',
  'status': 'CartSearchStatusInitial',
  'isLoading': true,
};
const _availableCartsRecord = {
  'kind': 'request',
  'method': 'POST',
  'path': '/carts/list/available',
  'status': _okStatus,
};
const _cartSearchViewRecord = {
  'kind': 'analytics',
  'target': 'tracker',
  'name': 'screen_opened',
  'parameters': {
    'screen_name': _cartSearchScreen,
    'prev_screen_name': _itemsScreen,
  },
};
const _cartSearchLoadedRecord = {
  'kind': 'state',
  'owner': 'CartSearchOwner',
  'status': 'CartSearchStatusBase',
  'isLoading': false,
};

const _confirmTapRecord = {
  'kind': 'analytics',
  'target': 'tracker',
  'name': 'send_request_confirm_tap',
  'parameters': {'screen_name': _itemDetailsScreen},
};
const _confirmTapBeaconRecord = {
  'kind': 'analytics',
  'target': 'beacon',
  'name': 'send_request_confirm_tap',
  'parameters': <String, Object?>{},
};
const _confirmTapAttributionRecord = {
  'kind': 'analytics',
  'target': 'attribution',
  'name': 'send_request_confirm_tap',
  'parameters': <String, Object?>{},
};
const _basketCreatingRecord = {
  'kind': 'state',
  'owner': 'BasketCreateOwner',
  'status': 'BasketCreateStatusBase',
  'isLoading': true,
};
const _basketCreateRecord = {
  'kind': 'request',
  'method': 'POST',
  'path': '/baskets/create',
  'status': _okStatus,
};
const _basketCreatedRecord = {
  'kind': 'state',
  'owner': 'BasketCreateOwner',
  'status': 'BasketCreateStatusBasketCreated',
  'isLoading': false,
};
const _quoteCreatedRecord = {
  'kind': 'analytics',
  'target': 'tracker',
  'name': 'buyer_quote_created',
  'parameters': {'screen_name': _itemDetailsScreen},
};
const _itemsChangedRecord = {
  'kind': 'state',
  'owner': 'ItemsOwner',
  'status': 'ItemsStatusChanged',
  'isLoading': false,
};
const _itemsReloadingRecord = {
  'kind': 'state',
  'owner': 'ItemsOwner',
  'status': 'ItemsStatusInitial',
  'isLoading': false,
};
const _sellerItemsRecord = {
  'kind': 'request',
  'method': 'POST',
  'path': '/items/list/by-seller',
  'status': _okStatus,
};
const _successViewRecord = {
  'kind': 'analytics',
  'target': 'tracker',
  'name': 'screen_opened',
  'parameters': {
    'screen_name': _successScreen,
    'prev_screen_name': _itemDetailsScreen,
  },
};
const _itemsReloadedRecord = {
  'kind': 'state',
  'owner': 'ItemsOwner',
  'status': 'ItemsStatusBase',
  'isLoading': false,
};

const _amountQuoteCreatedRecord = {
  'kind': 'state',
  'owner': 'AmountQuoteOwner',
  'created': true,
};
const _amountQuoteSubmittingRecord = {
  'kind': 'state',
  'owner': 'AmountQuoteOwner',
  'status': 'AmountQuoteStatusBase',
  'isLoading': true,
};
const _amountQuoteCreateRecord = {
  'kind': 'request',
  'method': 'POST',
  'path': '/baskets/amount-quote/create',
  'status': _okStatus,
};
const _amountQuoteViewRecord = {
  'kind': 'analytics',
  'target': 'tracker',
  'name': 'screen_opened',
  'parameters': {'screen_name': _amountQuoteScreen},
};

const _cartViewRecord = {
  'kind': 'analytics',
  'target': 'tracker',
  'name': 'screen_opened',
  'parameters': {'screen_name': _cartScreen},
};
const _channelQueryRecord = {
  'kind': 'socket',
  'method': 'POST',
  'path': '/carts/mock-cart-9001/query',
};
const _cartOpenedRecord = {
  'kind': 'analytics',
  'target': 'tracker',
  'name': 'cart_opened',
  'parameters': {'screen_name': _cartScreen},
};
const _cartOpenedAttributionRecord = {
  'kind': 'analytics',
  'target': 'attribution',
  'name': 'cart_opened',
  'parameters': <String, Object?>{},
};

void main() {
  group('AtlasJournalSplit Tests', () {
    _atlasJournalSplit_should_openScreenWithOwnerCreatedInStage();
    _atlasJournalSplit_should_keepReloadsOfOtherScreensAfterAction();
    _atlasJournalSplit_should_keepJournalAfterActionOnSameScreen();
    _atlasJournalSplit_should_keepAnalyticsCopyWithEventItCopies();
  });
}

void _atlasJournalSplit_should_openScreenWithOwnerCreatedInStage() {
  test('AtlasJournalSplit should open screen with owner created in stage', () {
    final split = testJournalSplit.split(
      journal: [
        _findCartsTapRecord,
        _cartSearchCreatedRecord,
        _cartSearchLoadingRecord,
        _availableCartsRecord,
        _cartSearchViewRecord,
        _cartSearchLoadedRecord,
      ],
      screen: _itemsScreen,
      destination: _cartSearchScreen,
    );

    expect(split.afterAction, [_findCartsTapRecord]);
    expect(split.onScreenOpen, [
      _cartSearchCreatedRecord,
      _cartSearchLoadingRecord,
      _availableCartsRecord,
      _cartSearchViewRecord,
      _cartSearchLoadedRecord,
    ]);
  });
}

void _atlasJournalSplit_should_keepReloadsOfOtherScreensAfterAction() {
  test(
    'AtlasJournalSplit should keep reloads of other screens after action',
    () {
      final split = testJournalSplit.split(
        journal: [
          _confirmTapRecord,
          _confirmTapBeaconRecord,
          _confirmTapAttributionRecord,
          _basketCreatingRecord,
          _basketCreateRecord,
          _basketCreatedRecord,
          _quoteCreatedRecord,
          _itemsChangedRecord,
          _itemsReloadingRecord,
          _cartSearchLoadingRecord,
          _sellerItemsRecord,
          _availableCartsRecord,
          _successViewRecord,
          _cartSearchLoadedRecord,
          _itemsReloadedRecord,
        ],
        screen: _itemDetailsScreen,
        destination: _successScreen,
      );

      expect(split.afterAction, [
        _confirmTapRecord,
        _confirmTapBeaconRecord,
        _confirmTapAttributionRecord,
        _basketCreatingRecord,
        _basketCreateRecord,
        _basketCreatedRecord,
        _quoteCreatedRecord,
        _itemsChangedRecord,
        _itemsReloadingRecord,
        _cartSearchLoadingRecord,
        _sellerItemsRecord,
        _availableCartsRecord,
        _cartSearchLoadedRecord,
        _itemsReloadedRecord,
      ]);
      expect(split.onScreenOpen, [_successViewRecord]);
    },
  );
}

void _atlasJournalSplit_should_keepJournalAfterActionOnSameScreen() {
  test('AtlasJournalSplit should keep journal after action on same screen', () {
    const journal = [
      _amountQuoteCreatedRecord,
      _amountQuoteSubmittingRecord,
      _amountQuoteCreateRecord,
      _amountQuoteViewRecord,
    ];
    final split = testJournalSplit.split(
      journal: journal,
      screen: _amountQuoteScreen,
      destination: _amountQuoteScreen,
    );

    expect(split.afterAction, journal);
    expect(split.onScreenOpen, isEmpty);
  });
}

void _atlasJournalSplit_should_keepAnalyticsCopyWithEventItCopies() {
  test('AtlasJournalSplit should keep analytics copy with event it copies', () {
    final split = testJournalSplit.split(
      journal: [
        _cartViewRecord,
        _channelQueryRecord,
        _cartOpenedRecord,
        _cartOpenedAttributionRecord,
      ],
      screen: _amountQuoteScreen,
      destination: _cartScreen,
    );

    expect(split.afterAction, [_channelQueryRecord]);
    expect(split.onScreenOpen, [
      _cartViewRecord,
      _cartOpenedRecord,
      _cartOpenedAttributionRecord,
    ]);
  });
}
