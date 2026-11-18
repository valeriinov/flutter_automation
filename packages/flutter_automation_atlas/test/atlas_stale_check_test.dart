import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_declarations_store.dart';
import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_mock_replay.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_source_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_check.dart';

import 'test_utils/add_test_headless_hashes.dart';
import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';
import 'test_utils/read_test_package_config.dart';
import 'test_utils/test_atlas_root.dart';
import 'test_utils/test_automation_pubspec.dart';

const _stagedLabels = ['open the search', 'open the cart', 'quote an item'];
const _widgetPath = 'lib/existing_items_view.dart';
final _uk = fakeAtlasLocales.first;
const _en = 'en';
const _sendKey = 'quoteItemSendRequest';
const _backKey = 'back';
const _doneKey = 'quoteItemSentTitle';
const _addedLabel = 'send the quote';
final _localeKeys = {
  _sendKey: AtlasContentHash.hashJson('Надіслати'),
  _backKey: AtlasContentHash.hashJson('Назад'),
};
const _ownerPath = 'lib/existing_items_owner.dart';
const _widgetSource = 'class ExistingItemsView {}';
const _ownerSource = 'class ExistingItemsOwner {}';
final _manifest = {
  _widgetPath: AtlasContentHash.hashBytes(_widgetSource.codeUnits),
  _ownerPath: AtlasContentHash.hashBytes(_ownerSource.codeUnits),
};
const _mockApiPath = 'lib/support/mock/apis/item/item_mock_api.dart';
const _deviceMockPath =
    'lib/support/mock/apis/device/device_mock_permission_adapter.dart';
const _targetsPath = 'lib/support/automation/targets/shop_flow_target.dart';
const _mockApiSource = 'class ItemMockApi {}';
const _deviceMockSource = 'class DeviceMockPermissionAdapter {}';
const _targetsSource = 'enum QuoteItemTarget { send }';
const _diagnosticsPath = 'lib/app/diagnostics_service.dart';
const _diagnosticsSource = 'class DiagnosticsService {}';
final _mockManifest = {
  _mockApiPath: AtlasContentHash.hashBytes(_mockApiSource.codeUnits),
  _deviceMockPath: AtlasContentHash.hashBytes(_deviceMockSource.codeUnits),
  _targetsPath: AtlasContentHash.hashBytes(_targetsSource.codeUnits),
};
const _targetedWidgetSource = '''
import 'package:flutter_automation/flutter_automation.dart';
import 'package:sample/common/automation/targets/shop_flow_target.dart';

class ExistingItemsView {
  Widget build() {
    return Text(
      'Надіслати',
    ).automationTarget(QuoteItemTarget.send);
  }
}
''';
const _untargetedWidgetSource = '''
class ExistingItemsView {
  Widget build() {
    return Text('Надіслати');
  }
}
''';
const _recordedRequest = {
  'kind': 'request',
  'method': 'GET',
  'path': '/items/creation-limit',
  'status': 200,
};
const _languageRequest = {
  'kind': 'request',
  'method': 'GET',
  'path': '/items/creation-limit',
  'acceptLanguage': 'uk',
  'status': 200,
};
const _failedRequest = {
  'kind': 'request',
  'method': 'GET',
  'path': '/items/creation-limit',
  'status': 500,
};
const _apiEndpointsPath = 'lib/app/data/api_paths.dart';
const _apiTimeoutsPath = 'lib/app/data/api_timeouts.dart';
const _analyticsMapperPath = 'lib/app/data/analytics/analytics_mapper.dart';
const _apiEndpointsSource =
    "class ApiPaths { static const limit = '/items/creation-limit'; }";
const _apiTimeoutsSource = 'class ApiTimeouts { static const seconds = 30; }';
const _analyticsMapperSource = 'class AnalyticsMapper {}';
final _networkManifest = {
  _apiEndpointsPath: AtlasContentHash.hashBytes(_apiEndpointsSource.codeUnits),
  _apiTimeoutsPath: AtlasContentHash.hashBytes(_apiTimeoutsSource.codeUnits),
  _analyticsMapperPath: AtlasContentHash.hashBytes(
    _analyticsMapperSource.codeUnits,
  ),
};
const _settingsTabEvent = {
  'kind': 'analytics',
  'target': 'tracker',
  'name': 'tabbar_settings_tap',
  'parameters': {'screen_name': 'carts-route'},
};
const _searchItemEvent = {
  'kind': 'analytics',
  'target': 'tracker',
  'name': 'find_seller_tap',
  'parameters': {'screen_name': 'carts-route', 'flow_type': 'cart'},
};
const _acceptedEvents = {'tabbar_settings_tap', 'screen_opened'};
const _anchor = '2026-10-03T09:00:00.000Z';
const _analysisTimeout = Timeout(Duration(minutes: 2));
const _packageConfigPath = '.dart_tool/package_config.json';
const _homeViewPath = 'lib/home/home_view.dart';
const _homeOwnerPath = 'lib/home/home_owner.dart';
const _homeOwnerCopyPath = 'lib/other/home_owner.dart';
const _homeViewImports = '''
import 'package:flutter/widgets.dart';
import 'package:sample/home/home_owner.dart';
''';
const _loadHeadingMethod = '  String loadHeading() => _readTitle();';
const _updateTitleMethod = '''
  void updateTitle(String title) {
    _title = title;
  }''';
