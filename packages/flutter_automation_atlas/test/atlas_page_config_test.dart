import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_launch_settings.dart';
import 'package:flutter_automation_atlas/src/atlas_page_config.dart';
import 'package:flutter_automation_atlas/src/atlas_page_part.dart';

const _bare = 'name: sample\n';
const _limits = '''
name: sample
flutter_automation:
  atlas:
    maxBundleBytes: 100
    maxBundleImages: 7
''';
const _editions = '''
name: sample
flutter_automation:
  atlas:
    editions:
      lite: [flowStages, designLinks]
      brief: [flowStages]
''';
const _unknownPart = '''
name: sample
flutter_automation:
  atlas:
    editions:
      lite: [flowStages, designLink]
''';
const _withoutFlows = '''
name: sample
flutter_automation:
  atlas:
    editions:
      brief: [designLinks]
''';
const _editionMaps = '''
name: sample
flutter_automation:
  atlas:
    icon: tool/icon.png
    editions:
      lite:
        parts: [flowStages, designLinks]
        title: {en: Product flows, uk: Флоу продукту}
        icon: tool/icon_lite.ico
      full:
        title: {en: Team atlas}
      brief: [flowStages]
''';
const _newEditionWithoutParts = '''
name: sample
flutter_automation:
  atlas:
    editions:
      brief:
        title: {en: Brief}
''';
const _unknownEditionKey = '''
name: sample
flutter_automation:
  atlas:
    editions:
      lite:
        heading: {en: Brief}
''';
const _unknownTitleLanguage = '''
name: sample
flutter_automation:
  atlas:
    editions:
      lite:
        title: {de: Ablauf}
''';
const _badIconFile = '''
name: sample
flutter_automation:
  atlas:
    icon: tool/icon.svg
''';
const _badLimit = '''
name: sample
flutter_automation:
  atlas:
    maxBundleBytes: many
''';

void main() {
  group('AtlasPageConfig Tests', () {
    _atlasPageConfig_should_giveFullEveryPart();
    _atlasPageConfig_should_giveLiteFlowsAndScreenDescriptions();
    _atlasPageConfig_should_replaceAnEditionAndAddOthers();
    _atlasPageConfig_should_rejectUnknownPartNamingTheKey();
    _atlasPageConfig_should_rejectEditionWithoutFlows();
    _atlasPageConfig_should_rejectUnknownEditionNamingTheOnesThereAre();
    _atlasPageConfig_should_readTitleAndIconOfEditionMap();
    _atlasPageConfig_should_keepBuiltInPartsOfMapWithoutParts();
    _atlasPageConfig_should_giveSectionIconToEditionWithoutIcon();
    _atlasPageConfig_should_giveNoTitleAndNoIconByDefault();
    _atlasPageConfig_should_rejectNewEditionWithoutParts();
    _atlasPageConfig_should_rejectUnknownEditionKey();
    _atlasPageConfig_should_rejectUnknownTitleLanguage();
    _atlasPageConfig_should_rejectIconThatIsNoPngOrIco();
    _atlasPageConfig_should_readLimits();
    _atlasPageConfig_should_nameTheKeyOfAMissingLimit();
    _atlasPageConfig_should_rejectLimitThatIsNoNumber();
  });
  group('AtlasLaunchSettings Tests', () {
    _atlasLaunchSettings_should_putPrefixBeforeTool();
    _atlasLaunchSettings_should_callToolDirectlyWithoutPrefix();
  });
}

void _atlasPageConfig_should_giveFullEveryPart() {
  test('AtlasPageConfig should give full every part', () {
    final edition = AtlasPageConfig.fromPubspec(
      _bare,
    ).resolveEdition(AtlasEdition.fullName);

    expect(edition.parts, AtlasPagePart.values.toSet());
  });
}

