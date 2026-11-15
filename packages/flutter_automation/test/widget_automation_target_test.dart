import 'package:flutter/widgets.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WidgetAutomationTarget Tests', () {
    _widgetAutomationTarget_should_keyTheWidgetByTheTargetIdWhenMarkingIsOn();
    _widgetAutomationTarget_should_returnTheWidgetUntouchedForNoTarget();
  });
}

void _widgetAutomationTarget_should_keyTheWidgetByTheTargetIdWhenMarkingIsOn() {
  testWidgets(
    'WidgetAutomationTarget should key the widget by the id',
    skip: !AutomationSettings.isMarkingEnabled,
    (tester) async {
      await tester.pumpWidget(
        const SizedBox().automationTarget(_SampleTarget.field),
      );

      expect(find.byKey(const ValueKey('sample.field.field')), findsOneWidget);
    },
  );
}

void _widgetAutomationTarget_should_returnTheWidgetUntouchedForNoTarget() {
  test('WidgetAutomationTarget should return the widget for no target', () {
    const widget = SizedBox();

    expect(widget.automationTarget(null), same(widget));
  });
}

enum _SampleTarget with AutomationIdComposer {
  field;

  @override
  AutomationTargetType get type => AutomationTargetType.field;

  @override
  String get scope => 'sample';
}