const _cartsViewPath = 'lib/carts/carts_view.dart';
const _cartsRepositoryImplPath = 'lib/carts/carts_repository_impl.dart';
const _inboxViewPath = 'lib/inbox/inbox_view.dart';
const _dimensPath = 'lib/theme/app_dimens_ext.dart';
const _stageWidgets = [
  ['HomeView'],
  ['CartsView'],
  ['InboxView'],
];
const _endWidgets = ['InboxView'];
const _widgetSources = {
  'lib/di/annotations.dart': '''
class Register {
  final Type? as;

  const Register({this.as});
}

const register = Register();

const bundle = Object();
''',
  'lib/di/locator.dart': '''
class Locator {
  static T find<T>() => throw UnimplementedError();
}
''',
  'pubspec.yaml':
      '''
$testAutomationPubspec
environment:
  sdk: ^3.9.0
''',
  _homeViewPath: '''
import 'package:flutter/widgets.dart';
import 'package:sample/home/home_owner.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Text('home', key: ValueKey(HomeOwner()));
  }
}
''',
  _homeOwnerPath: '''
class HomeOwner {
  String _title = 'home';

  String loadHeading() => _readTitle();

  void updateTitle(String title) {
    _title = title;
  }

  String _readTitle() => _title;
}
''',
  _cartsViewPath: '''
import 'package:flutter/widgets.dart';
import 'package:sample/di/locator.dart';
import 'package:sample/theme/app_dimens_ext.dart';

class CartsView extends StatelessWidget {
  const CartsView({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.appDimensExt.gapLg,
      child: Text(CartsOwner().loadTitle()),
    );
  }
}

class CartsOwner extends CartsTitleSource {
  final _repository = Locator.find<CartsRepository>();

  @override
  String loadTitle() => _repository.readTitle();
}

class CartsTitleSource {
  String loadTitle() => '';
}

abstract interface class CartsRepository {
  String readTitle();
}
''',
  _cartsRepositoryImplPath: '''
import 'package:sample/carts/carts_view.dart';
import 'package:sample/di/annotations.dart';

@Register(as: CartsRepository)
class CartsRepositoryImpl implements CartsRepository {
  @override
  String readTitle() => const CartsMapper().mapTitle();
}

class CartsMapper {
  const CartsMapper();

  String mapTitle() => 'carts';
}

class CartsHint {}
''',
  _inboxViewPath: '''
import 'package:flutter/widgets.dart';
import 'package:sample/home/home_owner.dart';
import 'package:sample/theme/app_dimens_ext.dart';

class InboxView extends StatefulWidget {
  const InboxView({super.key});

  @override
  State<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<InboxView> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.appDimensExt.gapSm,
      child: Text(HomeOwner().loadHeading()),
    );
  }
}
''',
  _dimensPath: '''
import 'package:flutter/widgets.dart';

class AppDimensExt {
  final double gapLg;
  final double gapSm;

  const AppDimensExt({required this.gapLg, required this.gapSm});
}

extension AppDimensExtBuildContext on BuildContext {
  AppDimensExt get appDimensExt => throw UnimplementedError();
}
''',
};
const _mockDifference = 'GET /items/creation-limit status 200, now 500';
const _changedOwnerSource = 'class ExistingItemsOwner { int a = 0; }';
const _snapshotCommit = 'c0ffee000000';
const _otherCommit = 'decaf0000000';
const _appSetupPath = 'lib/app/app_setup.dart';
const _systemSettingsSource = '''
abstract final class AppSetup {
  static Future<void> initialize() async {}

  static Future<String> resolveLanguage() async => 'uk';
}
''';
const _changedInitializeSource = '''
abstract final class AppSetup {
  static Future<void> initialize() async => print('');

  static Future<String> resolveLanguage() async => 'uk';
}
''';
const _changedStartLanguageSource = '''
abstract final class AppSetup {
  static Future<void> initialize() async {}

  static Future<String> resolveLanguage() async => 'en';
}
''';
const _frameHashes = ['a1b2c3d4e5f6', 'b2c3d4e5f6a1', 'c3d4e5f6a1b2'];
const _changedStageHashes = ['a1b2c3d4e5f6', 'ffffffffffff', 'c3d4e5f6a1b2'];
const _changedLastStageHashes = [
  'a1b2c3d4e5f6',
  'b2c3d4e5f6a1',
  'ffffffffffff',
];
const _endFrameHash = 'd4e5f6a1b2c3';
const _otherEndFrameHash = 'ffffffffffff';
const _walkToken = 'atlas-headless:tok-install';
const _walkTokenSubscription = {
  'kind': 'request',
  'method': 'POST',
  'path': '/notifications/toggle-subscribe/device',
  'acceptLanguage': 'uk',
  'body': {'token': _walkToken},
  'status': 200,
};
const _recordedMediaId = '975f305f-aeba-4e77-8109-1c54fd02d19c';
const _baselineMediaId = '2f476b8f-1b80-452e-8264-4c3eebe3d2ac';
const _currentMediaId = '0fb39a87-0a41-441f-990d-13310d8d3d92';
const _okStatus = 200;
const _otherRenderer = 'Flutter 3.41.0 · linux_x64';
const _walkedChannelReadStage = 1;
const _recordedChannelReadStage = 2;
const _channelReadRecords = [
  {
    'kind': 'socket',
    'method': 'POST',
    'path': '/inbox/threads/mock-cart-9001/read',
    'query': {'api_key': 'mock-api-key', 'user_id': 'user_1'},
    'body': <String, Object?>{},
    'status': _okStatus,
  },
  {
    'kind': 'inbox',
    'call': 'unreadCount',
    'totalUnreadMessages': 0,
    'totalUnreadChannels': 0,
  },
  {
    'kind': 'inbox',
    'call': 'channelPreviews',
    'threadIds': ['inbox:mock-cart-9001'],
  },
];

void main() {
  group('AtlasStaleCheck Tests', () {
    _atlasStaleCheck_should_reportNewWithoutSnapshot();
    _atlasStaleCheck_should_reportDefinitionWhenDefHashDiffers();
    _atlasStaleCheck_should_reportFailedBeforeChangedCode();
    _atlasStaleCheck_should_reportManifestWithoutOne();
    _atlasStaleCheck_should_reportCodeWithChangedAndDeletedPaths();
    _atlasStaleCheck_should_reportFreshWhenNothingChanged();
    _atlasStaleCheck_should_reportStagesFromFirstChangedStepHash();
    _atlasStaleCheck_should_reportStagesAddedAtTheEnd();
    _atlasStaleCheck_should_reportChangedMiddleStageAndStagesAfterIt();
    _atlasStaleCheck_should_reportDefinitionWhenStagesAreRemoved();
    _atlasStaleCheck_should_reportStageCodeWithTheStageBeforeIt();
    _atlasStaleCheck_should_reportEveryStageForPathOutsideStage();
    _atlasStaleCheck_should_reportLocaleForChangedAndDeletedKeys();
    _atlasStaleCheck_should_readSnapshotAndValuesOfItsLocale();
    _atlasStaleCheck_should_reportLastStageForChangedKeyOfTheEnd();
    _atlasStaleCheck_should_reportFreshWhenReplayedMockAnswersAlike();
    _atlasStaleCheck_should_reportStageMockFromStageBeforeDifference();
    _atlasStaleCheck_should_replayEverySnapshotTheStagesCanPlace();
    _atlasStaleCheck_should_ignoreChangedDeviceMock();
    _atlasStaleCheck_should_reportFreshForChangedTargetEnum();
    _atlasStaleCheck_should_reportFreshForTargetOnlyEdit();
    _atlasStaleCheck_should_reportFreshForChangedDiagnostics();
    _atlasStaleCheck_should_reportStageCodeForRealEditBesideTarget();
    _atlasStaleCheck_should_reportStageMockForChangedRequestPath();
    _atlasStaleCheck_should_reportEveryStageForChangedApiTimeouts();
    _atlasStaleCheck_should_reportFreshForChangedAnalyticsMapper();
    _atlasStaleCheck_should_reportStageAnalyticsForUncataloguedEvent();
    _atlasStaleCheck_should_reportFreshForEventWithBaseParameters();
    _atlasStaleCheck_should_reportStagesShowingRenamedThemeField();
    _atlasStaleCheck_should_reportEveryStageForAddedThemeFieldNoStageReads();
    _atlasStaleCheck_should_reportStageReadingAddedThemeField();
    _atlasStaleCheck_should_reportEveryStageForAddedUnreachedTheme();
    _atlasStaleCheck_should_reportStagesFromFirstReachingDi();
    _atlasStaleCheck_should_reportStagesShowingWidgetWithAddedMember();
    _atlasStaleCheck_should_reportStageWithoutWidgetsBySources();
    _atlasStaleCheck_should_reportEveryStageForUnreachedDeclaration();
    _atlasStaleCheck_should_reportEveryStageForSnapshotWithoutWidgets();
    _atlasStaleCheck_should_reportEveryStageForRenamedStageWidget();
    _atlasStaleCheck_should_reportFreshForDeletedUnusedDeclaration();
    _atlasStaleCheck_should_reportStagesShowingWidgetOfDeletedFile();
    _atlasStaleCheck_should_reportFreshForReorderedImport();
    _atlasStaleCheck_should_reportFreshForReorderedMethod();
    _atlasStaleCheck_should_reportStagesOfFileUsingNameDeclaredTwice();
    _atlasStaleCheck_should_reportStagesCallingChangedPrivateMethod();
    _atlasStaleCheck_should_reportStagesReachingNameOfRemovedMember();
    _atlasStaleCheck_should_reportFreshForCodeStagesOfBaselineHashes();
    _atlasStaleCheck_should_keepStageWhoseHashDiffersFromBaseline();
    _atlasStaleCheck_should_keepLastStageWhoseEndFrameDiffers();
    _atlasStaleCheck_should_reportStageJournalForJournalBaseline();
    _atlasStaleCheck_should_keepStageCodeForJournalBaselineDoesNotReproduce();
    _atlasStaleCheck_should_reportFreshForCodeStagesOfHeadlessHashes();
    _atlasStaleCheck_should_keepStageWhoseFrameDiffersFromHeadless();
    _atlasStaleCheck_should_reportStageJournalForJournalHeadlessHash();
    _atlasStaleCheck_should_compareWithBaselineForHashesOfOtherRenderer();
    _atlasStaleCheck_should_reportFreshForJournalShiftedAsHeadless();
    _atlasStaleCheck_should_readNoBaselineForStagelessSnapshotOfEnd();
    _atlasStaleCheck_should_compareLastStageWithBaselineForEnd();
    _atlasStaleCheck_should_keepStageOfWalkTokenForCapture();
    _atlasStaleCheck_should_keepWalkIdsOfUnprovenVariantForCapture();
    _atlasStaleCheck_should_reportFreshForStagelessWalkShownAlike();
    _atlasStaleCheck_should_reportFreshForStagelessWalkJournaling();
    _atlasStaleCheck_should_reportCodeForStagelessWalkEnding();
    _atlasStaleCheck_should_keepStagesWithoutBaselineReport();
    _atlasStaleCheck_should_keepStagesOfChangedStubbedDeclaration();
    _atlasStaleCheck_should_reportFreshForChangedKeptDeclaration();
    _atlasStaleCheck_should_keepStagesOfReportWalkedOnOtherSources();
    _atlasStaleCheck_should_keepStagesOfBaselineOnOtherCommit();
    _atlasStaleCheck_should_reportFreshForUnreachedThemeFieldOfBaselineHashes();
  });
}

