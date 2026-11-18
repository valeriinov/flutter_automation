import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_source_hash.dart';

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
import 'package:sample/common/automation/targets/profile_form_automation_target.dart';
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
  });
}

void _atlasSourceHash_should_ignoreAddedTargetAndItsImports() {
  test('AtlasSourceHash should ignore added target and its imports', () {
    final untargetedHash = AtlasSourceHash.hashSource(_untargetedSource);
    final targetedHash = AtlasSourceHash.hashSource(_targetedSource);

    expect(targetedHash, untargetedHash);
  });
}

void _atlasSourceHash_should_changeForEditBesideTarget() {
  test('AtlasSourceHash should change for edit beside target', () {
    final editedSource = _targetedSource.replaceFirst(
      'CommonGap.lg()',
      'CommonGap.md()',
    );
    final editedHash = AtlasSourceHash.hashSource(editedSource);

    expect(editedHash, isNot(AtlasSourceHash.hashSource(_untargetedSource)));
  });
}

void _atlasSourceHash_should_keepCharactersOfStringLiterals() {
  test('AtlasSourceHash should keep characters of string literals', () {
    const spacedSource = "final title = 'Нова  поїздка';";
    final normalized = AtlasSourceHash.normalize(spacedSource);

    expect(normalized, "finaltitle='Нова  поїздка';");
  });
}

void _atlasSourceHash_should_keepTargetCallInsideStringOrComment() {
  test('AtlasSourceHash should keep target call inside string or comment', () {
    const source = '''
// Marked with .automationTarget(Target.x) on purpose.
final hint = 'call .automationTarget(\${target.id}) here';
''';
    final normalized = AtlasSourceHash.normalize(source);

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
    final normalized = AtlasSourceHash.normalize(source);

    expect(normalized, 'child.build();');
  });
}
