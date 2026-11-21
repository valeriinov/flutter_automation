import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_stages.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_translations.dart';

/// {@category Utils}
///
/// Reads which translation keys the published variants show. It also reads
/// the list that names why no variant shows the other keys.
///
/// A key is on frames when a stage or the end of a stored snapshot of the
/// default locale shows it. The page must publish that variant. A key that
/// only an unpublished snapshot shows is not on frames. [reconcile] reads the
/// translations, the snapshots and the list. [readList] reads the list alone.
///
/// A line of the list maps a key to its reason word. It can also map a key to
/// an object. The object has the word as `reason`, the `place` in the app
/// that would show the key, and the `widget` that would render it. An
/// `unused` key takes the object.
final class AtlasLocaleKeyCoverageReport {
  final AtlasLocations _paths;

  const AtlasLocaleKeyCoverageReport(this._paths);

  /// The file of the list; `null` when the project names none.
  String? get listPath {
    final path = _paths.project.paths.uncoveredLocaleKeys;

    return path == null ? null : p.join(_paths.storePath, path);
  }

  /// What the translations, the published snapshots and the list say about
  /// every key.
  AtlasLocaleKeyCoverage reconcile() {
    final list = readList();

    return AtlasLocaleKeyCoverage(
      keys: AtlasTranslations.read(
        _paths,
        _paths.defaultLocale,
      ).values.keys.toList(),
      framedKeys: _readFramedKeys(),
      reasonsByKey: list.reasonsByKey,
      placesByKey: list.placesByKey,
    );
  }

  /// The word the list gives for each key it names, in its order, and the
  /// place of each key whose line names one. Both are empty when the project
  /// names no list.
  ///
  /// Throws an [AtlasException] when the list is missing or malformed.
  AtlasLocaleKeyCoverageList readList() {
    final path = listPath;

    if (path == null) {
      return (reasonsByKey: const {}, placesByKey: const {});
    }

    final file = File(path);

    if (!file.existsSync()) {
      throw AtlasException(
        'No uncovered localization keys list at ${file.path}.',
      );
    }

    final json = AtlasJson.decodeObject(
      file.readAsStringSync(),
      'The uncovered localization keys list ${file.path}',
    );
    final lines = {
      for (final MapEntry(:key, :value) in json.entries)
        key: _readLine(file.path, key, value),
    };

    return (
      reasonsByKey: lines.map((key, line) => MapEntry(key, line.reason)),
      placesByKey: {
        for (final MapEntry(:key, value: line) in lines.entries)
          key: ?line.place,
      },
    );
  }

  Set<String> _readFramedKeys() {
    return AtlasJournalStages(
      _paths,
    ).readPublishedSnapshots().expand(_readShownKeys).toSet();
  }

  _LocaleKeyCoverageLine _readLine(String listPath, String key, Object? value) {
    if (value is String) {
      return (reason: value, place: null);
    }

    if (value is! Map<String, Object?>) {
      throw AtlasException(
        'The uncovered localization keys list $listPath maps "$key" to '
        '$value; a key takes a reason or an object holding one.',
      );
    }

    return (
      reason: AtlasJson.readString(value, 'reason'),
      place: _tryReadPlace(value),
    );
  }

  Iterable<String> _readShownKeys(AtlasSnapshot snapshot) {
    return [
      for (final stage in snapshot.stages) ...stage.localeKeys.keys,
      ...snapshot.end.localeKeys.keys,
    ];
  }

  AtlasLocaleKeyPlace? _tryReadPlace(Map<String, Object?> json) {
    final place = AtlasJson.tryReadString(json, 'place');
    final widget = AtlasJson.tryReadString(json, 'widget');

    if (place == null || widget == null) {
      return null;
    }

    return (place: place, widget: widget);
  }
}

/// {@category Utils}
///
/// Why no published variant shows a translation key.
enum AtlasLocaleKeyReason {
  /// The text leaves the app and the app does not draw it: a share payload,
  /// a debug overlay, an exception message.
  codeOnly,

  /// No reachable code renders the key.
  unused,

  /// No published variant shows the key yet.
  pending;

  /// Each reason, in the order the list of them reads.
  static String get names => values.map((reason) => reason.name).join(', ');

  /// The reason [word] names, `null` when it names none.
  static AtlasLocaleKeyReason? tryParse(String word) {
    return values.firstWhereOrNull((reason) => reason.name == word);
  }
}

typedef _LocaleKeyCoverageLine = ({String reason, AtlasLocaleKeyPlace? place});

/// Where in the app an unused key would show and the widget that would render
/// it.
typedef AtlasLocaleKeyPlace = ({String place, String widget});

/// The uncovered keys list: the word of each line and the place of each
/// line naming one.
typedef AtlasLocaleKeyCoverageList = ({
  Map<String, String> reasonsByKey,
  Map<String, AtlasLocaleKeyPlace> placesByKey,
});

/// One line of the list naming why no published variant shows a key.
typedef AtlasLocaleKeyDeclaration = ({String key, String reason});

/// {@category Utils}
///
/// What the translations, the published snapshots and the uncovered keys list
/// say about every key.
final class AtlasLocaleKeyCoverage {
  /// Each key of the default locale translations, in their order.
  final List<String> keys;

  /// The keys a published variant shows on a stage or its end.
  final Set<String> framedKeys;

  /// The word the list gives for each key it names, in its order.
  final Map<String, String> reasonsByKey;

  /// The place the list gives for each key whose line names one.
  final Map<String, AtlasLocaleKeyPlace> placesByKey;

  const AtlasLocaleKeyCoverage({
    required this.keys,
    required this.framedKeys,
    required this.reasonsByKey,
    required this.placesByKey,
  });

  /// Keys at least one published variant shows.
  Iterable<String> get keysOnFrames => keys.where(isOnFrames);

  /// Keys no published variant shows and the list leaves out.
  Iterable<String> get undeclaredKeys {
    return keys.where(
      (key) => !isOnFrames(key) && !reasonsByKey.containsKey(key),
    );
  }

  /// Lines of the list naming a key a published variant shows after all.
  Iterable<AtlasLocaleKeyDeclaration> get framedDeclarations {
    return _declarations.where((declaration) => isOnFrames(declaration.key));
  }

  /// Lines of the list naming a key the translations do not hold.
  Iterable<String> get strandedDeclarations {
    return reasonsByKey.keys.where((key) => !keys.contains(key));
  }

  /// Lines of the list whose word names no reason.
  Iterable<AtlasLocaleKeyDeclaration> get unknownReasons {
    return _declarations.where(
      (declaration) =>
          AtlasLocaleKeyReason.tryParse(declaration.reason) == null,
    );
  }

  /// Lines of the list naming a key unused without its place and widget.
  Iterable<String> get unplacedDeclarations {
    return _declarations
        .where(
          (declaration) =>
              declaration.reason == AtlasLocaleKeyReason.unused.name &&
              !placesByKey.containsKey(declaration.key),
        )
        .map((declaration) => declaration.key);
  }

  Iterable<AtlasLocaleKeyDeclaration> get _declarations {
    return reasonsByKey.entries.map(
      (entry) => (key: entry.key, reason: entry.value),
    );
  }

  /// Whether at least one published variant shows [key].
  bool isOnFrames(String key) => framedKeys.contains(key);

  /// How many lines of the list give [reason].
  int countDeclarations(AtlasLocaleKeyReason reason) {
    return reasonsByKey.values.where((word) => word == reason.name).length;
  }
}