void _atlasPageConfig_should_giveLiteFlowsAndScreenDescriptions() {
  test('AtlasPageConfig should give lite flows and screen descriptions', () {
    final edition = AtlasPageConfig.fromPubspec(
      _bare,
    ).resolveEdition(AtlasEdition.liteName);

    expect(edition.parts, {
      AtlasPagePart.flowStages,
      AtlasPagePart.screenDescriptions,
    });
  });
}

void _atlasPageConfig_should_replaceAnEditionAndAddOthers() {
  test('AtlasPageConfig should replace an edition and add others', () {
    final config = AtlasPageConfig.fromPubspec(_editions);

    expect(config.resolveEdition('lite').parts, {
      AtlasPagePart.flowStages,
      AtlasPagePart.designLinks,
    });
    expect(config.resolveEdition('brief').parts, {AtlasPagePart.flowStages});
    expect(config.editionNames, ['full', 'lite', 'brief']);
  });
}

void _atlasPageConfig_should_rejectUnknownPartNamingTheKey() {
  test('AtlasPageConfig should reject unknown part naming the key', () {
    expect(
      () => AtlasPageConfig.fromPubspec(_unknownPart),
      throwsA(
        isA<AtlasException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('flutter_automation: atlas: editions: lite:'),
            contains('designLink'),
            contains('designLinks'),
          ),
        ),
      ),
    );
  });
}

void _atlasPageConfig_should_rejectEditionWithoutFlows() {
  test('AtlasPageConfig should reject edition without flows', () {
    expect(
      () => AtlasPageConfig.fromPubspec(_withoutFlows).resolveEdition('brief'),
      throwsA(
        isA<AtlasException>().having(
          (error) => error.message,
          'message',
          allOf(contains('brief'), contains('flowStages')),
        ),
      ),
    );
  });
}

void _atlasPageConfig_should_rejectUnknownEditionNamingTheOnesThereAre() {
  test(
    'AtlasPageConfig should reject unknown edition naming the ones there are',
    () {
      expect(
        () => AtlasPageConfig.fromPubspec(_editions).resolveEdition('gold'),
        throwsA(
          isA<AtlasException>().having(
            (error) => error.message,
            'message',
            allOf(contains('gold'), contains('full, lite, brief')),
          ),
        ),
      );
    },
  );
}

void _atlasPageConfig_should_readTitleAndIconOfEditionMap() {
  test('AtlasPageConfig should read title and icon of edition map', () {
    final edition = AtlasPageConfig.fromPubspec(
      _editionMaps,
    ).resolveEdition('lite');

    expect(edition.parts, {
      AtlasPagePart.flowStages,
      AtlasPagePart.designLinks,
    });
    expect(edition.title, {'en': 'Product flows', 'uk': 'Флоу продукту'});
    expect(edition.iconPath, 'tool/icon_lite.ico');
  });
}

void _atlasPageConfig_should_keepBuiltInPartsOfMapWithoutParts() {
  test('AtlasPageConfig should keep built in parts of map without parts', () {
    final edition = AtlasPageConfig.fromPubspec(
      _editionMaps,
    ).resolveEdition(AtlasEdition.fullName);

    expect(edition.parts, AtlasPagePart.values.toSet());
    expect(edition.title, {'en': 'Team atlas'});
  });
}

void _atlasPageConfig_should_giveSectionIconToEditionWithoutIcon() {
  test('AtlasPageConfig should give section icon to edition without icon', () {
    final config = AtlasPageConfig.fromPubspec(_editionMaps);
    final full = config.resolveEdition(AtlasEdition.fullName);
    final brief = config.resolveEdition('brief');

    expect(full.iconPath, 'tool/icon.png');
    expect(brief.iconPath, 'tool/icon.png');
    expect(brief.title, isEmpty);
  });
}

void _atlasPageConfig_should_giveNoTitleAndNoIconByDefault() {
  test('AtlasPageConfig should give no title and no icon by default', () {
    final edition = AtlasPageConfig.fromPubspec(
      _editions,
    ).resolveEdition('lite');

    expect(edition.title, isEmpty);
    expect(edition.iconPath, isNull);
  });
}

