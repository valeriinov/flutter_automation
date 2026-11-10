import 'package:flutter_driver/flutter_driver.dart';

import 'package:flutter_automation_runner/src/automation_screen_answer.dart';

/// {@category Utils}
///
/// The rectangle an action's element covers, as fractions of the view.
///
/// A fraction lays the rectangle over a screenshot of any resolution, since
/// the screenshot spans the whole view.
final class AutomationTargetRect {
  static const _fractionDigits = 3;

  /// Distance of the left edge from the left of the view.
  final double left;

  /// Distance of the top edge from the top of the view.
  final double top;

  /// Distance of the right edge from the left of the view.
  final double right;

  /// Distance of the bottom edge from the top of the view.
  final double bottom;

  const AutomationTargetRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// Divides the corners the driver reads by the size of the view and rounds
  /// each fraction to three decimals.
  ///
  /// The [topLeft] and [bottomRight] parameters are the corners of the element
  /// in logical pixels, and the [view] parameter is the size of the view in
  /// logical pixels.
  factory AutomationTargetRect.fromOffsets({
    required DriverOffset topLeft,
    required DriverOffset bottomRight,
    required AutomationViewSize view,
  }) {
    final (:width, :height) = view;

    return AutomationTargetRect(
      left: _toFraction(topLeft.dx, width),
      top: _toFraction(topLeft.dy, height),
      right: _toFraction(bottomRight.dx, width),
      bottom: _toFraction(bottomRight.dy, height),
    );
  }

  /// The rectangle as the run report writes it.
  Map<String, double> toJson() {
    return {'left': left, 'top': top, 'right': right, 'bottom': bottom};
  }

  static double _toFraction(double offset, double extent) {
    return double.parse((offset / extent).toStringAsFixed(_fractionDigits));
  }
}