void _atlasStaleCheck_should_reportNewWithoutSnapshot() {
  test('AtlasStaleCheck should report new without snapshot', () async {
    await TestAtlasRoot.run((root) async {
      _writeFlow(root);

      final staleness = await _check(root);

      expect(staleness.reason, AtlasStaleReason.noSnapshot);
      expect(staleness.isStale, isTrue);
      expect(staleness.describe(), 'shop_flow shopFromExistingItem new');
    });
  });
}

void _atlasStaleCheck_should_reportDefinitionWhenDefHashDiffers() {
  test(
    'AtlasStaleCheck should report definition when def hash differs',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeFlow(root);
        _writeSnapshot(root, defHash: '000000000000');

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.definition);
        expect(
          staleness.describe(),
          'shop_flow shopFromExistingItem definition',
        );
      });
    },
  );
}

void _atlasStaleCheck_should_reportFailedBeforeChangedCode() {
  test('AtlasStaleCheck should report failed before changed code', () async {
    await TestAtlasRoot.run((root) async {
      _writeFlow(root);
      _writeSnapshot(root, isOk: false);
      root.writeSource(_widgetPath, 'class ExistingItemsView { int a = 0; }');

      final staleness = await _check(root);

      expect(staleness.reason, AtlasStaleReason.failed);
      expect(staleness.isStale, isTrue);
      expect(staleness.describe(), 'shop_flow shopFromExistingItem failed');
    });
  });
}

void _atlasStaleCheck_should_reportManifestWithoutOne() {
  test('AtlasStaleCheck should report manifest without one', () async {
    await TestAtlasRoot.run((root) async {
      _writeFlow(root);
      _writeSnapshot(root, hasManifest: false);

      final staleness = await _check(root);

      expect(staleness.reason, AtlasStaleReason.noManifest);
      expect(staleness.isStale, isTrue);
      expect(staleness.changedPaths, isEmpty);
      expect(staleness.describe(), 'shop_flow shopFromExistingItem manifest');
    });
  });
}

void _atlasStaleCheck_should_reportCodeWithChangedAndDeletedPaths() {
  test(
    'AtlasStaleCheck should report code with changed and deleted paths',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeFlow(root);
        _writeSnapshot(root);

        root
          ..writeSource(_widgetPath, 'class ExistingItemsView { int a = 0; }')
          ..deleteSource(_ownerPath);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.code);
        expect(staleness.changedPaths, ['$_ownerPath (deleted)', _widgetPath]);
        expect(
          staleness.describe(),
          'shop_flow shopFromExistingItem code '
          '$_ownerPath (deleted), $_widgetPath',
        );
      });
    },
  );
}

void _atlasStaleCheck_should_reportFreshWhenNothingChanged() {
  test('AtlasStaleCheck should report fresh when nothing changed', () async {
    await TestAtlasRoot.run((root) async {
      _writeFlow(root);
      _writeSnapshot(root);

      final staleness = await _check(root);

      expect(staleness.reason, AtlasStaleReason.fresh);
      expect(staleness.isStale, isFalse);
    });
  });
}

void _atlasStaleCheck_should_reportStagesFromFirstChangedStepHash() {
  test(
    'AtlasStaleCheck should report stages from first changed step hash',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(
          root,
          defHash: '000000000000',
          changedStepHashStage: 1,
        );

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageDefinition);
        expect(staleness.stages, [0, 1, 2]);
        expect(
          staleness.describe(),
          'shop_flow shopFromExistingItem stage definition 0,1,2',
        );
      });
    },
  );
}

void _atlasStaleCheck_should_reportStagesAddedAtTheEnd() {
  test('AtlasStaleCheck should report stages added at the end', () async {
    await TestAtlasRoot.run((root) async {
      _writeStagedFlow(root);
      _writeStagedSnapshot(root);
      _writeStagedFlow(root, labels: [..._stagedLabels, _addedLabel]);

      final staleness = await _check(root);

      expect(staleness.reason, AtlasStaleReason.stageDefinition);
      expect(staleness.stages, [2, 3]);
    });
  });
}

void _atlasStaleCheck_should_reportChangedMiddleStageAndStagesAfterIt() {
  test(
    'AtlasStaleCheck should report changed middle stage and stages after it',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root, changedStepHashStage: 1);
        _writeStagedFlow(root, labels: [..._stagedLabels, _addedLabel]);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageDefinition);
        expect(staleness.stages, [0, 1, 2, 3]);
      });
    },
  );
}

void _atlasStaleCheck_should_reportDefinitionWhenStagesAreRemoved() {
  test(
    'AtlasStaleCheck should report definition when stages are removed',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        _writeStagedFlow(
          root,
          labels: _stagedLabels.take(_stagedLabels.length - 1).toList(),
        );

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.definition);
        expect(staleness.stages, isEmpty);
      });
    },
  );
}

void _atlasStaleCheck_should_reportStageCodeWithTheStageBeforeIt() {
  test(
    'AtlasStaleCheck should report stage code with the stage before it',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        root.writeSource(_widgetPath, 'class ExistingItemsView { int a = 0; }');

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [1, 2]);
        expect(
          staleness.describe(),
          'shop_flow shopFromExistingItem stage code 1,2 $_widgetPath',
        );
      });
    },
  );
}

void _atlasStaleCheck_should_reportEveryStageForPathOutsideStage() {
  test(
    'AtlasStaleCheck should report every stage for path outside stage',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        root.writeSource(_ownerPath, 'class ExistingItemsOwner { int a = 0; }');

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0, 1, 2]);
        expect(
          staleness.describe(),
          'shop_flow shopFromExistingItem stage code 0,1,2 '
          '[every stage by $_ownerPath]',
        );
      });
    },
  );
}

void _atlasStaleCheck_should_reportLocaleForChangedAndDeletedKeys() {
  test(
    'AtlasStaleCheck should report locale for changed and deleted keys',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        root.writeTranslations('uk', {_sendKey: 'Надіслати запит'});

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.locale);
        expect(staleness.stages, [1]);
        expect(
          staleness.describe(),
          'shop_flow shopFromExistingItem locale 1 '
          'locale $_backKey (deleted), $_sendKey',
        );
      });
    },
  );
}

void _atlasStaleCheck_should_readSnapshotAndValuesOfItsLocale() {
  test(
    'AtlasStaleCheck should read snapshot and values of its locale',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        _writeStagedSnapshot(root, locale: _en);
        root.writeTranslations('en', {_sendKey: 'Send', _backKey: 'Назад'});

        final enStaleness = await _check(root, locale: _en);

        expect(enStaleness.reason, AtlasStaleReason.locale);
        expect(enStaleness.changedTranslationKeys, [_sendKey]);
        expect((await _check(root)).reason, AtlasStaleReason.fresh);
      });
    },
  );
}

