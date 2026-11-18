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
/// A project implements this interface once and passes it to `runAtlas`.
abstract interface class AtlasProject {
  /// The places of the project the atlas reads and writes.
  AtlasPaths get paths;

  /// How the atlas starts the app on a simulator.
  AtlasLaunchSettings get launch;

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

  /// The tables of project data the page shows, read from the atlas stored in
  /// [store].
  List<AtlasTable> tables(String store);

  /// The translations the app shows in [locale], by key.
  Map<String, Object?> translations(String locale);

  /// The prose that describes each design screen, by design screen and then
  /// by locale.
  Map<String, Map<String, String>> get screenDescriptions;

  /// The link to the design of [screen], absent when the project has none.
  String? designLink(String screen);

  /// The name of the project; the page shows it and prefixes the keys it
  /// keeps in the browser with it.
  String get projectName;

  /// The group a flow joins when it declares none.
  AutomationFlowGroup get defaultGroup;

  /// The groups of the page in display order. A group names its area, and
  /// the page lists the areas in the order they first stand.
  List<AutomationFlowGroup> get groupOrder;

  /// The paths a change in which the source tree does not count as an edit
  /// of the code, relative to the root of the project.
  List<String> get sourceDirtyIgnores;

  /// Writes the reports of the project that read the atlas stored in
  /// [store].
  void writeReports(String store);

  /// Publishes the screenshots of a page, absent when the project keeps them
  /// beside the page or inside it.
  AtlasShotPublisher? get shotPublisher;

  /// The locales the atlas captures and the page shows; the first one is the
  /// default.
  List<String> get locales;

  /// Whether the analytics [record] matches the analytics catalogue of the
  /// project: its event is known and its parameters fit the event.
  ///
  /// The project removes the parameters every record holds before it
  /// compares. A project without an analytics catalogue returns `true`, so the
  /// atlas accepts every event.
  bool isCataloguedAnalytics(Map<String, Object?> record);
}
