import 'package:flutter_automation_atlas/src/atlas_source_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils/fake_atlas_project.dart';

const _untargetedSource = '''
import 'package:sample/common/generated/locale_keys.g.dart';

class ProfileForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InputField.name(name: _firstNameFieldName),
        CommonGap.lg(),
      ],
    );
  }
}
''';
const _targetedSource = '''
import 'package:flutter_automation/flutter_automation.dart';
import 'package:sample/support/automation/targets/profile_form_automation_target.dart';
import 'package:sample/common/generated/locale_keys.g.dart';

class ProfileForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InputField.name(
          name: _firstNameFieldName,
        ).automationTarget(ProfileFormAutomationTarget.firstName),
        CommonGap.lg(),
      ],
    );
  }
}
''';

void main() {
  group('AtlasSourceHash Tests', () {
    _atlasSourceHash_should_ignoreAddedTargetAndItsImports();
    _atlasSourceHash_should_changeForEditBesideTarget();
    _atlasSourceHash_should_keepCharactersOfStringLiterals();
    _atlasSourceHash_should_keepTargetCallInsideStringOrComment();
    _atlasSourceHash_should_skipParenthesesInsideTargetArguments();
    _atlasSourceHash_should_skipImportsOfAutomationDirectoryOnly();
  });
}

void _atlasSourceHash_should_ignoreAddedTargetAndItsImports() {
  test('AtlasSourceHash should ignore added target and its imports', () {
    final untargetedHash = testSourceHash.hashSource(_untargetedSource);
    final targetedHash = testSourceHash.hashSource(_targetedSource);

    expect(targetedHash, untargetedHash);
  });
}

void _atlasSourceHash_should_changeForEditBesideTarget() {
  test('AtlasSourceHash should change for edit beside target', () {
    final editedSource = _targetedSource.replaceFirst(
      'CommonGap.lg()',
      'CommonGap.md()',
    );
    final editedHash = testSourceHash.hashSource(editedSource);

    expect(editedHash, isNot(testSourceHash.hashSource(_untargetedSource)));
  });
}

void _atlasSourceHash_should_keepCharactersOfStringLiterals() {
  test('AtlasSourceHash should keep characters of string literals', () {
    const spacedSource = "final title = 'Новий  товар';";
    final normalized = testSourceHash.normalize(spacedSource);

    expect(normalized, "finaltitle='Новий  товар';");
  });
}

void _atlasSourceHash_should_keepTargetCallInsideStringOrComment() {
  test('AtlasSourceHash should keep target call inside string or comment', () {
    const source = '''
// Marked with .automationTarget(Target.x) on purpose.
final hint = 'call .automationTarget(\${target.id}) here';
''';
    final normalized = testSourceHash.normalize(source);

    expect(normalized, contains('//Markedwith.automationTarget(Target.x)'));
    expect(
      normalized,
      contains(r"'call .automationTarget(${target.id}) here'"),
    );
  });
}

void _atlasSourceHash_should_skipParenthesesInsideTargetArguments() {
  test('AtlasSourceHash should skip parentheses inside target arguments', () {
    const source = "child.automationTarget(resolve(')', item)).build();";
    final normalized = testSourceHash.normalize(source);

    expect(normalized, 'child.build();');
  });
}

void _atlasSourceHash_should_skipImportsOfAutomationDirectoryOnly() {
  test('AtlasSourceHash should skip imports of automation directory only', () {
    final sourceHash = AtlasSourceHash(
      const AtlasStaleSettings(
        mockDirectory: 'lib/mock/',
        targetsDirectory: 'lib/automation/targets/',
        automationDirectory: 'lib/automation/',
        stopPaths: [],
      ),
    );
    const source = '''
import 'package:app/automation/cart_flow.dart';
import '../automation/cart_flow.dart';
import 'package:app/my_automation/cart_flow.dart';
class CartView {}
''';

    expect(
      sourceHash.normalize(source),
      sourceHash.normalize('''
import 'package:app/my_automation/cart_flow.dart';
class CartView {}
'''),
    );
    expect(
      sourceHash.hashSource(source),
      isNot(sourceHash.hashSource('class CartView {}')),
    );
  });
}