void _atlasStaleCheck_should_reportLastStageForChangedKeyOfTheEnd() {
  test(
    'AtlasStaleCheck should report last stage for changed key of the end',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(
          root,
          endTextKeys: {_doneKey: AtlasContentHash.hashJson('Готово')},
        );
        root.writeTranslations('uk', {
          _sendKey: 'Надіслати',
          _backKey: 'Назад',
          _doneKey: 'Пропозицію надіслано',
        });

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.locale);
        expect(staleness.stages, [_stagedLabels.length - 1]);
        expect(staleness.changedTranslationKeys, [_doneKey]);
      });
    },
  );
}

void _atlasStaleCheck_should_reportFreshWhenReplayedMockAnswersAlike() {
  test(
    'AtlasStaleCheck should report fresh when replayed mock answers alike',
    () async {
      await TestAtlasRoot.run((root) async {
        final replay = _FakeMockReplay();

        _writeStagedFlow(root);
        _writeStagedSnapshot(root, extraManifest: _mockManifest);
        root.writeSource(_mockApiPath, 'class ItemMockApi { int a = 0; }');

        final staleness = await _check(root, mockReplay: replay);

        expect(staleness.reason, AtlasStaleReason.fresh);
        expect(replay.inputs.map((input) => input.id), [staleness.variant.id]);
        expect(replay.inputs.single.answers.map((request) => request.stage), [
          1,
        ]);
      });
    },
  );
}

void _atlasStaleCheck_should_reportStageMockFromStageBeforeDifference() {
  test(
    'AtlasStaleCheck should report stage mock from stage before difference',
    () async {
      await TestAtlasRoot.run((root) async {
        final replay = _FakeMockReplay(
          outcome: const AtlasMockReplayOutcome(
            stage: 1,
            difference: _mockDifference,
          ),
        );

        _writeStagedFlow(root);
        _writeStagedSnapshot(root, extraManifest: _mockManifest);
        root.writeSource(_mockApiPath, 'class ItemMockApi { int a = 0; }');

        final staleness = await _check(root, mockReplay: replay);

        expect(staleness.reason, AtlasStaleReason.stageMock);
        expect(staleness.stages, [0, 1, 2]);
        expect(staleness.changedPaths, isEmpty);
        expect(
          staleness.describe(),
          'shop_flow shopFromExistingItem stage mock 0,1,2 '
          'mock $_mockDifference',
        );
      });
    },
  );
}

void _atlasStaleCheck_should_replayEverySnapshotTheStagesCanPlace() {
  test(
    'AtlasStaleCheck should replay every snapshot the stages can place',
    () async {
      await TestAtlasRoot.run((root) async {
        final replay = _FakeMockReplay();

        _writeStagedFlow(root);
        _writeStagedSnapshot(root, extraManifest: _mockManifest);

        final staleness = await _check(root, mockReplay: replay);

        expect(staleness.reason, AtlasStaleReason.fresh);
        expect(replay.inputs.map((input) => input.id), [staleness.variant.id]);
      });
    },
  );
}

void _atlasStaleCheck_should_ignoreChangedDeviceMock() {
  test('AtlasStaleCheck should ignore changed device mock', () async {
    await TestAtlasRoot.run((root) async {
      _writeStagedFlow(root);
      _writeStagedSnapshot(root, extraManifest: _mockManifest, anchor: _anchor);
      root.writeSource(
        _deviceMockPath,
        'class DeviceMockPermissionAdapter { int a = 0; }',
      );

      final staleness = await _check(root);

      expect(staleness.reason, AtlasStaleReason.fresh);
      expect(staleness.changedPaths, isEmpty);
    });
  });
}

void _atlasStaleCheck_should_reportFreshForChangedTargetEnum() {
  test('AtlasStaleCheck should report fresh for changed target enum', () async {
    await TestAtlasRoot.run((root) async {
      _writeStagedFlow(root);
      _writeStagedSnapshot(root, extraManifest: _mockManifest);
      root.writeSource(_targetsPath, 'enum QuoteItemTarget { send, back }');

      final staleness = await _check(root, mockReplay: _FakeMockReplay());

      expect(staleness.reason, AtlasStaleReason.fresh);
    });
  });
}

void _atlasStaleCheck_should_reportFreshForTargetOnlyEdit() {
  test('AtlasStaleCheck should report fresh for target only edit', () async {
    await TestAtlasRoot.run((root) async {
      _writeStagedFlow(root);
      _writeStagedSnapshot(root, widgetSource: _untargetedWidgetSource);
      root.writeSource(_widgetPath, _targetedWidgetSource);

      final staleness = await _check(root);

      expect(staleness.reason, AtlasStaleReason.fresh);
    });
  });
}

void _atlasStaleCheck_should_reportFreshForChangedDiagnostics() {
  test('AtlasStaleCheck should report fresh for changed diagnostics', () async {
    await TestAtlasRoot.run((root) async {
      _writeStagedFlow(root);
      _writeStagedSnapshot(
        root,
        extraManifest: {
          _diagnosticsPath: AtlasContentHash.hashBytes(
            _diagnosticsSource.codeUnits,
          ),
        },
      );
      root.writeSource(
        _diagnosticsPath,
        'class DiagnosticsService { void report() {} }',
      );

      final staleness = await _check(root, mockReplay: _FakeMockReplay());

      expect(staleness.reason, AtlasStaleReason.fresh);
    });
  });
}

void _atlasStaleCheck_should_reportStageCodeForRealEditBesideTarget() {
  test(
    'AtlasStaleCheck should report stage code for real edit beside target',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root, widgetSource: _untargetedWidgetSource);
        root.writeSource(
          _widgetPath,
          _targetedWidgetSource.replaceFirst('Надіслати', 'Відправити'),
        );

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.changedPaths, [_widgetPath]);
      });
    },
  );
}

void _atlasStaleCheck_should_reportStageMockForChangedRequestPath() {
  test(
    'AtlasStaleCheck should report stage mock for changed request path',
    () async {
      await TestAtlasRoot.run((root) async {
        final replay = _FakeMockReplay(
          outcome: const AtlasMockReplayOutcome(
            stage: 1,
            difference: _mockDifference,
          ),
        );

        _writeStagedFlow(root);
        _writeStagedSnapshot(root, extraManifest: _networkManifest);
        root.writeSource(
          _apiEndpointsPath,
          _apiEndpointsSource.replaceFirst('creation-limit', 'limit'),
        );

        final staleness = await _check(root, mockReplay: replay);

        expect(staleness.reason, AtlasStaleReason.stageMock);
        expect(staleness.stages, [0, 1, 2]);
        expect(staleness.changedPaths, isEmpty);
        expect(replay.inputs.map((input) => input.id), [staleness.variant.id]);
      });
    },
  );
}

void _atlasStaleCheck_should_reportEveryStageForChangedApiTimeouts() {
  test(
    'AtlasStaleCheck should report every stage for changed api timeouts',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root, extraManifest: _networkManifest);
        root.writeSource(
          _apiTimeoutsPath,
          _apiTimeoutsSource.replaceFirst('30', '60'),
        );

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.unattributedPaths, [_apiTimeoutsPath]);
      });
    },
  );
}

void _atlasStaleCheck_should_reportFreshForChangedAnalyticsMapper() {
  test(
    'AtlasStaleCheck should report fresh for changed analytics mapper',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root, extraManifest: _networkManifest);
        root.writeSource(
          _analyticsMapperPath,
          'class AnalyticsMapper { int a = 0; }',
        );

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.fresh);
        expect(staleness.changedPaths, isEmpty);
      });
    },
  );
}

void _atlasStaleCheck_should_reportStageAnalyticsForUncataloguedEvent() {
  test(
    'AtlasStaleCheck should report stage analytics for uncatalogued event',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(
          root,
          addedRecords: const {
            1: [_searchItemEvent],
            2: [_settingsTabEvent],
          },
        );
        root.project.acceptedEvents.addAll(_acceptedEvents);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageAnalytics);
        expect(staleness.stages, [1]);
        expect(
          staleness.describe(),
          'shop_flow shopFromExistingItem stage analytics 1',
        );
      });
    },
  );
}

