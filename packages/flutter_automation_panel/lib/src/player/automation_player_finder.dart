import 'package:flutter/cupertino.dart' show CupertinoNavigationBarBackButton;
import 'package:flutter/material.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_panel/src/player/automation_player_exception.dart';
import 'package:flutter_automation_panel/src/player/automation_player_settings.dart';

/// {@category Utils}
///
/// Finds the elements that a catalogue `finder` JSON names, in the element
/// tree of the running app.
///
/// It answers the `by` values the runner writes: `valueKey`, `text`,
/// `tooltip`, `localeKey`, `localeKeyTooltip`, `type`, `pageBack`, `dateText`,
/// a declared date kind and the nested `descendant` and `ancestor`. A text
/// match ignores the mark of a locale key, as the driver finder does.
class AutomationPlayerFinder {
  static const _backTooltip = 'Back';

  /// The finder JSON of the step.
  final Map<String, Object?> json;

  /// What the project tells the player.
  final AutomationPlayerSettings settings;

  /// Day a date finder counts from.
  final DateTime anchor;

  /// Pattern a `dateText` finder writes a date in, by locale code.
  final Map<String, String> dateFormats;

  /// Value key template of each declared date finder, by its name.
  final Map<String, String> dateValueKeys;

  AutomationPlayerFinder(
    this.json,
    this.settings, {
    DateTime? anchor,
    this.dateFormats = const {},
    this.dateValueKeys = const {},
  }) : anchor = anchor ?? DateTime.now();

  /// The elements the finder names, in tree order.
  ///
  /// With [isOnstage], the search skips the routes and the subtrees that the
  /// framework keeps off the stage. A scroll into view searches the whole
  /// tree.
  List<Element> findAll({bool isOnstage = true}) {
    return _resolve(json, isOnstage: isOnstage);
  }

  /// The first element the finder names, `null` when it names none.
  Element? findFirst({bool isOnstage = true}) {
    return findAll(isOnstage: isOnstage).firstOrNull;
  }

  List<Element> _resolve(Object? finder, {required bool isOnstage}) {
    if (finder is! Map<String, Object?>) {
      throw const AutomationPlayerException('A finder is not a JSON object.');
    }

    final by = finder['by'];

    if (by == 'descendant' || by == 'ancestor') {
      return _resolveRelative(finder, isOnstage: isOnstage);
    }

    return _collect(_readMatcher(finder), isOnstage: isOnstage);
  }

  List<Element> _resolveRelative(
    Map<String, Object?> finder, {
    required bool isOnstage,
  }) {
    final isAncestor = finder['by'] == 'ancestor';
    final matchRoot = finder['matchRoot'] == true;
    final roots = _resolve(finder['of'], isOnstage: isOnstage);
    final matching = Set<Element>.identity()
      ..addAll(_resolve(finder['matching'], isOnstage: isOnstage));
    final found = <Element>[];

    for (final root in roots) {
      if (matchRoot && matching.contains(root)) {
        found.add(root);
      }

      if (isAncestor) {
        _collectAncestors(root, matching, found);
      } else {
        _visit(root, isOnstage, (element) {
          if (matching.contains(element)) {
            found.add(element);
          }
        });
      }
    }

    return found;
  }

  void _collectAncestors(
    Element root,
    Set<Element> matching,
    List<Element> found,
  ) {
    root.visitAncestorElements((ancestor) {
      if (matching.contains(ancestor)) {
        found.add(ancestor);
      }

      return true;
    });
  }

  List<Element> _collect(
    bool Function(Element element) matches, {
    required bool isOnstage,
  }) {
    final root = WidgetsBinding.instance.rootElement;
    final found = <Element>[];

    if (root == null) {
      return found;
    }

    if (matches(root)) {
      found.add(root);
    }

    _visit(root, isOnstage, (element) {
      if (matches(element)) {
        found.add(element);
      }
    });

    return found;
  }

  void _visit(
    Element root,
    bool isOnstage,
    void Function(Element element) onElement,
  ) {
    void visit(Element element) {
      onElement(element);

      if (isOnstage) {
        element.debugVisitOnstageChildren(visit);
      } else {
        element.visitChildren(visit);
      }
    }

    if (isOnstage) {
      root.debugVisitOnstageChildren(visit);
    } else {
      root.visitChildren(visit);
    }
  }

