import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_runner_catalogue.dart';

import 'test_utils/test_atlas_root.dart';

const _catalogueText =
    '{"flows":{"login":{"variants":{}}},"blocks":{"open":{"steps":[]}}}';

void main() {
  group('AtlasRunnerCatalogue Tests', () {
    _automationRunnerCatalogue_should_decodeFlowsAndBlocks();
    _automationRunnerCatalogue_should_nameErrorLineOfRunner();
    _automationRunnerCatalogue_should_rejectCatalogueWithoutBlocks();
    _automationRunnerCatalogue_should_rejectCatalogueWithoutFlows();
    _automationRunnerCatalogue_should_rejectTextThatIsNotJson();
    _automationRunnerCatalogue_should_answerSeededRootWithoutRunningRunner();
  });
}

void _automationRunnerCatalogue_should_decodeFlowsAndBlocks() {
  test('AtlasRunnerCatalogue should decode flows and blocks', () {
    final catalogue = AtlasRunnerCatalogue.decode(_catalogueText);

    expect(catalogue.flows.keys, ['login']);
    expect(catalogue.blocks.keys, ['open']);
  });
}

void _automationRunnerCatalogue_should_nameErrorLineOfRunner() {
  test('AtlasRunnerCatalogue should name error line of runner', () {
    expect(
      () => AtlasRunnerCatalogue.decode('{"error":"declared twice"}'),
      throwsA(
        isA<AtlasException>().having(
          (error) => error.message,
          'message',
          'The runner failed: declared twice',
        ),
      ),
    );
  });
}

void _automationRunnerCatalogue_should_rejectCatalogueWithoutBlocks() {
  test('AtlasRunnerCatalogue should reject catalogue without blocks', () {
    expect(
      () => AtlasRunnerCatalogue.decode('{"flows":{}}'),
      throwsA(isA<AtlasException>()),
    );
  });
}

void _automationRunnerCatalogue_should_rejectCatalogueWithoutFlows() {
  test('AtlasRunnerCatalogue should reject catalogue without flows', () {
    expect(
      () => AtlasRunnerCatalogue.decode('{"blocks":{}}'),
      throwsA(
        isA<AtlasException>().having(
          (error) => error.message,
          'message',
          'The flows of the runner catalogue is not a JSON object.',
        ),
      ),
    );
  });
}

void _automationRunnerCatalogue_should_rejectTextThatIsNotJson() {
  test('AtlasRunnerCatalogue should reject text that is not JSON', () {
    expect(
      () => AtlasRunnerCatalogue.decode('Resolving dependencies...'),
      throwsA(isA<AtlasException>()),
    );
  });
}

void _automationRunnerCatalogue_should_answerSeededRootWithoutRunningRunner() {
  test(
    'AtlasRunnerCatalogue should answer seeded root without running runner',
    () async {
      await TestAtlasRoot.run((root) {
        root.writeFlow('login', const {'variants': <String, Object?>{}});
        root.writeBlock('open', const {'steps': <Object?>[]});

        final catalogue = AtlasRunnerCatalogue.read(root.paths);

        expect(catalogue.flows.keys, ['login']);
        expect(catalogue.blocks.keys, ['open']);
      });
    },
  );
}
