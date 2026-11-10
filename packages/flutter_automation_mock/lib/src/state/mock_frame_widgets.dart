import 'package:flutter/widgets.dart';
import 'package:flutter_automation_mock/src/state/mock_frame_walk.dart';

/// {@category Utils}
///
/// The widget types a frame shows: the `runtimeType` name of every widget
/// [MockFrameWalk] reaches, without generic arguments, sorted, each once.
///
/// The list leaves out a widget whose box lies past its clip, such as a list
/// row built in a viewport's cache extent. It keeps a widget without a box,
/// such as a sliver.
abstract final class MockFrameWidgets {
  /// Reads the widget types under [root] that stand inside [window], in
  /// global logical pixels.
  static List<String> read(Element root, Rect window) {
    final widgets = <String>{};

    MockFrameWalk.visit(
      root,
      window,
      onShown: (element, clip) => _maybeAddWidget(element, clip, widgets),
    );

    return widgets.toList()..sort();
  }

  static void _maybeAddWidget(Element element, Rect clip, Set<String> widgets) {
    final name = _readTypeName(element.widget);

    if (widgets.contains(name) || !_isInsideClip(element, clip)) {
      return;
    }

    widgets.add(name);
  }

  static String _readTypeName(Widget widget) {
    final name = widget.runtimeType.toString();
    final genericStart = name.indexOf('<');

    return genericStart < 0 ? name : name.substring(0, genericStart);
  }

  static bool _isInsideClip(Element element, Rect clip) {
    final rect = MockFrameWalk.readRect(element.findRenderObject());

    return rect == null || rect.overlaps(clip);
  }
}
