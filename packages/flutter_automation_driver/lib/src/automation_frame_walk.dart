import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// {@category Utils}
///
/// Walks the elements a frame shows, in tree order.
///
/// The tree also holds what the frame does not show, and the walk leaves it
/// out. This covers the routes that an opaque one covers, under a disabled
/// `TickerMode`. It covers the children that an `IndexedStack` lays out but
/// does not paint, which is how the tabs not selected stay in the tree. It also
/// covers an `Offstage` subtree.
///
/// Below a viewport the clip narrows to the viewport. A reader can then leave
/// out, by [readRect], the list rows built in its cache extent.
abstract final class AutomationFrameWalk {
  /// Calls [onShown] with each shown element under [root] and the clip it
  /// stands in. The walk starts from [window], in global logical pixels.
  static void visit(
    Element root,
    Rect window, {
    required void Function(Element element, Rect clip) onShown,
  }) {
    _visit(root, clip: window, onShown: onShown);
  }

  /// Reads the global rect of [renderObject], or null when it is not a laid
  /// out, attached box.
  static Rect? readRect(RenderObject? renderObject) {
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    if (!renderObject.attached) {
      return null;
    }

    return MatrixUtils.transformRect(
      renderObject.getTransformTo(null),
      Offset.zero & renderObject.size,
    );
  }

  static void _visit(
    Element element, {
    required Rect clip,
    required void Function(Element element, Rect clip) onShown,
  }) {
    if (_isHidden(element.widget)) {
      return;
    }

    final elementClip = _tryClipToViewport(element, clip);

    if (elementClip == null) {
      return;
    }

    onShown(element, elementClip);
    _visitShownChildren(
      element,
      (child) => _visit(child, clip: elementClip, onShown: onShown),
    );
  }

  static bool _isHidden(Widget widget) {
    return switch (widget) {
      TickerMode(:final enabled) => !enabled,
      Offstage(:final offstage) => offstage,
      _ => false,
    };
  }

  static Rect? _tryClipToViewport(Element element, Rect clip) {
    final renderObject = element is RenderObjectElement
        ? element.renderObject
        : null;

    if (renderObject is! RenderAbstractViewport) {
      return clip;
    }

    final viewportRect = readRect(renderObject);

    if (viewportRect == null || !viewportRect.overlaps(clip)) {
      return null;
    }

    return viewportRect.intersect(clip);
  }

  /// Visits the children of [element] its render object paints: the one an
  /// `IndexedStack` shows, every child otherwise. The children of an element
  /// stand in the order of the render children they own.
  static void _visitShownChildren(Element element, ElementVisitor visitor) {
    final renderObject = element is RenderObjectElement
        ? element.renderObject
        : null;

    if (renderObject is! RenderIndexedStack) {
      element.visitChildElements(visitor);

      return;
    }

    int index = 0;

    element.visitChildElements((child) {
      if (index == renderObject.index) {
        visitor(child);
      }

      index += 1;
    });
  }
}
