import 'package:flutter/widgets.dart';
import 'package:flutter_automation_mock/src/state/mock_frame_walk.dart';

/// {@category Utils}
///
/// The texts a frame shows: every `RichText` and `EditableText` laid out
/// inside the window, in tree order, each once.
///
/// The elements come from [MockFrameWalk]. The list leaves out a text that lies
/// past its clip, such as a list row built in a viewport's cache extent. A
/// `Text` builds a `RichText`, so a read of both would name it twice.
abstract final class MockFrameTexts {
  /// Reads the texts under [root] that stand inside [window], in global
  /// logical pixels.
  static List<String> read(Element root, Rect window) {
    final texts = <String>{};

    MockFrameWalk.visit(
      root,
      window,
      onShown: (element, clip) => _maybeAddText(element, clip, texts),
    );

    return texts.toList();
  }

  static void _maybeAddText(Element element, Rect clip, Set<String> texts) {
    final text = _tryReadText(element.widget);

    if (text == null || text.trim().isEmpty) {
      return;
    }

    final rect = MockFrameWalk.readRect(element.findRenderObject());

    if (rect == null || !rect.overlaps(clip)) {
      return;
    }

    texts.add(text);
  }

  static String? _tryReadText(Widget widget) {
    return switch (widget) {
      RichText(:final text) => text.toPlainText(),
      EditableText(:final controller) => controller.text,
      _ => null,
    };
  }
}