void _atlasPageConfig_should_rejectNewEditionWithoutParts() {
  test('AtlasPageConfig should reject new edition without parts', () {
    expect(
      () => AtlasPageConfig.fromPubspec(_newEditionWithoutParts),
      _throwsAtlasException(
        allOf(
          contains('flutter_automation: atlas: editions: brief:'),
          contains('parts:'),
        ),
      ),
    );
  });
}

void _atlasPageConfig_should_rejectUnknownEditionKey() {
  test('AtlasPageConfig should reject unknown edition key', () {
    expect(
      () => AtlasPageConfig.fromPubspec(_unknownEditionKey),
      _throwsAtlasException(
        allOf(contains('heading'), contains('parts, title, icon')),
      ),
    );
  });
}

void _atlasPageConfig_should_rejectUnknownTitleLanguage() {
  test('AtlasPageConfig should reject unknown title language', () {
    expect(
      () => AtlasPageConfig.fromPubspec(_unknownTitleLanguage),
      _throwsAtlasException(
        allOf(
          contains('editions: lite: title:'),
          contains('"de"'),
          contains('en, uk'),
        ),
      ),
    );
  });
}

void _atlasPageConfig_should_rejectIconThatIsNoPngOrIco() {
  test('AtlasPageConfig should reject icon that is no png or ico', () {
    expect(
      () => AtlasPageConfig.fromPubspec(_badIconFile),
      _throwsAtlasException(
        allOf(
          contains('flutter_automation: atlas: icon:'),
          contains('.png or .ico'),
        ),
      ),
    );
  });
}

void _atlasPageConfig_should_readLimits() {
  test('AtlasPageConfig should read limits', () {
    final config = AtlasPageConfig.fromPubspec(_limits);

    expect(config.maxBundleBytes, 100);
    expect(config.maxBundleImages, 7);
  });
}

void _atlasPageConfig_should_nameTheKeyOfAMissingLimit() {
  test('AtlasPageConfig should name the key of a missing limit', () {
    final config = AtlasPageConfig.fromPubspec(_bare);

    expect(
      () => config.maxBundleBytes,
      throwsA(
        isA<AtlasException>().having(
          (error) => error.message,
          'message',
          contains('flutter_automation: atlas: maxBundleBytes:'),
        ),
      ),
    );
    expect(
      () => config.maxBundleImages,
      throwsA(
        isA<AtlasException>().having(
          (error) => error.message,
          'message',
          contains('maxBundleImages'),
        ),
      ),
    );
  });
}

void _atlasPageConfig_should_rejectLimitThatIsNoNumber() {
  test('AtlasPageConfig should reject limit that is no number', () {
    expect(
      () => AtlasPageConfig.fromPubspec(_badLimit),
      throwsA(
        isA<AtlasException>().having(
          (error) => error.message,
          'message',
          contains('maxBundleBytes'),
        ),
      ),
    );
  });
}

void _atlasLaunchSettings_should_putPrefixBeforeTool() {
  test('AtlasLaunchSettings should put prefix before tool', () {
    const launch = AtlasLaunchSettings(
      entry: 'lib/main.dart',
      commandPrefix: ['fvm'],
    );
    final command = launch.resolveCommand('flutter');

    expect(command.executable, 'fvm');
    expect(command.arguments, ['flutter']);
  });
}

void _atlasLaunchSettings_should_callToolDirectlyWithoutPrefix() {
  test('AtlasLaunchSettings should call tool directly without prefix', () {
    const launch = AtlasLaunchSettings(entry: 'lib/main.dart');
    final command = launch.resolveCommand('dart');

    expect(command.executable, 'dart');
    expect(command.arguments, isEmpty);
  });
}

Matcher _throwsAtlasException(Matcher message) {
  return throwsA(
    isA<AtlasException>().having((error) => error.message, 'message', message),
  );
}
