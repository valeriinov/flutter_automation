import 'package:flutter_automation_atlas/src/atlas_headless_settings.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_schema.dart';
import 'package:flutter_automation_atlas/src/atlas_launch_settings.dart';
import 'package:flutter_automation_atlas/src/atlas_paths.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_publisher.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_settings.dart';
import 'package:flutter_automation_atlas/src/atlas_store_reader.dart';
import 'package:flutter_automation_atlas/src/atlas_table.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';

/// {@category Utils}
///
/// Everything the atlas needs to know about one project. It covers where the
/// project keeps its files and how it starts. It covers what its journal
/// looks like and what it shows on the page beside the flows.
///
/// A project extends this class once and passes it to `runAtlas`. The members
/// with a body have a default for a project without that data. The defaults
/// are no tables, no translations, no screen descriptions, no design links,
/// no reports, no shot publisher, and each analytics event accepted.
abstract class AtlasProject {
  const AtlasProject();

  /// The places of the project the atlas reads and writes.
  AtlasPaths get paths;

  /// How the atlas starts the app on a simulator.
  AtlasLaunchSettings get launchSettings;

  /// The shape of the journal records the app writes.
  AtlasJournalSchema get journalSchema;

  /// The files and names the atlas compares to tell a stale stage.
  AtlasStaleSettings get staleSettings;

  /// How the atlas walks a variant under `flutter test`.
  AtlasHeadlessSettings get headlessSettings;

  /// The `flutter test` file that replays the answers of a snapshot against
  /// the mock, relative to the root of the project.
  String get mockReplayEntry;

  /// The key of the screen record that names the design screen.
  String get designScreenKey;

  /// The name of the project; the page shows it and prefixes the keys it
  /// keeps in the browser with it.
  String get projectName;

  /// The group a flow joins when it declares none.
  AutomationFlowGroup get defaultGroup;

  /// The groups of the page in display order. A group names its area, and
  /// the page lists the areas in the order they first stand.
  List<AutomationFlowGroup> get groupOrder;

  /// The locales the atlas captures and the page shows; the first one is the
  /// default.
  List<String> get locales;

  /// The prose that describes each design screen, by design screen and then
  /// by locale; empty by default. An empty map makes the atlas read the file
  /// [AtlasPaths.screenDescriptions] names.
  Map<String, Map<String, String>> get screenDescriptions => const {};

  /// The pattern that finds the use of a translation key in a source file
  /// under `lib/`; group 1 holds the key. Without it the built-in table of the
  /// keys lists no usages; `null` by default.
  RegExp? get localeKeyUsagePattern => null;

  /// The paths whose changes in the source tree do not count as an edit of
  /// the code. They are relative to the root of the project. Empty by
  /// default.
  List<String> get sourceDirtyIgnores => const [];

  /// Publishes the screenshots of a page. It is `null` when the project keeps
  /// them beside the page or inside it; `null` by default.
  AtlasShotPublisher? get shotPublisher => null;

  /// The tables of project data the page shows, read from the atlas [store]
  /// holds; empty by default.
  ///
  /// A project that returns no table with the id [AtlasTable.localeKeysId]
  /// gets the table of the translation keys that the atlas builds itself. This
  /// applies when the default locale has translations.
  List<AtlasTable> tables(AtlasStoreReader store) => const [];

  /// The translations the app shows in [locale], by key; empty by default. An
  /// empty map makes the atlas read the file [AtlasPaths.translations] names.
  Map<String, Object?> translations(String locale) => const {};

  /// The link to the design of [screen]; `null` when the project has none, and
  /// `null` by default.
  String? designLink(String screen) => null;

  /// Writes the reports of the project that read the atlas [store] holds;
  /// writes nothing by default.
  void writeReports(AtlasStoreReader store) {}

  /// Whether the analytics [record] matches the analytics catalogue of the
  /// project. The catalogue knows its event and its parameters fit the event.
  ///
  /// The project removes the parameters every record holds before it
  /// compares. A project without an analytics catalogue keeps the default,
  /// `true`, so the atlas accepts every event.
  bool isCataloguedAnalytics(Map<String, Object?> record) => true;
}
