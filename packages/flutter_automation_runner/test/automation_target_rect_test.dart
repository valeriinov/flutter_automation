import 'package:flutter_driver/flutter_driver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_runner/src/automation_screen_answer.dart';
import 'package:flutter_automation_runner/src/automation_target_rect.dart';

const AutomationViewSize _view = (width: 400, height: 800);
const _topLeft = DriverOffset(40, 200);
const _bottomRight = DriverOffset(360, 280);
const _fractions = [0.1, 0.25, 0.9, 0.35];
const AutomationViewSize _thirdsView = (width: 300, height: 900);
const _thirdsTopLeft = DriverOffset(100, 100);
const _thirdsBottomRight = DriverOffset(200, 800.5);
const _roundedThirds = [0.333, 0.111, 0.667, 0.889];
const _edgeKeys = ['left', 'top', 'right', 'bottom'];

void main() {
  group('AutomationTargetRect Tests', () {
    _automationTargetRect_should_divideCornersByView();
    _automationTargetRect_should_roundFractionsToThreeDecimals();
    _automationTargetRect_should_writeEdgesInReportOrder();
  });
}

void _automationTargetRect_should_divideCornersByView() {
  test('AutomationTargetRect should divide corners by view', () {
    final rect = AutomationTargetRect.fromOffsets(
      topLeft: _topLeft,
      bottomRight: _bottomRight,
      view: _view,
    );

    expect(_readEdges(rect), _fractions);
  });
}

void _automationTargetRect_should_roundFractionsToThreeDecimals() {
  test('AutomationTargetRect should round fractions to three decimals', () {
    final rect = AutomationTargetRect.fromOffsets(
      topLeft: _thirdsTopLeft,
      bottomRight: _thirdsBottomRight,
      view: _thirdsView,
    );

    expect(_readEdges(rect), _roundedThirds);
  });
}

void _automationTargetRect_should_writeEdgesInReportOrder() {
  test('AutomationTargetRect should write edges in report order', () {
    final rect = AutomationTargetRect.fromOffsets(
      topLeft: _topLeft,
      bottomRight: _bottomRight,
      view: _view,
    );
    final json = rect.toJson();

    expect(json.keys, _edgeKeys);
    expect(json.values, _fractions);
  });
}

List<double> _readEdges(AutomationTargetRect rect) {
  return [rect.left, rect.top, rect.right, rect.bottom];
}
