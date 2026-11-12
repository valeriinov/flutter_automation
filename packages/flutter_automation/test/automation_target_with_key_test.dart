import 'package:flutter_automation/automation_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutomationTargetWithKey Extension Tests', () {
    _automationTargetWithKey_should_appendTheKeyAsTheLastSegment();
    _automationTargetWithKey_should_keepTheTypeAndTheScope();
    _automationTargetWithKey_should_keepThePrefixForAKeyWithADotOrASpace();
    _automationTargetWithKey_should_giveEveryRecordAnIdOfItsOwn();
  });
}

void _automationTargetWithKey_should_appendTheKeyAsTheLastSegment() {
  test('AutomationTargetWithKey should append the key as the last segment', () {
    final byInt = _InboxTarget.deleteButton.withKey(42);
    final byString = _InboxTarget.deleteButton.withKey('UA');

    expect(byInt.id, 'inbox.button.deleteButton.42');
    expect(byString.id, 'inbox.button.deleteButton.UA');
  });
}

void _automationTargetWithKey_should_keepTheTypeAndTheScope() {
  test('AutomationTargetWithKey should keep the type and the scope', () {
    final target = _InboxTarget.deleteButton.withKey(42);

    expect(target.type, AutomationTargetType.button);
    expect(target.scope, 'inbox');
  });
}

void _automationTargetWithKey_should_keepThePrefixForAKeyWithADotOrASpace() {
  test(
    'AutomationTargetWithKey should keep the prefix for a key with a dot or a '
    'space',
    () {
      const prefix = 'inbox.button.';
      final dotted = _InboxTarget.deleteButton.withKey('2.5');
      final spaced = _InboxTarget.deleteButton.withKey('new york');

      expect(dotted.id, 'inbox.button.deleteButton.2.5');
      expect(spaced.id, 'inbox.button.deleteButton.new york');
      expect(dotted.id, startsWith(prefix));
      expect(spaced.id, startsWith(prefix));
    },
  );
}

void _automationTargetWithKey_should_giveEveryRecordAnIdOfItsOwn() {
  test('AutomationTargetWithKey should give every record an id of its own', () {
    final ids = {
      _InboxTarget.deleteButton.id,
      _InboxTarget.deleteButton.withKey(1).id,
      _InboxTarget.deleteButton.withKey(2).id,
      _InboxTarget.inboxScreen.id,
    };

    expect(ids, hasLength(4));
  });
}

enum _InboxTarget with AutomationIdComposer {
  inboxScreen(AutomationTargetType.screen),
  deleteButton(AutomationTargetType.button);

  @override
  final AutomationTargetType type;

  const _InboxTarget(this.type);

  @override
  String get scope => 'inbox';
}