  bool Function(Element element) _readMatcher(Map<String, Object?> finder) {
    final by = finder['by'];

    return switch (by) {
      'valueKey' => _matchValueKey(_readValue(finder)),
      'text' => _matchUnmarkedText(_readTexts(finder), _readText),
      'tooltip' => _matchUnmarkedText(_readTexts(finder), _readTooltip),
      'localeKey' => _matchLocaleKey(_readTexts(finder), _readText),
      'localeKeyTooltip' => _matchLocaleKey(_readTexts(finder), _readTooltip),
      'type' => _matchType(_readTexts(finder)),
      'pageBack' => _matchPageBack,
      'dateText' => _matchUnmarkedText([_readDateText(finder)], _readText),
      final String kind when dateValueKeys.containsKey(kind) => _matchValueKey(
        _readDateKey(kind, finder),
      ),
      _ => throw AutomationPlayerException('Unknown finder "$by".'),
    };
  }

  Object _readValue(Map<String, Object?> finder) {
    final value = finder['value'];

    return switch (value) {
      final String text => text,
      final int number => number,
      final Map<String, Object?> _ => _readTexts(finder).first,
      _ => throw const AutomationPlayerException(
        'A valueKey finder takes a string or an int value.',
      ),
    };
  }

  List<String> _readTexts(Map<String, Object?> finder) {
    final value = finder['value'];

    if (value is String) {
      return [value];
    }

    if (value is! Map<String, Object?>) {
      throw const AutomationPlayerException('A finder takes a string value.');
    }

    final locale = settings.readLocale?.call();
    final own = value[locale];

    if (own is String) {
      return [own];
    }

    return value.values.whereType<String>().toList(growable: false);
  }

  String _readDateText(Map<String, Object?> finder) {
    final locale = settings.readLocale?.call();
    final pattern = dateFormats[locale];
    final dayOffset = finder['dayOffset'];
    final time = finder['time'];

    if (pattern == null) {
      throw AutomationPlayerException(
        'A dateText finder needs a "dateFormats" entry for the locale '
        '"$locale". It holds ${dateFormats.keys.toList()}.',
      );
    }

    if (dayOffset is! int) {
      throw const AutomationPlayerException(
        'A dateText finder takes an int "dayOffset".',
      );
    }

    if (time is! String?) {
      throw const AutomationPlayerException(
        'A dateText finder takes a string "time".',
      );
    }

    return AutomationDatePattern.writeDayText(
      anchor,
      dayOffset,
      pattern,
      time: time,
    );
  }

  String _readDateKey(String kind, Map<String, Object?> finder) {
    final dayOffset = finder['dayOffset'];

    if (dayOffset is! int) {
      throw AutomationPlayerException(
        'A $kind finder takes an int "dayOffset".',
      );
    }

    return AutomationDatePattern.writeDayKey(
      anchor,
      dayOffset,
      dateValueKeys[kind] ?? '',
    );
  }

  bool Function(Element element) _matchValueKey(Object value) {
    final key = switch (value) {
      final String text => ValueKey<String>(text),
      final int number => ValueKey<int>(number),
      _ => ValueKey<Object>(value),
    };

    return (element) => element.widget.key == key;
  }

  bool Function(Element element) _matchUnmarkedText(
    List<String> texts,
    String? Function(Element element) read,
  ) {
    return (element) {
      final shown = read(element);

      return shown != null && texts.contains(LocaleKeyMarker.strip(shown));
    };
  }

  bool Function(Element element) _matchLocaleKey(
    List<String> keys,
    String? Function(Element element) read,
  ) {
    return (element) {
      final shown = read(element);

      return shown != null &&
          LocaleKeyMarker.readKeys(shown).any(keys.contains);
    };
  }

  bool Function(Element element) _matchType(List<String> names) {
    return (element) => names.contains(element.widget.runtimeType.toString());
  }

  bool _matchPageBack(Element element) {
    final widget = element.widget;

    return widget is CupertinoNavigationBarBackButton ||
        (widget is Tooltip && widget.message == _backTooltip);
  }

  String? _readText(Element element) {
    return switch (element.widget) {
      Text(:final data?) => data,
      Text(:final textSpan?) => textSpan.toPlainText(),
      EditableText(:final controller) => controller.text,
      final RichText richText when !_isBuiltByText(element) =>
        richText.text.toPlainText(),
      _ => null,
    };
  }

  bool _isBuiltByText(Element element) {
    bool isBuilt = false;

    element.visitAncestorElements((ancestor) {
      isBuilt = ancestor.widget is Text;

      return !isBuilt;
    });

    return isBuilt;
  }

  String? _readTooltip(Element element) {
    return switch (element.widget) {
      Tooltip(:final message?) => message,
      _ => null,
    };
  }
}
