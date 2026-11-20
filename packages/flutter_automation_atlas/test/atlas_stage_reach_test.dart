import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_stage_reach.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_settings.dart';

import 'test_utils/fake_atlas_project.dart';
import 'test_utils/read_test_package_config.dart';
import 'test_utils/test_atlas_root.dart';

const _analysisTimeout = Timeout(Duration(minutes: 2));
const _packageConfigPath = '.dart_tool/package_config.json';
const _homeViewPath = 'lib/home/home_view.dart';
const _homeOwnerPath = 'lib/home/home_owner.dart';
const _repositoryPath = 'lib/home/home_repository.dart';
const _repositoryImplPath = 'lib/home/home_repository_impl.dart';
const _otherViewPath = 'lib/other/other_view.dart';
const _otherSourcesPath = 'lib/other/other_sources.dart';
const _mainPath = 'lib/main.dart';
const _sizesPath = 'lib/theme/ui_sizes_ext.dart';
const _spacingPath = 'lib/theme/ui_spacing_ext.dart';
const _spacingGeneratedPath = 'lib/theme/ui_spacing_ext.g.dart';
const _themeHostViewPath = 'lib/theme/theme_host_view.dart';
const _spacingFieldOwners = [
  'UiSpacingExt',
  'UiSpacingFactory',
  '_UiSpacing',
  r'_$UiSpacingExtMixin',
];
const _firstNamesPath = 'lib/names/first_names.dart';
const _secondNamesPath = 'lib/names/second_names.dart';
const _samplePackageSources = {
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
  _firstNamesPath: '''
import 'package:flutter/widgets.dart';

String formatTitle() => '';

class Text {}

extension FirstTitleFormat on String {
  String get shouted => toUpperCase();
}

Widget buildGap() => const SizedBox();
''',
  _secondNamesPath: '''
String formatTitle() => 'title';

String formatSubtitle() => 'subtitle';

extension SecondTitleFormat on String {
  String get shouted => this;
}
''',
  'pubspec.yaml': '''
name: sample
environment:
  sdk: ^3.9.0
''',
  _homeViewPath: '''
import 'package:flutter/widgets.dart';
import 'package:sample/home/home_owner.dart';
import 'package:sample/other/other_view.dart';
import 'package:sample/theme/ui_sizes_ext.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _owner = HomeOwner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.uiSizesExt.gapLg,
      child: OtherView(title: _owner.loadTitle()),
    );
  }
}
''',
  _homeOwnerPath: '''
import 'package:sample/di/locator.dart';
import 'package:sample/home/home_repository.dart';

class HomeOwner {
  final _repository = Locator.find<HomeRepository>();

  String loadTitle() => _repository.readTitle();
}
''',
  _repositoryPath: '''
abstract interface class HomeRepository {
  String readTitle();
}
''',
  _repositoryImplPath: '''
import 'package:sample/home/home_repository.dart';
import 'package:sample/di/annotations.dart';

@Register(as: HomeRepository)
class HomeRepositoryImpl implements HomeRepository {
  @override
  String readTitle() => const _TitleSource().title;
}

class _TitleSource {
  final title = '';

  const _TitleSource();
}
''',
  _otherViewPath: '''
import 'package:flutter/widgets.dart';
import 'package:sample/di/locator.dart';
import 'package:sample/other/other_sources.dart';

class OtherView extends StatelessWidget {
  final String title;

  const OtherView({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return Text(OtherOwner().readTitle(title));
  }
}

class OtherOwner {
  final _useCase = Locator.find<OtherUseCase>();
  final _delay = Locator.find<Duration>();

  String readTitle(String title) =>
      title + _useCase.readTitle() + _delay.toString();
}
''',
  _otherSourcesPath: '''
import 'package:sample/di/annotations.dart';

abstract interface class OtherRepository {
  String readTitle();
}

@Register(as: OtherRepository)
class OtherRepositoryImpl implements OtherRepository {
  final String _title;

  OtherRepositoryImpl() : _title = OtherTitles.initial;

  @override
  String readTitle() => _title;
}

@Register()
class OtherUseCase {
  final OtherRepository _repository;

  OtherUseCase(this._repository);

  String readTitle() => _repository.readTitle();
}

@bundle
abstract class OtherModule {
  @register
  Duration otherDelay() => const Duration(seconds: OtherTitles.delaySeconds);
}

abstract final class OtherTitles {
  static const initial = '';
  static const delaySeconds = 1;
}
''',
  _mainPath: '''
import 'package:flutter/widgets.dart';
import 'package:sample/other/other_view.dart';

void main() {
  runApp(OtherView(title: readStartTitle()));
}

String readStartTitle() => 'start';
''',
  _sizesPath: '''
import 'package:flutter/widgets.dart';

class UiSizesExt {
  final double gapLg;
  final double gapSm;

  const UiSizesExt({required this.gapLg, required this.gapSm});
}

extension UiSizesExtBuildContext on BuildContext {
  UiSizesExt get uiSizesExt => throw UnimplementedError();
}
''',
  _spacingPath: r'''
import 'package:flutter/material.dart';

part 'ui_spacing_ext.g.dart';

class UiSpacingExt extends ThemeExtension<UiSpacingExt>
    with _$UiSpacingExtMixin {
  @override
  final double padSm;

  @override
  final double padLg;

  const UiSpacingExt({required this.padSm, required this.padLg});
}

abstract final class _UiSpacing {
  static const double padSm = 4;
  static const double padLg = 16;
}

abstract final class UiSpacingFactory {
  static UiSpacingExt createSpacing() {
    return const UiSpacingExt(
      padSm: _UiSpacing.padSm,
      padLg: _UiSpacing.padLg,
    );
  }
}

extension UiSpacingExtBuildContext on BuildContext {
  UiSpacingExt get uiSpacingExt => throw UnimplementedError();
}
''',
  _spacingGeneratedPath: r'''
part of 'ui_spacing_ext.dart';

mixin _$UiSpacingExtMixin on ThemeExtension<UiSpacingExt> {
  double get padSm;
  double get padLg;

  @override
  UiSpacingExt copyWith({double? padSm, double? padLg}) {
    return UiSpacingExt(
      padSm: padSm ?? this.padSm,
      padLg: padLg ?? this.padLg,
    );
  }

  @override
  UiSpacingExt lerp(covariant ThemeExtension<UiSpacingExt>? other, double t) {
    return other is UiSpacingExt ? other : copyWith();
  }
}
''',
  _themeHostViewPath: '''
import 'package:flutter/material.dart';
import 'package:sample/theme/ui_spacing_ext.dart';

class ThemeHostView extends StatelessWidget {
  const ThemeHostView({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(extensions: [UiSpacingFactory.createSpacing()]),
      child: const SizedBox(),
    );
  }
}

class SpacedView extends StatelessWidget {
  const SpacedView({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: context.uiSpacingExt.padLg);
  }
}
''',
};

