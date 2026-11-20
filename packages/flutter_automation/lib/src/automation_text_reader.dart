import 'package:flutter/widgets.dart';

/// {@category Utils}
///
/// Reads the text that a widget shows, the same way for the text finders of
/// the driver, the runner and the QA panel.
///
/// It reads a [Text], an [EditableText] and a [RichText] that no [Text] builds.
/// A [RichText] that a [Text] builds gives null. A finder then matches each
/// text once. The [RichText] of a [WidgetSpan] child gives its own text.
abstract final class AutomationTextReader {
  /// Returns the text that the widget of [element] shows. Returns null when
  /// the widget shows no text of its own.
  static String? tryRead(Element element) {
    return switch (element.widget) {
      Text(:final data?) => data,
      Text(:final textSpan?) => textSpan.toPlainText(),
      EditableText(:final controller) => controller.text,
      final RichText richText when !_isBuiltByText(element) =>
        richText.text.toPlainText(),
      _ => null,
    };
  }

  static bool _isBuiltByText(Element element) {
    bool isBuilt = false;

    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;

      isBuilt = widget is Text;

      return !isBuilt && widget is! RichText;
    });

    return isBuilt;
  }
}
