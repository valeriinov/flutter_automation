import 'package:flutter/material.dart';
import 'package:flutter_automation_driver/src/automation_frame_walk.dart';
import 'package:flutter_automation_driver/src/automation_protocol.dart';

/// {@category Utils}
///
/// What a frame still lacks before a screenshot of it is true to the screen:
/// the images that have no decoded frame yet and the texts that are empty.
///
/// The elements come from [AutomationFrameWalk], so the count leaves out what
/// the frame does not show. Each kind also names up to [maxItems] of its
/// elements by their rect and the automation id of their nearest marked
/// ancestor.
final class AutomationFrameReadiness {
  /// Most items the readiness names for one kind of defect.
  static const int maxItems = 5;

  /// Count of shown `Image` widgets that have no decoded frame yet. An image
  /// whose box has a zero size counts too, because a loading image has no
  /// size.
  final int loadingImages;

  /// Count of shown `RichText` widgets that hold no visible character and
  /// still have a box with a size. A text inside an `InputDecorator` does not
  /// count: a `TextField` builds empty hint, helper and error texts there.
  final int emptyTexts;

  /// Rect and target of up to [maxItems] of the images counted in
  /// [loadingImages].
  final List<AutomationFrameDefectItem> loadingImageItems;

  /// Rect and target of up to [maxItems] of the texts counted in [emptyTexts].
  final List<AutomationFrameDefectItem> emptyTextItems;

  const AutomationFrameReadiness({
    required this.loadingImages,
    required this.emptyTexts,
    this.loadingImageItems = const [],
    this.emptyTextItems = const [],
  });

  /// Reads the frame under [root] inside [window], in global logical pixels.
  factory AutomationFrameReadiness.read(Element root, Rect window) {
    int loadingImages = 0;
    int emptyTexts = 0;
    final loadingImageItems = <AutomationFrameDefectItem>[];
    final emptyTextItems = <AutomationFrameDefectItem>[];

    AutomationFrameWalk.visit(
      root,
      window,
      onShown: (element, clip) {
        if (_isLoadingImage(element, clip)) {
          loadingImages += 1;

          _maybeAddItem(element, loadingImageItems);
        }

        if (_isEmptyText(element, clip)) {
          emptyTexts += 1;

          _maybeAddItem(element, emptyTextItems);
        }
      },
    );

    return AutomationFrameReadiness(
      loadingImages: loadingImages,
      emptyTexts: emptyTexts,
      loadingImageItems: loadingImageItems,
      emptyTextItems: emptyTextItems,
    );
  }

  static void _maybeAddItem(
    Element element,
    List<AutomationFrameDefectItem> items,
  ) {
    final rect = AutomationFrameWalk.readRect(element.findRenderObject());

    if (items.length >= maxItems || rect == null) {
      return;
    }

    items.add(
      AutomationFrameDefectItem(rect: rect, target: _readTarget(element)),
    );
  }

  static String? _readTarget(Element element) {
    String? target;

    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      final key = widget.key;

      if (widget is KeyedSubtree && key is ValueKey<String>) {
        target = key.value;

        return false;
      }

      return true;
    });

    return target;
  }

  static bool _isLoadingImage(Element element, Rect clip) {
    if (element.widget is! Image || !_isInsideClip(element, clip)) {
      return false;
    }

    final rawImages = <RawImage>[];

    _collectRawImages(element, rawImages);

    return rawImages.isNotEmpty &&
        rawImages.every((rawImage) => rawImage.image == null);
  }

  static void _collectRawImages(Element element, List<RawImage> rawImages) {
    element.visitChildElements((child) {
      if (child.widget case final RawImage rawImage) {
        rawImages.add(rawImage);
      }

      _collectRawImages(child, rawImages);
    });
  }

  static bool _isEmptyText(Element element, Rect clip) {
    final widget = element.widget;

    if (widget is! RichText || widget.text.toPlainText().trim().isNotEmpty) {
      return false;
    }

    return !_isInsideInputDecorator(element) &&
        _hasSize(element) &&
        _isInsideClip(element, clip);
  }

  static bool _isInsideInputDecorator(Element element) {
    return element.findAncestorWidgetOfExactType<InputDecorator>() != null;
  }

  static bool _isInsideClip(Element element, Rect clip) {
    final rect = AutomationFrameWalk.readRect(element.findRenderObject());

    return rect != null && AutomationFrameWalk.isInsideClip(rect, clip);
  }

  static bool _hasSize(Element element) {
    final rect = AutomationFrameWalk.readRect(element.findRenderObject());

    return rect != null && (rect.width > 0 || rect.height > 0);
  }
}

/// {@category Utils}
///
/// One element of a frame defect: where it stands and which marked widget
/// holds it.
final class AutomationFrameDefectItem {
  /// Global rect of the element, in logical pixels.
  final Rect rect;

  /// Id of the nearest ancestor that the marking keys, or null when none.
  final String? target;

  const AutomationFrameDefectItem({required this.rect, required this.target});

  /// The wire form: `rect` as `[left, top, width, height]` in rounded logical
  /// pixels, and `target`.
  Map<String, Object?> toJson() {
    return {
      AutomationProtocol.rectKey: [
        rect.left.round(),
        rect.top.round(),
        rect.width.round(),
        rect.height.round(),
      ],
      AutomationProtocol.targetKey: target,
    };
  }
}