final _samplePackageReach = _readSamplePackageReach();

void main() {
  group('AtlasStageReach Tests', () {
    _atlasStageReach_should_reachOwnStateAndItsMentions();
    _atlasStageReach_should_readEveryFileWithoutExcludedSuffix();
    _atlasStageReach_should_readPackageConfigOfWorkspaceRoot();
    _atlasStageReach_should_rejectProjectWithoutPackageConfig();
    _atlasStageReach_should_notEnterOtherWidget();
    _atlasStageReach_should_reachThemeFieldOnlyByItsName();
    _atlasStageReach_should_reachThemeFieldOnlyFromWidgetReadingIt();
    _atlasStageReach_should_markImplementationAsDi();
    _atlasStageReach_should_reachRegisteredConstructorsThroughDi();
    _atlasStageReach_should_reachModuleMethodFromRegisteredType();
    _atlasStageReach_should_reachMainFromWidgetItConstructs();
    _atlasStageReach_should_tellNamesDeclaredInTwoFiles();
    _atlasStageReach_should_tellNamesAnImportedPackageDeclares();
  });
}

void _atlasStageReach_should_reachOwnStateAndItsMentions() {
  test('AtlasStageReach should reach own state and its mentions', () async {
    final reach = await _samplePackageReach;

    final reached = reach.reachFrom('HomeView');

    expect(
      reached.ids,
      containsAll([
        AtlasStageReach.idOf(_homeViewPath, 'HomeView'),
        AtlasStageReach.idOf(_homeViewPath, '_HomeViewState'),
        AtlasStageReach.idOf(_homeOwnerPath, 'HomeOwner'),
        AtlasStageReach.idOf(_repositoryPath, 'HomeRepository'),
      ]),
    );
  }, timeout: _analysisTimeout);
}

void _atlasStageReach_should_notEnterOtherWidget() {
  test('AtlasStageReach should not enter other widget', () async {
    final reach = await _samplePackageReach;

    final reachedIds = _readReachedIds(reach, 'HomeView');

    expect(
      reachedIds,
      isNot(contains(AtlasStageReach.idOf(_otherViewPath, 'OtherView'))),
    );
    expect(
      reachedIds,
      isNot(contains(AtlasStageReach.idOf(_otherViewPath, 'OtherOwner'))),
    );
  }, timeout: _analysisTimeout);
}