void _atlasStaleCheck_should_reportFreshForEventWithBaseParameters() {
  test(
    'AtlasStaleCheck should report fresh for event with base parameters',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(
          root,
          addedRecords: const {
            1: [_settingsTabEvent],
          },
        );
        root.project.acceptedEvents.addAll(_acceptedEvents);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.fresh);
      });
    },
  );
}

void _atlasStaleCheck_should_reportStagesShowingRenamedThemeField() {
  test(
    'AtlasStaleCheck should report stages showing renamed theme field',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root);
        _replaceSource(root, _dimensPath, 'gapLg', 'gapXl');
        _replaceSource(root, _cartsViewPath, 'gapLg', 'gapXl');

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0, 1]);
        expect(staleness.changedPaths, [_cartsViewPath, _dimensPath]);
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStaleCheck_should_reportEveryStageForAddedThemeFieldNoStageReads() {
  test(
    'AtlasStaleCheck should report every stage for added theme field no stage '
    'reads',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root);
        _addDimensField(root);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0, 1, 2]);
        expect(staleness.unattributedPaths, [_dimensPath]);
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStaleCheck_should_reportStageReadingAddedThemeField() {
  test(
    'AtlasStaleCheck should report stage reading added theme field',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root);
        _addDimensField(root);
        _replaceSource(root, _cartsViewPath, 'gapLg', 'gapXs');

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0, 1]);
        expect(staleness.attributedPaths[_dimensPath], {1});
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStaleCheck_should_reportEveryStageForAddedUnreachedTheme() {
  test(
    'AtlasStaleCheck should report every stage for added unreached theme',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root);
        _replaceSource(
          root,
          _dimensPath,
          'extension AppDimensExtBuildContext',
          'class AppSpacingExt {\n  final double gapXs = 0;\n}\n\n'
              'extension AppDimensExtBuildContext',
        );

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0, 1, 2]);
        expect(staleness.unattributedPaths, [_dimensPath]);
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStaleCheck_should_reportStagesFromFirstReachingDi() {
  test('AtlasStaleCheck should report stages from first reaching di', () async {
    await TestAtlasRoot.run((root) async {
      _writeWidgetsSnapshotWithoutSources(root);
      _replaceSource(root, _cartsRepositoryImplPath, "'carts'", "'my carts'");

      final staleness = await _check(root);

      expect(staleness.reason, AtlasStaleReason.stageCode);
      expect(staleness.stages, [0, 1, 2]);
    });
  }, timeout: _analysisTimeout);
}

void _atlasStaleCheck_should_reportStagesShowingWidgetWithAddedMember() {
  test(
    'AtlasStaleCheck should report stages showing widget with added member',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root);
        _addInboxInitState(root);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [1, 2]);
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStaleCheck_should_reportStageWithoutWidgetsBySources() {
  test(
    'AtlasStaleCheck should report stage without widgets by sources',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root, stageWithoutWidgets: 0);
        _addInboxInitState(root);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0, 1, 2]);
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStaleCheck_should_reportEveryStageForUnreachedDeclaration() {
  test(
    'AtlasStaleCheck should report every stage for unreached declaration',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root);
        _replaceSource(
          root,
          _homeViewPath,
          'class HomeView',
          'class HomeHint {}\n\nclass HomeView',
        );
        _replaceSource(
          root,
          _homeOwnerPath,
          '_readTitle() => _title;',
          '_readTitle() => _title.trim();',
        );

        final mockReplay = _FakeMockReplay();

        final staleness = await _check(root, mockReplay: mockReplay);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0, 1, 2]);
        expect(staleness.attributedPaths[_homeOwnerPath], {2});
        expect(mockReplay.inputs, isEmpty);
        expect(
          staleness.describe(),
          'shop_flow shopFromExistingItem stage code 0,1,2 '
          '[every stage by $_homeViewPath] $_homeOwnerPath',
        );
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStaleCheck_should_reportEveryStageForSnapshotWithoutWidgets() {
  test(
    'AtlasStaleCheck should report every stage for snapshot without widgets',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root, hasWidgets: false);
        File(root.paths.resolve(_packageConfigPath)).deleteSync();
        _replaceSource(root, _dimensPath, 'gapLg', 'gapXl');
        _replaceSource(root, _cartsViewPath, 'gapLg', 'gapXl');

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0, 1, 2]);
        expect(staleness.unattributedPaths, [_cartsViewPath, _dimensPath]);
      });
    },
  );
}

void _atlasStaleCheck_should_reportEveryStageForRenamedStageWidget() {
  test(
    'AtlasStaleCheck should report every stage for renamed stage widget',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root);
        _replaceSource(root, _inboxViewPath, 'InboxView', 'InboxPanel');

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0, 1, 2]);
        expect(staleness.unattributedPaths, [_inboxViewPath]);
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStaleCheck_should_reportFreshForDeletedUnusedDeclaration() {
  test(
    'AtlasStaleCheck should report fresh for deleted unused declaration',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root);
        _replaceSource(
          root,
          _cartsRepositoryImplPath,
          '\nclass CartsHint {}\n',
          '',
        );

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.fresh);
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStaleCheck_should_reportStagesShowingWidgetOfDeletedFile() {
  test(
    'AtlasStaleCheck should report stages showing widget of deleted file',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root);
        root.deleteSource(_inboxViewPath);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [1, 2]);
        expect(staleness.changedPaths, ['$_inboxViewPath (deleted)']);
        expect(staleness.unattributedPaths, isEmpty);
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStaleCheck_should_reportFreshForReorderedImport() {
  test('AtlasStaleCheck should report fresh for reordered import', () async {
    await TestAtlasRoot.run((root) async {
      _writeWidgetsSnapshotWithoutSources(root);
      _reorderHomeViewImports(root);

      final staleness = await _check(root);

      expect(staleness.reason, AtlasStaleReason.fresh);
      expect(staleness.attributedPaths[_homeViewPath], isEmpty);
    });
  }, timeout: _analysisTimeout);
}

void _atlasStaleCheck_should_reportFreshForReorderedMethod() {
  test('AtlasStaleCheck should report fresh for reordered method', () async {
    await TestAtlasRoot.run((root) async {
      _writeWidgetsSnapshotWithoutSources(root);
      _replaceSource(
        root,
        _homeOwnerPath,
        '$_loadHeadingMethod\n\n$_updateTitleMethod',
        '$_updateTitleMethod\n\n$_loadHeadingMethod',
      );

      final staleness = await _check(root);

      expect(staleness.reason, AtlasStaleReason.fresh);
    });
  }, timeout: _analysisTimeout);
}

void _atlasStaleCheck_should_reportStagesOfFileUsingNameDeclaredTwice() {
  test(
    'AtlasStaleCheck should report stages of file using name declared twice',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root);
        root.writeSource(_homeOwnerCopyPath, 'class HomeOwner {}');
        _reorderHomeViewImports(root);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0]);
        expect(staleness.changedPaths, [_homeViewPath]);
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStaleCheck_should_reportStagesCallingChangedPrivateMethod() {
  test(
    'AtlasStaleCheck should report stages calling changed private method',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root);
        _replaceSource(
          root,
          _homeOwnerPath,
          '_readTitle() => _title;',
          '_readTitle() => _title.trim();',
        );

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [1, 2]);
        expect(staleness.changedPaths, [_homeOwnerPath]);
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStaleCheck_should_reportStagesReachingNameOfRemovedMember() {
  test(
    'AtlasStaleCheck should report stages reaching name of removed member',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root);
        _replaceSource(root, _cartsViewPath, '''
  @override
  String loadTitle() => _repository.readTitle();
''', '');

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0, 1]);
        expect(staleness.changedPaths, [_cartsViewPath]);
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStaleCheck_should_reportFreshForCodeStagesOfBaselineHashes() {
  test(
    'AtlasStaleCheck should report fresh for code stages of baseline hashes',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(root);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.fresh);
        expect(staleness.describe(), 'shop_flow shopFromExistingItem fresh');
      });
    },
  );
}

