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
