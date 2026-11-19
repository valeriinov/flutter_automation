import 'package:flutter_automation_atlas/src/atlas_headless_settings.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_schema.dart';
import 'package:flutter_automation_atlas/src/atlas_launch_settings.dart';
import 'package:flutter_automation_atlas/src/atlas_paths.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_publisher.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_settings.dart';
import 'package:flutter_automation_atlas/src/atlas_table.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';

/// {@category Utils}
///
/// Everything the atlas needs to know about one project: where it keeps its
/// files, how it starts, what its journal looks like and what it shows on the
/// page beside the flows.
///
/// A project extends this class once and passes it to `runAtlas`. The members
/// with a body have a default for a project without that data: no tables, no
/// translations, no screen descriptions, no design links, no reports, no shot
/// publisher, and every analytics event accepted.
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
  /// by locale; empty by default.
  Map<String, Map<String, String>> get screenDescriptions => const {};

  /// The paths a change in which the source tree does not count as an edit
  /// of the code, relative to the root of the project; empty by default.
  List<String> get sourceDirtyIgnores => const [];

  /// Publishes the screenshots of a page, absent when the project keeps them
  /// beside the page or inside it; absent by default.
  AtlasShotPublisher? get shotPublisher => null;

  /// The tables of project data the page shows, read from the atlas stored in
  /// [store]; empty by default.
  List<AtlasTable> tables(String store) => const [];

  /// The translations the app shows in [locale], by key; empty by default.
  Map<String, Object?> translations(String locale) => const {};

  /// The link to the design of [screen], absent when the project has none;
  /// absent by default.
  String? designLink(String screen) => null;

  /// Writes the reports of the project that read the atlas stored in
  /// [store]; writes nothing by default.
  void writeReports(String store) {}

  /// Whether the analytics [record] matches the analytics catalogue of the
  /// project: its event is known and its parameters fit the event.
  ///
  /// The project removes the parameters every record holds before it
  /// compares. A project without an analytics catalogue keeps the default,
  /// `true`, so the atlas accepts every event.
  bool isCataloguedAnalytics(Map<String, Object?> record) => true;
}