void _atlasStaleCheck_should_keepStageWhoseHashDiffersFromBaseline() {
  test(
    'AtlasStaleCheck should keep stage whose hash differs from baseline',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(root, currentStageHashes: _changedStageHashes);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [1]);
      });
    },
  );
}

void _atlasStaleCheck_should_keepLastStageWhoseEndFrameDiffers() {
  test(
    'AtlasStaleCheck should keep last stage whose end frame differs',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(root, currentEndFrameHash: 'ffffffffffff');

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [2]);
      });
    },
  );
}

void _atlasStaleCheck_should_reportStageJournalForJournalBaseline() {
  test(
    'AtlasStaleCheck should report stage journal for journal baseline',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(
          root,
          currentJournals: {
            1: [_languageRequest],
          },
        );

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageJournal);
        expect(staleness.stages, [1]);
        expect(staleness.journalStages, [1]);
        expect(
          staleness.describe(),
          'shop_flow shopFromExistingItem stage journal 1',
        );
      });
    },
  );
}

void _atlasStaleCheck_should_keepStageCodeForJournalBaselineDoesNotReproduce() {
  test('AtlasStaleCheck should keep stage code for journal baseline does not '
      'reproduce', () async {
    await TestAtlasRoot.run((root) async {
      _writeStagedFlow(root);
      _writeStagedSnapshot(root);
      root.writeSource(_ownerPath, _changedOwnerSource);
      _writeHeadlessReports(
        root,
        currentJournals: {
          1: [_languageRequest],
        },
        baselineJournals: {
          1: [_failedRequest],
        },
      );

      final staleness = await _check(root);

      expect(staleness.reason, AtlasStaleReason.stageCode);
      expect(staleness.stages, [1]);
      expect(staleness.journalStages, isEmpty);
      expect(staleness.journalDifferences, {
        1: 'request GET /items/creation-limit status',
      });
    });
  });
}

void _atlasStaleCheck_should_reportFreshForCodeStagesOfHeadlessHashes() {
  test(
    'AtlasStaleCheck should report fresh for code stages of headless hashes',
    () async {
      await TestAtlasRoot.run((root) async {
        final snapshotCommitReads = <String>[];

        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        root.writeFlutterConfig();
        _writeHeadlessHashes(root);
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(root, hasBaseline: false);

        final staleness = await _check(
          root,
          snapshotCommitReads: snapshotCommitReads,
        );

        expect(staleness.reason, AtlasStaleReason.fresh);
        expect(snapshotCommitReads, isEmpty);
      });
    },
  );
}

void _atlasStaleCheck_should_keepStageWhoseFrameDiffersFromHeadless() {
  test(
    'AtlasStaleCheck should keep stage whose frame differs from headless',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        root.writeFlutterConfig();
        _writeHeadlessHashes(root, frameHashes: _changedStageHashes);
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(root);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [1]);
      });
    },
  );
}

void _atlasStaleCheck_should_reportStageJournalForJournalHeadlessHash() {
  test(
    'AtlasStaleCheck should report stage journal for journal headless hash',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        root.writeFlutterConfig();
        _writeHeadlessHashes(root);
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(
          root,
          currentJournals: {
            1: [_languageRequest],
          },
          hasBaseline: false,
        );

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageJournal);
        expect(staleness.stages, [1]);
        expect(staleness.journalStages, [1]);
      });
    },
  );
}

void _atlasStaleCheck_should_compareWithBaselineForHashesOfOtherRenderer() {
  test(
    'AtlasStaleCheck should compare with baseline for headless hashes of other '
    'renderer',
    () async {
      await TestAtlasRoot.run((root) async {
        final snapshotCommitReads = <String>[];

        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        root.writeFlutterConfig();
        _writeHeadlessHashes(
          root,
          frameHashes: _changedStageHashes,
          renderer: _otherRenderer,
        );
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(root);

        final staleness = await _check(
          root,
          snapshotCommitReads: snapshotCommitReads,
        );

        expect(staleness.reason, AtlasStaleReason.fresh);
        expect(snapshotCommitReads, hasLength(1));
      });
    },
  );
}

void _atlasStaleCheck_should_reportFreshForJournalShiftedAsHeadless() {
  test(
    'AtlasStaleCheck should report fresh for journal shifted as headless',
    () async {
      await TestAtlasRoot.run((root) async {
        const walkedJournals = {
          _walkedChannelReadStage: [_recordedRequest, ..._channelReadRecords],
          _recordedChannelReadStage: <Object?>[],
        };

        _writeStagedFlow(root);
        _writeStagedSnapshot(
          root,
          addedRecords: {_recordedChannelReadStage: _channelReadRecords},
        );
        root.writeFlutterConfig();
        _writeHeadlessHashes(root, journalsByStage: walkedJournals);
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(
          root,
          currentJournals: walkedJournals,
          hasBaseline: false,
        );

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.fresh);
      });
    },
  );
}

void _atlasStaleCheck_should_readNoBaselineForStagelessSnapshotOfEnd() {
  test(
    'AtlasStaleCheck should read no baseline for stageless snapshot of end',
    () async {
      await TestAtlasRoot.run((root) async {
        final snapshotCommitReads = <String>[];

        _writeFlow(root);
        _writeSnapshot(root);
        root.writeFlutterConfig();
        _writeHeadlessHashes(
          root,
          frameHashes: const [],
          endFrameHash: _otherEndFrameHash,
        );
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(
          root,
          currentStageHashes: const [],
          currentEndFrameHash: _otherEndFrameHash,
        );

        final staleness = await _check(
          root,
          snapshotCommitReads: snapshotCommitReads,
        );

        expect(staleness.reason, AtlasStaleReason.fresh);
        expect(snapshotCommitReads, isEmpty);
      });
    },
  );
}

void _atlasStaleCheck_should_compareLastStageWithBaselineForEnd() {
  test(
    'AtlasStaleCheck should compare last stage with baseline for end',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        root.writeFlutterConfig();
        _writeHeadlessHashes(
          root,
          frameHashes: _changedLastStageHashes,
          endFrameHash: null,
        );
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(
          root,
          currentStageHashes: _changedLastStageHashes,
        );

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [2]);
      });
    },
  );
}

void _atlasStaleCheck_should_keepStageOfWalkTokenForCapture() {
  test('AtlasStaleCheck should keep stage of walk token for capture', () async {
    await TestAtlasRoot.run((root) async {
      _writeStagedFlow(root);
      _writeStagedSnapshot(root);
      root.writeSource(_ownerPath, _changedOwnerSource);
      _writeHeadlessReports(
        root,
        currentJournals: {
          1: [_recordedRequest, _walkTokenSubscription],
        },
      );

      final staleness = await _check(root);

      expect(staleness.reason, AtlasStaleReason.stageCode);
      expect(staleness.journalStages, isEmpty);
      expect(staleness.journalDifferences, {
        1:
            'request POST /notifications/toggle-subscribe/device holds '
            '$_walkToken',
      });
    });
  });
}

void _atlasStaleCheck_should_keepWalkIdsOfUnprovenVariantForCapture() {
  test(
    'AtlasStaleCheck should keep walk ids of unproven variant for capture',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(
          root,
          addedRecords: {
            1: [_mediaRecord(_recordedMediaId, isWalked: false)],
          },
        );
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(
          root,
          currentEndFrameHash: _otherEndFrameHash,
          currentJournals: {
            1: [
              _recordedRequest,
              _mediaRecord(_currentMediaId, isWalked: true),
            ],
          },
          baselineJournals: {
            1: [
              _recordedRequest,
              _mediaRecord(_baselineMediaId, isWalked: false),
            ],
          },
        );

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.journalStages, isEmpty);
        expect(staleness.journalDifferences, {
          1:
              'request GET /inboxes/media/by-id/$_currentMediaId holds '
              '$_currentMediaId',
        });
      });
    },
  );
}

