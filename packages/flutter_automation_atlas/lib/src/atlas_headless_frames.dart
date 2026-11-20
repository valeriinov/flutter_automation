import 'dart:io';
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';

/// Reads the frame a headless walk hashes: the PNG of the whole tree.
///
/// A flat box covers the text that shows a wall-clock minute of the walk.
abstract final class AtlasHeadlessFrames {
  /// The key of the boundary the walk renders the app in.
  static const key = ValueKey('atlas_headless.frame');

  static const _clockRectInflation = 1.0;
  static const _clockRectColor = Color(0xFFFF00FF);
  static const _clockFieldWidth = 2;

  /// The hash of the PNG that the whole tree of the app renders now, in
  /// logical pixels. The method writes the PNG to [framePath]. It returns
  /// `null` when the tree renders none or shows an image that the app did not
  /// decode.
  ///
  /// A box covers the text of the tree that shows a minute from [launchedAt]
  /// to now and is not among [recordedTexts].
  static Future<String?> read(
    WidgetTester tester, {
    required String framePath,
    required Set<String> recordedTexts,
    required DateTime launchedAt,
  }) async {
    if (hasUndecodedImage()) {
      return null;
    }

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final clockRects = _readClockRects(boundary, recordedTexts, launchedAt);

    final bytes = await tester.runAsync(() => _encodePng(boundary, clockRects));

    if (bytes == null) {
      return null;
    }

    File(framePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    return AtlasContentHash.hashBytes(bytes);
  }

  // An image whose load failed shows its error builder with no RawImage,
  // and one still loading is pending in the cache.
  static bool hasUndecodedImage() {
    return PaintingBinding.instance.imageCache.pendingImageCount > 0 ||
        find.byType(Image).evaluate().any(_isAwaitingFrame);
  }

  static List<Rect> _readClockRects(
    RenderRepaintBoundary boundary,
    Set<String> recordedTexts,
    DateTime launchedAt,
  ) {
    final clockTexts = _readWalkMinutes(launchedAt);

    return [
      for (final (:box, :text) in _readTextBoxes(boundary))
        if (_isClockText(
              LocaleKeyMarker.strip(text),
              clockTexts: clockTexts,
              recordedTexts: recordedTexts,
            ) &&
            _isShown(box))
          (box.localToGlobal(Offset.zero, ancestor: boundary) & box.size)
              .inflate(_clockRectInflation),
    ];
  }

  static Future<List<int>?> _encodePng(
    RenderRepaintBoundary boundary,
    List<Rect> clockRects,
  ) async {
    final image = await boundary.toImage();

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder)..drawImage(image, Offset.zero, Paint());
    final clockPaint = Paint()..color = _clockRectColor;

    for (final rect in clockRects) {
      canvas.drawRect(rect, clockPaint);
    }

    final masked = await recorder.endRecording().toImage(
      image.width,
      image.height,
    );

    try {
      final data = await masked.toByteData(format: ImageByteFormat.png);

      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
      masked.dispose();
    }
  }

  static Set<String> _readWalkMinutes(DateTime launchedAt) {
    final now = DateTime.now();
    final start = DateTime(
      launchedAt.year,
      launchedAt.month,
      launchedAt.day,
      launchedAt.hour,
      launchedAt.minute,
    );

    return {
      for (
        DateTime minute = start;
        !minute.isAfter(now);
        minute = minute.add(const Duration(minutes: 1))
      )
        '${_pad(minute.hour)}:${_pad(minute.minute)}',
    };
  }

  static Iterable<({RenderBox box, String text})> _readTextBoxes(
    RenderObject renderObject,
  ) sync* {
    final span = switch (renderObject) {
      RenderParagraph(:final text) => text,
      RenderEditable(:final text) => text,
      _ => null,
    };
    final text = span?.toPlainText();

    if (text != null && renderObject is RenderBox && renderObject.hasSize) {
      yield (box: renderObject, text: text);
    }

    final children = <RenderObject>[];

    renderObject.visitChildren(children.add);

    for (final child in children) {
      yield* _readTextBoxes(child);
    }
  }

  static bool _isClockText(
    String text, {
    required Set<String> clockTexts,
    required Set<String> recordedTexts,
  }) {
    return !recordedTexts.contains(text) && clockTexts.any(text.contains);
  }

  // The overlay builds a route that an opaque route covers offstage, under
  // a TickerMode that is off.
  static bool _isShown(RenderBox box) {
    final creator = box.debugCreator;

    return creator is! DebugCreator ||
        TickerMode.valuesOf(creator.element).enabled;
  }

  static bool _isAwaitingFrame(Element imageElement) {
    final rawImages = find
        .descendant(
          of: find.byElementPredicate((element) => element == imageElement),
          matching: find.byType(RawImage),
        )
        .evaluate()
        .map((element) => element.widget)
        .whereType<RawImage>();

    return rawImages.isNotEmpty &&
        rawImages.every((rawImage) => rawImage.image == null);
  }

  static String _pad(int value) =>
      value.toString().padLeft(_clockFieldWidth, '0');
}
