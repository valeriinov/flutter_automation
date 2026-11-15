import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

/// {@category Widgets}
///
/// A layer that blocks the finger while [isBlocked] is true and lets the
/// pointer events of the player through.
///
/// The gate stands above the `Navigator` of the app, usually in the `builder`
/// of the `MaterialApp`, so it also covers a dialog and a bottom sheet. A
/// blocked gate answers every hit test itself, so the app below sees no touch.
class AutomationInputGate extends SingleChildRenderObjectWidget {
  /// Tells whether the gate blocks a pointer event now. The gate calls it at
  /// each hit test.
  final bool Function() isBlocked;

  const AutomationInputGate({
    required this.isBlocked,
    required super.child,
    super.key,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderInputGate(isBlocked);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    if (renderObject is _RenderInputGate) {
      renderObject.isBlocked = isBlocked;
    }
  }
}

/// {@category Widgets}
///
/// A layer that the player's pointer events pass through while [isPassing] is
/// true.
///
/// It wraps the controls that stand above an [AutomationInputGate], such as
/// the walk plaque. The finger reaches them. A tap of the player goes to the
/// app under them.
class AutomationInputPassThrough extends SingleChildRenderObjectWidget {
  /// Tells whether the layer is transparent to a pointer event now. The layer
  /// calls it at each hit test.
  final bool Function() isPassing;

  const AutomationInputPassThrough({
    required this.isPassing,
    required super.child,
    super.key,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderInputPassThrough(isPassing);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    if (renderObject is _RenderInputPassThrough) {
      renderObject.isPassing = isPassing;
    }
  }
}

class _RenderInputGate extends RenderProxyBox {
  bool Function() isBlocked;

  _RenderInputGate(this.isBlocked);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!isBlocked()) {
      return super.hitTest(result, position: position);
    }

    if (!size.contains(position)) {
      return false;
    }

    result.add(BoxHitTestEntry(this, position));

    return true;
  }
}

class _RenderInputPassThrough extends RenderProxyBox {
  bool Function() isPassing;

  _RenderInputPassThrough(this.isPassing);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (isPassing()) {
      return false;
    }

    return super.hitTest(result, position: position);
  }
}