void _atlasStaleCheck_should_reportFreshForStagelessWalkShownAlike() {
  test(
    'AtlasStaleCheck should report fresh for stageless walk shown alike',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeFlow(root);
        _writeSnapshot(root);
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(root, currentStageHashes: const []);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.fresh);
      });
    },
  );
}

void _atlasStaleCheck_should_reportFreshForStagelessWalkJournaling() {
  test(
    'AtlasStaleCheck should report fresh for stageless walk journaling',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeFlow(root);
        _writeSnapshot(root);
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(root, currentStageHashes: const []);
        _rewriteCurrentWalkJournal(root, const [_languageRequest]);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.fresh);
      });
    },
  );
}

void _atlasStaleCheck_should_reportCodeForStagelessWalkEnding() {
  test(
    'AtlasStaleCheck should report code for stageless walk ending',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeFlow(root);
        _writeSnapshot(root);
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(
          root,
          currentStageHashes: const [],
          currentEndFrameHash: 'ffffffffffff',
        );

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.code);
        expect(staleness.changedPaths, [_ownerPath]);
      });
    },
  );
}

void _atlasStaleCheck_should_keepStagesWithoutBaselineReport() {
  test('AtlasStaleCheck should keep stages without baseline report', () async {
    await TestAtlasRoot.run((root) async {
      _writeStagedFlow(root);
      _writeStagedSnapshot(root);
      root.writeSource(_ownerPath, _changedOwnerSource);
      _writeHeadlessReports(root, hasBaseline: false);

      final staleness = await _check(root);

      expect(staleness.reason, AtlasStaleReason.stageCode);
      expect(staleness.stages, [0, 1, 2]);
    });
  });
}

void _atlasStaleCheck_should_keepStagesOfChangedStubbedDeclaration() {
  test(
    'AtlasStaleCheck should keep stages of changed stubbed declaration',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeAppSetupSnapshot(root);
        root.writeSource(_appSetupPath, _changedInitializeSource);
        _writeHeadlessReports(root);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0, 1, 2]);
      });
    },
  );
}

void _atlasStaleCheck_should_reportFreshForChangedKeptDeclaration() {
  test(
    'AtlasStaleCheck should report fresh for changed kept declaration',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeAppSetupSnapshot(root);
        root.writeSource(_appSetupPath, _changedStartLanguageSource);
        _writeHeadlessReports(root);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.fresh);
      });
    },
  );
}

void _atlasStaleCheck_should_keepStagesOfReportWalkedOnOtherSources() {
  test(
    'AtlasStaleCheck should keep stages of report walked on other sources',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        _writeHeadlessReports(root);
        root.writeSource(_ownerPath, _changedOwnerSource);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0, 1, 2]);
      });
    },
  );
}

void _atlasStaleCheck_should_keepStagesOfBaselineOnOtherCommit() {
  test(
    'AtlasStaleCheck should keep stages of baseline on other commit',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeStagedFlow(root);
        _writeStagedSnapshot(root);
        root.writeSource(_ownerPath, _changedOwnerSource);
        _writeHeadlessReports(root, baselineCommit: _otherCommit);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.stageCode);
        expect(staleness.stages, [0, 1, 2]);
      });
    },
  );
}

void
_atlasStaleCheck_should_reportFreshForUnreachedThemeFieldOfBaselineHashes() {
  test(
    'AtlasStaleCheck should report fresh for unreached theme field of baseline '
    'hashes',
    () async {
      await TestAtlasRoot.run((root) async {
        _writeWidgetsSnapshotWithoutSources(root);
        _addDimensField(root);
        _writeHeadlessReports(root);

        final staleness = await _check(root);

        expect(staleness.reason, AtlasStaleReason.fresh);
      });
    },
    timeout: _analysisTimeout,
  );
}

Map<String, Object?> _mediaRecord(String mediaId, {required bool isWalked}) {
  return {
    'kind': 'request',
    'method': 'GET',
    'path': '/inboxes/media/by-id/$mediaId',
    if (isWalked) 'acceptLanguage': 'uk',
    'status': _okStatus,
  };
}

void _writeFlow(TestAtlasRoot root) {
  root.writeFlow('shop_flow', {
    'variants': {
      'shopFromExistingItem': {
        'items': [
          {
            'action': 'tap',
            'label': 'quote an item',
            'finder': {'by': 'valueKey', 'value': 'bottom_bar.button.primary'},
          },
        ],
      },
    },
  });
}

void _writeSnapshot(
  TestAtlasRoot root, {
  String? defHash,
  bool isOk = true,
  bool hasManifest = true,
}) {
  root
    ..writeSource(_widgetPath, _widgetSource)
    ..writeSource(_ownerPath, _ownerSource);

  final variant = AtlasDefinitions.read(root.paths).variants.single;

  AtlasSnapshotStore(root.paths).write(
    createAtlasSnapshot(
      flow: variant.flow,
      variant: variant.name,
      ok: isOk,
      defHash: defHash ?? variant.defHash,
      manifest: hasManifest ? _manifest : const {},
    ),
  );
}

Future<AtlasStaleness> _check(
  TestAtlasRoot root, {
  String? locale,
  AtlasMockReplay? mockReplay,
  List<String>? snapshotCommitReads,
}) async {
  final variants = AtlasDefinitions.read(root.paths).variants;

  final stalenesses = await AtlasStaleCheck(
    root.paths,
    locale ?? _uk,
    mockReplay: mockReplay ?? _FakeMockReplay(),
    snapshotCommitReader: (snapshotPath) {
      snapshotCommitReads?.add(snapshotPath);

      return _snapshotCommit;
    },
  ).check(variants);

  return stalenesses.single;
}

void _writeStagedFlow(
  TestAtlasRoot root, {
  List<String> labels = _stagedLabels,
}) {
  root.writeFlow('shop_flow', {
    'variants': {
      'shopFromExistingItem': {
        'items': [
          for (final label in labels)
            {
              'action': 'tap',
              'label': label,
              'finder': {'by': 'text', 'value': label},
            },
        ],
      },
    },
  });
}

// Writes a snapshot whose last stage holds the widget among its sources, the
// widget hashed as a capture hashes it and the owner by its raw content.
void _writeStagedSnapshot(
  TestAtlasRoot root, {
  String? defHash,
  int? changedStepHashStage,
  String? locale,
  Map<String, String> endTextKeys = const {},
  Map<String, String> extraManifest = const {},
  String widgetSource = _widgetSource,
  String? anchor,
  Map<int, List<Object?>> addedRecords = const {},
}) {
  root
    ..writeSource(_widgetPath, widgetSource)
    ..writeSource(_ownerPath, _ownerSource)
    ..writeSource(_mockApiPath, _mockApiSource)
    ..writeSource(_deviceMockPath, _deviceMockSource)
    ..writeSource(_targetsPath, _targetsSource)
    ..writeSource(_apiEndpointsPath, _apiEndpointsSource)
    ..writeSource(_apiTimeoutsPath, _apiTimeoutsSource)
    ..writeSource(_analyticsMapperPath, _analyticsMapperSource)
    ..writeTranslations('uk', {_sendKey: 'Надіслати', _backKey: 'Назад'});

  final variant = AtlasDefinitions.read(root.paths).variants.single;
  final stepHashes = variant.stageStepHashes;
  final manifest = {
    ..._manifest,
    _widgetPath: AtlasSourceHash.hashSource(widgetSource),
    ...extraManifest,
  };

  AtlasSnapshotStore(root.paths).write(
    createAtlasSnapshot(
      flow: variant.flow,
      variant: variant.name,
      locale: locale,
      defHash: defHash ?? variant.defHash,
      manifest: manifest,
      stages: [
        for (final (index, label) in _stagedLabels.indexed)
          AtlasStage(
            label: label,
            action: 'tap',
            journal: [
              if (index == 1) _recordedRequest,
              ...?addedRecords[index],
            ],
            ok: true,
            target: {'by': 'text', 'value': label},
            block: null,
            targetRect: null,
            screen: null,
            designScreen: null,
            shot: null,
            error: null,
            stepHash: index == changedStepHashStage
                ? '000000000000'
                : stepHashes[index],
            sources: index == _stagedLabels.length - 1
                ? {_widgetPath: manifest[_widgetPath] ?? ''}
                : const {},
            localeKeys: index == 1 ? _localeKeys : const {},
            anchor: anchor,
            launchedAt: anchor,
          ),
      ],
      end: AtlasEnd(
        screen: null,
        designScreen: null,
        shot: null,
        localeKeys: endTextKeys,
      ),
    ),
  );
}

