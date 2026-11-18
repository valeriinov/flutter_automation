import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_settings.dart';
import 'package:flutter_automation_atlas/src/atlas_stage_sources.dart';

import 'test_utils/fake_atlas_project.dart';
import 'test_utils/test_atlas_root.dart';

const _routesPath = 'lib/app/router.g.dart';
const _routerPath = 'lib/app/router.dart';
const _registryPath = 'lib/app/registry.dart';
const _screenPath = 'lib/ui/screens/carts/carts_screen.dart';
const _ownerPath = 'lib/ui/screens/carts/carts_owner.dart';
const _statePath = 'lib/ui/screens/carts/carts_state.dart';
const _freezedPath = 'lib/ui/screens/carts/carts_state.freezed.dart';
const _freezedImportPath = 'lib/domain/entities/cart/cart_json.dart';
const _cardPath = 'lib/ui/widgets/cart_card.dart';
const _entityPath = 'lib/domain/entities/cart/cart_data.dart';
const _otherScreenPath = 'lib/ui/screens/items/items_screen.dart';
const _routes = '''
part of 'router.dart';

/// generated route for
/// [CartsScreen]
class CartsRoute extends GeneratedRoute<void> {
  const CartsRoute();
}

/// generated route for
/// [ItemsScreen]
class ItemsRoute
    extends GeneratedRoute<ItemsRouteArgs> {
  ItemsRoute();
}
''';
const _router = '''
import 'package:route_kit/route_kit.dart';
import 'package:sample/app/registry.dart';
import 'package:sample/ui/screens/carts/carts_screen.dart';
import 'package:sample/ui/screens/items/items_screen.dart';

part 'router.g.dart';
''';
const _screen = '''
import 'package:flutter/material.dart';
import 'package:sample/app/router.dart';
import 'package:sample/ui/widgets/cart_card.dart';

import 'carts_owner.dart';

class CartsScreen {}
''';
const _owner = '''
import 'dart:async';

import 'package:sample/domain/entities/cart/cart_data.dart';

part 'carts_state.dart';
part 'carts_state.freezed.dart';
''';
const _state = '''
part of 'carts_owner.dart';
''';
const _otherScreen = '''
import 'package:sample/app/router.dart';

class ItemsScreen {}
''';
const _allPaths = [
  _routerPath,
  _registryPath,
  _screenPath,
  _ownerPath,
  _statePath,
  _freezedPath,
  _freezedImportPath,
  _cardPath,
  _entityPath,
  _otherScreenPath,
];

void main() {
  group('AtlasStageSources Tests', () {
    _atlasStageSources_should_collectTransitiveImportsOfScreenFile();
    _atlasStageSources_should_stopAtRouterAndGeneratedFiles();
    _atlasStageSources_should_resolveRouteDeclaredOnTwoLines();
    _atlasStageSources_should_keepOnlyManifestPaths();
    _atlasStageSources_should_returnEmptyForUnknownScreen();
    _atlasStageSources_should_throwWithoutRoutesFile();
    _atlasStageSources_should_returnEmptyForProjectWithoutRoutes();
  });
}

void _atlasStageSources_should_collectTransitiveImportsOfScreenFile() {
  test(
    'AtlasStageSources should collect transitive imports of screen file',
    () async {
      await TestAtlasRoot.run((root) {
        _writeApp(root);

        final sources = AtlasStageSources(
          root.paths,
          root.paths.packagePrefix,
        ).resolve(screen: 'carts-route', manifestPaths: _allPaths);

        expect(sources, [
          _entityPath,
          _ownerPath,
          _screenPath,
          _statePath,
          _cardPath,
        ]);
      });
    },
  );
}