void _atlasStageReach_should_reachThemeFieldOnlyByItsName() {
  test('AtlasStageReach should reach theme field only by its name', () async {
    final reach = await _samplePackageReach;

    final reached = reach.reachFrom('HomeView');

    expect(
      reached.ids,
      containsAll([
        AtlasStageReach.idOf(_sizesPath, 'UiSizesExt'),
        AtlasStageReach.idOf(_sizesPath, 'UiSizesExt.gapLg'),
      ]),
    );
    expect(
      reached.ids,
      isNot(contains(AtlasStageReach.idOf(_sizesPath, 'UiSizesExt.gapSm'))),
    );
  }, timeout: _analysisTimeout);
}

void _atlasStageReach_should_reachThemeFieldOnlyFromWidgetReadingIt() {
  test(
    'AtlasStageReach should reach theme field only from widget reading it',
    () async {
      final reach = await _samplePackageReach;

      final hostIds = _readReachedIds(reach, 'ThemeHostView');
      final spacedIds = _readReachedIds(reach, 'SpacedView');

      expect(
        hostIds,
        contains(AtlasStageReach.idOf(_spacingPath, 'UiSpacingFactory')),
      );
      expect(hostIds.where(_isSpacingField), isEmpty);
      expect(spacedIds.where(_isSpacingField).toSet(), {
        AtlasStageReach.idOf(_spacingPath, 'UiSpacingExt.padLg'),
        AtlasStageReach.idOf(_spacingPath, 'UiSpacingFactory.padLg'),
        AtlasStageReach.idOf(_spacingPath, '_UiSpacing.padLg'),
        AtlasStageReach.idOf(
          _spacingGeneratedPath,
          r'_$UiSpacingExtMixin.padLg',
        ),
      });
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStageReach_should_markImplementationAsDi() {
  test('AtlasStageReach should mark implementation as DI', () async {
    final reach = await _samplePackageReach;

    final reached = reach.reachFrom('HomeView');

    expect(reached.diIds, {
      AtlasStageReach.idOf(_repositoryImplPath, 'HomeRepositoryImpl'),
      AtlasStageReach.idOf(_repositoryImplPath, 'HomeRepositoryImpl.readTitle'),
      AtlasStageReach.idOf(_repositoryImplPath, '_TitleSource'),
      AtlasStageReach.idOf(_repositoryImplPath, '_TitleSource.new'),
      AtlasStageReach.idOf(_repositoryImplPath, '_TitleSource.title'),
      AtlasStageReach.idOf('lib/di/annotations.dart', 'Register'),
      AtlasStageReach.idOf('lib/di/annotations.dart', 'Register.new'),
      AtlasStageReach.idOf('lib/di/annotations.dart', 'Register.as'),
    });
  }, timeout: _analysisTimeout);
}

void _atlasStageReach_should_reachRegisteredConstructorsThroughDi() {
  test(
    'AtlasStageReach should reach registered constructors through DI',
    () async {
      final reach = await _samplePackageReach;

      final reached = reach.reachFrom('OtherView');

      expect(
        reached.diIds,
        containsAll([
          AtlasStageReach.idOf(_otherSourcesPath, 'OtherUseCase.new'),
          AtlasStageReach.idOf(_otherSourcesPath, 'OtherRepositoryImpl.new'),
          AtlasStageReach.idOf(_otherSourcesPath, 'OtherTitles.initial'),
        ]),
      );
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStageReach_should_reachModuleMethodFromRegisteredType() {
  test(
    'AtlasStageReach should reach module method from registered type',
    () async {
      final reach = await _samplePackageReach;

      final reached = reach.reachFrom('OtherView');

      expect(
        reached.diIds,
        containsAll([
          AtlasStageReach.idOf(_otherSourcesPath, 'OtherModule.otherDelay'),
          AtlasStageReach.idOf(_otherSourcesPath, 'OtherTitles.delaySeconds'),
        ]),
      );
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStageReach_should_reachMainFromWidgetItConstructs() {
  test('AtlasStageReach should reach main from widget it constructs', () async {
    final reach = await _samplePackageReach;

    final otherIds = reach.reachFrom('OtherView').ids;
    final homeIds = _readReachedIds(reach, 'HomeView');

    expect(
      otherIds,
      containsAll([
        AtlasStageReach.idOf(_mainPath, 'main'),
        AtlasStageReach.idOf(_mainPath, 'readStartTitle'),
      ]),
    );
    expect(homeIds, isNot(contains(AtlasStageReach.idOf(_mainPath, 'main'))));
  }, timeout: _analysisTimeout);
}

void _atlasStageReach_should_tellNamesDeclaredInTwoFiles() {
  test('AtlasStageReach should tell names declared in two files', () async {
    final reach = await _samplePackageReach;

    final isFunctionTwice = reach.isNameDeclaredMoreThanOnce('formatTitle');
    final isMemberTwice = reach.isNameDeclaredMoreThanOnce('shouted');
    final isUniqueTwice = reach.isNameDeclaredMoreThanOnce('formatSubtitle');

    expect(isFunctionTwice, isTrue);
    expect(isMemberTwice, isTrue);
    expect(isUniqueTwice, isFalse);
  }, timeout: _analysisTimeout);
}

void _atlasStageReach_should_tellNamesAnImportedPackageDeclares() {
  test(
    'AtlasStageReach should tell names an imported package declares',
    () async {
      final reach = await _samplePackageReach;

      final isTextTwice = reach.isNameDeclaredMoreThanOnce('Text');
      final isGapTwice = reach.isNameDeclaredMoreThanOnce('buildGap');

      expect(isTextTwice, isTrue);
      expect(isGapTwice, isFalse);
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStageReach_should_readEveryFileWithoutExcludedSuffix() {
  test(
    'AtlasStageReach should read every file without excluded suffix',
    () async {
      final project = FakeAtlasProject(
        staleSettingsOverride: const AtlasStaleSettings(
          mockDirectory: 'lib/mock/',
          targetsDirectory: 'lib/automation/',
          automationDirectory: 'lib/automation/',
          stopPaths: [],
        ),
      );

      final reach = await _readSamplePackageReach(project: project);

      final reachedIds = _readReachedIds(reach, 'HomeView');

      expect(
        reachedIds,
        contains(AtlasStageReach.idOf(_homeViewPath, 'HomeView')),
      );
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStageReach_should_readPackageConfigOfWorkspaceRoot() {
  test(
    'AtlasStageReach should read package config of workspace root',
    () async {
      final directory = Directory.systemTemp.createTempSync('reach-');

      try {
        final appPath = p.join(directory.path, 'app');

        _samplePackageSources.forEach((path, content) {
          File(p.join(appPath, path))
            ..createSync(recursive: true)
            ..writeAsStringSync(content);
        });

        File(p.join(directory.path, _packageConfigPath))
          ..createSync(recursive: true)
          ..writeAsStringSync(
            readTestPackageConfig(
              'sample',
            ).replaceFirst('"rootUri":"../"', '"rootUri":"../app"'),
          );

        final reach = await AtlasStageReach.read(
          AtlasLocations(appPath, FakeAtlasProject()),
        );

        expect(
          reach.reachFrom('HomeView').ids,
          contains(AtlasStageReach.idOf(_homeViewPath, 'HomeView')),
        );
      } finally {
        directory.deleteSync(recursive: true);
      }
    },
    timeout: _analysisTimeout,
  );
}

void _atlasStageReach_should_rejectProjectWithoutPackageConfig() {
  test(
    'AtlasStageReach should reject project without package config',
    () async {
      final directory = Directory.systemTemp.createTempSync('reach-');

      try {
        Directory(p.join(directory.path, 'lib')).createSync();

        await expectLater(
          AtlasStageReach.read(
            AtlasLocations(directory.path, FakeAtlasProject()),
          ),
          throwsA(isA<AtlasException>()),
        );
      } finally {
        directory.deleteSync(recursive: true);
      }
    },
  );
}

Future<AtlasStageReach> _readSamplePackageReach({
  FakeAtlasProject? project,
}) async {
  final completer = Completer<AtlasStageReach>();

  await TestAtlasRoot.runWith(project: project, (root) async {
    _samplePackageSources.forEach(root.writeSource);
    root.writeSource(_packageConfigPath, readTestPackageConfig('sample'));
    completer.complete(await AtlasStageReach.read(root.paths));
  });

  return completer.future;
}

Set<String> _readReachedIds(AtlasStageReach reach, String widgetName) {
  final reached = reach.reachFrom(widgetName);

  return {...reached.ids, ...reached.diIds};
}

bool _isSpacingField(String id) {
  return _spacingFieldOwners.any(
    (owner) => id.contains('::$owner.padSm') || id.contains('::$owner.padLg'),
  );
}