// Writes the staged variant with AppSetup in its manifest, outside the
// sources of every stage, and its declarations record.
void _writeAppSetupSnapshot(TestAtlasRoot root) {
  _writeStagedFlow(root);
  root.writeSource(_appSetupPath, _systemSettingsSource);

  final sourceHash = AtlasSourceHash.hashSource(_systemSettingsSource);

  AtlasDeclarationsStore(
    root.paths,
  ).maybeWrite(sourceHash: sourceHash, source: _systemSettingsSource);
  _writeStagedSnapshot(root, extraManifest: {_appSetupPath: sourceHash});
}

// Writes the current report of the variant, walked on the manifest files as
// they stand, and, unless [hasBaseline] is unset, its baseline report on
// [baselineCommit], the baseline holding [_frameHashes] and [_endFrameHash].
// Both hold the journal of every stage the snapshot holds, but where
// [currentJournals] or [baselineJournals] name another one by stage.
void _writeHeadlessReports(
  TestAtlasRoot root, {
  List<String> currentStageHashes = _frameHashes,
  String currentEndFrameHash = _endFrameHash,
  Map<int, List<Object?>> currentJournals = const {},
  Map<int, List<Object?>> baselineJournals = const {},
  bool hasBaseline = true,
  String baselineCommit = _snapshotCommit,
}) {
  final variant = AtlasDefinitions.read(root.paths).variants.single;
  final snapshot = AtlasSnapshotStore(
    root.paths,
  ).tryRead(flow: variant.flow, variant: variant.name, locale: _uk);
  final current = AtlasHeadlessReport(
    frameHashes: currentStageHashes,
    endFrameHash: currentEndFrameHash,
    error: null,
    journals: _readReportJournals(snapshot, currentJournals),
    sourceHashes: {
      for (final path in snapshot?.manifest.keys ?? <String>[])
        path: AtlasSourceHash.tryHashFile(root.paths.resolve(path)),
    },
  );
  final baseline = AtlasHeadlessReport(
    frameHashes: _frameHashes,
    endFrameHash: _endFrameHash,
    error: null,
    journals: _readReportJournals(snapshot, baselineJournals),
    commit: baselineCommit,
  );

  for (final (isBaseline, report) in [
    (false, current),
    if (hasBaseline) (true, baseline),
  ]) {
    root.writeHeadlessReport(
      report,
      flow: variant.flow,
      variant: variant.name,
      isBaseline: isBaseline,
    );
  }
}

void _writeHeadlessHashes(
  TestAtlasRoot root, {
  List<String> frameHashes = _frameHashes,
  Map<int, List<Object?>> journalsByStage = const {},
  String? endFrameHash = _endFrameHash,
  String? renderer,
}) {
  final variant = AtlasDefinitions.read(root.paths).variants.single;
  final store = AtlasSnapshotStore(root.paths);
  final snapshot = store.tryRead(
    flow: variant.flow,
    variant: variant.name,
    locale: _uk,
  );

  if (snapshot == null) {
    fail('No snapshot to write the headless hashes into');
  }

  store.write(
    addTestHeadlessHashes(
      snapshot,
      frameHashes: frameHashes,
      journalHashes: [
        for (final (index, stage) in snapshot.stages.indexed)
          testJournalComparison.hash(journalsByStage[index] ?? stage.journal),
      ],
      endFrameHash: endFrameHash,
      renderer: renderer,
    ),
  );
}

void _rewriteCurrentWalkJournal(TestAtlasRoot root, List<Object?> journal) {
  final variant = AtlasDefinitions.read(root.paths).variants.single;
  final file = File(
    root.paths.resolveHeadlessReportPath(
      flow: variant.flow,
      variant: variant.name,
      locale: _uk,
    ),
  );
  final report = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

  file.writeAsStringSync(
    jsonEncode({
      ...report,
      'journals': [journal],
    }),
  );
}

List<List<Object?>> _readReportJournals(
  AtlasSnapshot? snapshot,
  Map<int, List<Object?>> journals,
) {
  final stages = snapshot?.stages ?? const <AtlasStage>[];

  return [
    const [],
    for (final (index, stage) in stages.indexed)
      journals[index] ?? stage.journal,
  ];
}

final class _FakeMockReplay implements AtlasMockReplay {
  final AtlasMockReplayOutcome outcome;
  final List<AtlasMockReplayInput> inputs = [];

  _FakeMockReplay({this.outcome = const AtlasMockReplayOutcome.same()});

  @override
  Map<String, AtlasMockReplayOutcome> replay(
    List<AtlasMockReplayInput> inputs,
  ) {
    this.inputs.addAll(inputs);

    return {for (final input in inputs) input.id: outcome};
  }
}

void _writeWidgetsSnapshotWithoutSources(
  TestAtlasRoot root, {
  bool hasWidgets = true,
  int? stageWithoutWidgets,
}) {
  _widgetSources.forEach(root.writeSource);

  root
    ..writeSource(_packageConfigPath, readTestPackageConfig('sample'))
    ..writeTranslations('uk', {_sendKey: 'Надіслати', _backKey: 'Назад'});

  _writeStagedFlow(root);

  final declarationsStore = AtlasDeclarationsStore(root.paths);
  final manifest = {
    for (final MapEntry(key: path, value: source) in _widgetSources.entries)
      if (path.endsWith('.dart')) path: AtlasSourceHash.hashSource(source),
  };

  _widgetSources.forEach((path, source) {
    declarationsStore.maybeWrite(
      sourceHash: AtlasSourceHash.hashSource(source),
      source: source,
    );
  });

  final variant = AtlasDefinitions.read(root.paths).variants.single;

  AtlasSnapshotStore(root.paths).write(
    createAtlasSnapshot(
      flow: variant.flow,
      variant: variant.name,
      defHash: variant.defHash,
      manifest: manifest,
      stages: [
        for (final (index, label) in _stagedLabels.indexed)
          AtlasStage(
            label: label,
            action: 'tap',
            journal: const [],
            ok: true,
            target: {'by': 'text', 'value': label},
            block: null,
            targetRect: null,
            screen: null,
            designScreen: null,
            shot: null,
            error: null,
            stepHash: variant.stageStepHashes[index],
            widgets: hasWidgets && index != stageWithoutWidgets
                ? _stageWidgets[index]
                : const [],
          ),
      ],
      end: AtlasEnd(
        screen: null,
        designScreen: null,
        shot: null,
        widgets: hasWidgets ? _endWidgets : const [],
      ),
    ),
  );
}

void _reorderHomeViewImports(TestAtlasRoot root) {
  _replaceSource(root, _homeViewPath, _homeViewImports, '''
import 'package:sample/home/home_owner.dart';
import 'package:flutter/widgets.dart';
''');
}

void _replaceSource(TestAtlasRoot root, String path, String from, String to) {
  final source = _widgetSources[path] ?? '';

  expect(source, contains(from));
  root.writeSource(path, source.replaceAll(from, to));
}

void _addInboxInitState(TestAtlasRoot root) {
  _replaceSource(root, _inboxViewPath, '  @override\n  Widget build', '''
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build''');
}

void _addDimensField(TestAtlasRoot root) {
  final source = _widgetSources[_dimensPath] ?? '';

  root.writeSource(
    _dimensPath,
    source
        .replaceAll(
          'final double gapSm;',
          'final double gapSm;\n  final double gapXs;',
        )
        .replaceAll(
          'required this.gapSm});',
          'required this.gapSm, required this.gapXs});',
        ),
  );
}