void _atlasStageSources_should_stopAtRouterAndGeneratedFiles() {
  test('AtlasStageSources should stop at router and generated files', () async {
    await TestAtlasRoot.run((root) {
      _writeApp(root);

      final sources = AtlasStageSources(
        root.paths,
        root.paths.packagePrefix,
      ).resolve(screen: 'carts-route', manifestPaths: _allPaths);

      expect(sources, isNot(contains(_routerPath)));
      expect(sources, isNot(contains(_registryPath)));
      expect(sources, isNot(contains(_otherScreenPath)));
      expect(sources, isNot(contains(_freezedPath)));
      expect(sources, isNot(contains(_freezedImportPath)));
    });
  });
}

void _atlasStageSources_should_resolveRouteDeclaredOnTwoLines() {
  test(
    'AtlasStageSources should resolve route declared on two lines',
    () async {
      await TestAtlasRoot.run((root) {
        _writeApp(root);

        final sources = AtlasStageSources(
          root.paths,
          root.paths.packagePrefix,
        ).resolve(screen: 'items-route', manifestPaths: _allPaths);

        expect(sources, [_otherScreenPath]);
      });
    },
  );
}

void _atlasStageSources_should_keepOnlyManifestPaths() {
  test('AtlasStageSources should keep only manifest paths', () async {
    await TestAtlasRoot.run((root) {
      _writeApp(root);

      final sources = AtlasStageSources(root.paths, root.paths.packagePrefix)
          .resolve(
            screen: 'carts-route',
            manifestPaths: const [_screenPath, _cardPath, _otherScreenPath],
          );

      expect(sources, [_screenPath, _cardPath]);
    });
  });
}

void _atlasStageSources_should_returnEmptyForUnknownScreen() {
  test('AtlasStageSources should return empty for unknown screen', () async {
    await TestAtlasRoot.run((root) {
      _writeApp(root);

      final sources = AtlasStageSources(
        root.paths,
        root.paths.packagePrefix,
      ).resolve(screen: 'settings-route', manifestPaths: _allPaths);

      expect(sources, isEmpty);
    });
  });
}

void _atlasStageSources_should_throwWithoutRoutesFile() {
  test('AtlasStageSources should throw without routes file', () async {
    await TestAtlasRoot.run((root) {
      final sources = AtlasStageSources(root.paths, root.paths.packagePrefix);

      expect(
        () => sources.resolve(screen: 'carts-route', manifestPaths: const []),
        throwsA(isA<AtlasException>()),
      );
    });
  });
}

void _atlasStageSources_should_returnEmptyForProjectWithoutRoutes() {
  test(
    'AtlasStageSources should return empty for project without routes',
    () async {
      final project = FakeAtlasProject(
        staleSettingsOverride: const AtlasStaleSettings(
          mockDirectory: 'lib/mock/',
          targetsDirectory: 'lib/automation/',
          automationDirectory: 'lib/automation/',
          stopPaths: [_routerPath],
        ),
      );

      await TestAtlasRoot.runWith(project: project, (root) {
        _writeApp(root);

        final sources = AtlasStageSources(
          root.paths,
          root.paths.packagePrefix,
        ).resolve(screen: 'carts-route', manifestPaths: _allPaths);

        expect(sources, isEmpty);
      });
    },
  );
}

void _writeApp(TestAtlasRoot root) {
  root
    ..writeSource(_routesPath, _routes)
    ..writeSource(_routerPath, _router)
    ..writeSource(
      _registryPath,
      "import '${root.paths.packagePrefix}x/y.dart';",
    )
    ..writeSource(_screenPath, _screen)
    ..writeSource(_ownerPath, _owner)
    ..writeSource(_statePath, _state)
    ..writeSource(
      _freezedPath,
      "import '../../../../domain/entities/cart/cart_json.dart';",
    )
    ..writeSource(_cardPath, 'class CartCard {}')
    ..writeSource(_entityPath, 'class CartData {}')
    ..writeSource(_freezedImportPath, 'class CartJson {}')
    ..writeSource(_otherScreenPath, _otherScreen);
}
