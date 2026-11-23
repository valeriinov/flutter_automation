import 'package:flutter_automation_atlas/src/atlas_exception.dart';

/// {@category Utils}
///
/// One part of the atlas page. An [AtlasEdition] lists the parts a page
/// shows; the renderer puts into the page data, and into its search, only
/// the parts of the edition.
enum AtlasPagePart {
  /// The flows, their groups, and the stages with the screenshot and the
  /// place of the tap. Every edition holds this part.
  flowStages,

  /// The prose that describes each design screen.
  screenDescriptions,

  /// The link of a stage to the design of its screen.
  designLinks,

  /// The tables of project data, except the table of the translation keys.
  tables,

  /// The journal records of every stage: the requests, the analytics events
  /// and the state changes.
  journalRecords,

  /// The translation keys of every stage, and the table of the translation
  /// keys.
  localeKeys,

  /// The translations of every page locale.
  translations,

  /// The mock scenario of every variant.
  mockScenario,

  /// The search over the journal records.
  recordSearch;

  /// The part named [name], or `null` when no part has that name.
  static AtlasPagePart? tryRead(String name) {
    return values.asNameMap()[name];
  }
}

/// {@category Utils}
///
/// A named list of the parts of the atlas page, with the title and the icon
/// of the page.
///
/// The `full` edition holds every [AtlasPagePart]. The `lite` edition holds
/// [AtlasPagePart.flowStages] and [AtlasPagePart.screenDescriptions]. The
/// `flutter_automation: atlas: editions:` section of the `pubspec.yaml` of a
/// project replaces either list, adds others, and gives an edition its title
/// and its icon.
final class AtlasEdition {
  /// The name of the edition that holds every part.
  static const fullName = 'full';

  /// The name of the edition for people outside the team.
  static const liteName = 'lite';

  /// The name the `--edition` option and the file of a bundle use.
  final String name;

  /// The parts the page of the edition shows.
  final Set<AtlasPagePart> parts;

  /// The title of the page, by page language (`en`, `uk`). The page shows
  /// its own title in a language the map lacks. Empty by default.
  final Map<String, String> title;

  /// The path of the `.png` or `.ico` file that the browser tab shows,
  /// relative to the root of the project. The page draws its own icon when
  /// the path is `null`, the default.
  final String? iconPath;

  /// Creates the edition [name] with [parts], [title] and [iconPath].
  ///
  /// Throws an [AtlasException] when [parts] lacks
  /// [AtlasPagePart.flowStages].
  AtlasEdition(
    this.name,
    Set<AtlasPagePart> parts, {
    Map<String, String> title = const {},
    this.iconPath,
  }) : parts = Set.unmodifiable(parts),
       title = Map.unmodifiable(title) {
    if (!parts.contains(AtlasPagePart.flowStages)) {
      throw AtlasException(
        'The edition "$name" lacks the part ${AtlasPagePart.flowStages.name}; '
        'every page shows the flows.',
      );
    }
  }

  /// Whether the page of the edition shows [part].
  bool has(AtlasPagePart part) => parts.contains(part);
}
