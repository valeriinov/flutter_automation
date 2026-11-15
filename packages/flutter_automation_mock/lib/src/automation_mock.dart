import 'dart:async';
import 'dart:convert';

import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_failure.dart';
import 'package:flutter_automation_mock/src/mock_scenario_file.dart';
import 'package:flutter_automation_mock/src/scenario/mock_commands.dart';
import 'package:flutter_automation_mock/src/scenario/mock_section.dart';
import 'package:flutter_automation_mock/src/scenario/mock_scenario.dart';
import 'package:flutter_automation_mock/src/scenario/mock_scenario_reader.dart';
import 'package:flutter_automation_mock/src/state/automation_state_store.dart';
import 'package:flutter_automation_mock/src/state/automation_walk_progress.dart';
import 'package:flutter_automation_mock/src/state/mock_journal.dart';
import 'package:flutter_automation_mock/src/transport/mock_latency.dart';

/// {@category Utils}
///
/// Hook the project runs after the mock applied the [scenario] of a run.
typedef MockScenarioAppliedCallback =
    FutureOr<void> Function(MockScenario scenario);

/// {@category Utils}
///
/// Hook the project runs after [AutomationMock.updateScenario] replaced the
/// scenario.
typedef MockScenarioUpdatedCallback =
    FutureOr<void> Function(MockScenario scenario);

/// {@category Utils}
///
/// Entry of the mock in an app: the scenario of the run, the substitutes and
/// the commands an agent sends.
///
/// The project decides with one parameter, `isEnabled`, whether the app runs on
/// the mock. [init] runs before the dependency injection of the project and
/// answers the object the project reads its scenario from. A disabled mock
/// registers no command and [substitute] answers the real object.
///
/// An enabled mock registers two commands in [AutomationCommandRegistry]:
///
/// - `scenario.apply` takes `{"scenario": <scenario JSON>}`, saves the
///   scenario for the next launch, runs `onScenarioApplied` and empties the
///   [journal]. It answers `{"latency": <name>, "failures": [<path>]}`.
/// - `journal.read` answers `{"records": [...], "launch": {...}}` and empties
///   the [journal].
///
/// A project that passes a `stateStore` lets a tester change the mock while the
/// app runs. [updateScenario] and [setFailure] replace the scenario at once, do
/// not seed the app again and keep the [journal]. They save the choice in the
/// store, and the next launch starts from it. [requiresRestart] tells whether a
/// scenario holds a change that only a restart applies.
class AutomationMock {
  static const _scenarioKey = 'scenario';
  static const _recordsKey = 'records';
  static const _launchKey = 'launch';
  static const _failuresKey = 'failures';
  static const _defaultJournalResponseTimeout = Duration(seconds: 10);

  /// What the app did while a run walked it.
  final MockJournal journal = MockJournal();

  /// Sections of the mock the project declared.
  ///
  /// The package keeps the list for tools that build a form from the settings
  /// of the sections. Nothing in the package reads it.
  final List<MockSection<Object?>> sections;

  /// Whether the app runs on the mock.
  final bool isEnabled;

  final String _scenarioDirectory;
  final AutomationStateStore? _stateStore;
  final MockScenarioAppliedCallback? _onScenarioApplied;
  final MockScenarioUpdatedCallback? _onScenarioUpdated;
  final Duration _journalResponseTimeout;

  MockScenario _scenario;
  MockScenario _launchScenario;
  AutomationWalkProgress? _walk;
  Map<String, Object?> _outcomeFailures = const {};

  AutomationMock._({
    required this.isEnabled,
    required this.sections,
    required String scenarioDirectory,
    required AutomationStateStore? stateStore,
    required MockScenarioAppliedCallback? onScenarioApplied,
    required MockScenarioUpdatedCallback? onScenarioUpdated,
    required Duration journalResponseTimeout,
  }) : _scenarioDirectory = scenarioDirectory,
       _stateStore = stateStore,
       _scenario = const MockScenario([]),
       _launchScenario = const MockScenario([]),
       _onScenarioApplied = onScenarioApplied,
       _onScenarioUpdated = onScenarioUpdated,
       _journalResponseTimeout = journalResponseTimeout;

  /// Starts the mock before the dependency injection of the project.
  ///
  /// The scenario of the run is the one the previous `scenario.apply` saved in
  /// [scenarioDirectory], or an empty one when it saved none. The launch reads
  /// the file once and removes it.
  ///
  /// The [isEnabled] parameter is the project's decision to run on the mock.
  /// The [scenarioDirectory] parameter is a writable folder that holds the
  /// scenario file between launches.
  /// The [sections] parameter lists the sections of the mock; the package only
  /// keeps it.
  /// The [onScenarioApplied] parameter runs after `scenario.apply` applied its
  /// own part.
  /// The [stateStore] parameter holds the choice of a tester between launches.
  /// A scenario file that `scenario.apply` saved wins over the scenario of the
  /// store, also when the file holds an empty scenario.
  /// The [onScenarioUpdated] parameter runs after [updateScenario] replaced
  /// the scenario.
  /// The [journalResponseTimeout] parameter bounds how long `journal.read`
  /// waits for the requests that the mock still has to answer.
  static Future<AutomationMock> init({
    required bool isEnabled,
    required String scenarioDirectory,
    List<MockSection<Object?>> sections = const [],
    AutomationStateStore? stateStore,
    MockScenarioAppliedCallback? onScenarioApplied,
    MockScenarioUpdatedCallback? onScenarioUpdated,
    Duration journalResponseTimeout = _defaultJournalResponseTimeout,
  }) {
    // The AOT compiler drops the fakes of a release build only while the
    // constructor runs outside an async body and gets a constant isEnabled.
    return AutomationMock._(
      isEnabled: isEnabled,
      sections: sections,
      scenarioDirectory: scenarioDirectory,
      stateStore: stateStore,
      onScenarioApplied: onScenarioApplied,
      onScenarioUpdated: onScenarioUpdated,
      journalResponseTimeout: journalResponseTimeout,
    )._start();
  }

  /// Scenario of the run: the saved one at launch, the applied one after
  /// `scenario.apply`.
  MockScenario get scenario => _scenario;

  /// The scenario that the launch started from.
  ///
  /// What the app read once at launch matches it.
  MockScenario get launchScenario => _launchScenario;

  /// The store of the choice of a tester, missing when the project passes none.
  AutomationStateStore? get stateStore => _stateStore;

  /// The manual walk in progress, missing when none runs.
  AutomationWalkProgress? get walk => _walk;

  /// The `failures` JSON of the outcome the tester chose last.
  Map<String, Object?> get outcomeFailures => _outcomeFailures;

  /// How long `journal.read` waits for the requests that the mock still has
  /// to answer.
  Duration get journalResponseTimeout => _journalResponseTimeout;

  /// Latency of a mocked answer: the profile of the `latency` key of the
  /// [scenario] (`realistic` when absent or unknown) and the `latencySeed` key
  /// (0 when absent).
  MockLatency get latency => MockScenarioReader.readLatency(_scenario);

  /// Failed paths of the `failures` key of the [scenario]: path to failure.
  Map<String, MockApiFailure> get failures {
    return MockScenarioReader.readFailures(_scenario);
  }

  /// Answers [fake] when the mock is enabled and [real] otherwise.
  ///
  /// The [real] parameter is the object the app uses without the mock.
  /// The [fake] parameter builds the stand-in; it receives this mock.
  T substitute<T>({
    required T real,
    required T Function(AutomationMock mock) fake,
  }) {
    return isEnabled ? fake(this) : real;
  }

  /// Settings of [section] in the current [scenario].
  S settingsOf<S>(MockSection<S> section) => scenario.settingsOf(section);

  /// Replaces the scenario at once and saves it for the next launch.
  ///
  /// The call runs `onScenarioUpdated`. It neither seeds the app again nor
  /// empties the [journal].
  ///
  /// The [scenario] parameter is the new scenario.
  Future<void> updateScenario(MockScenario scenario) async {
    _scenario = scenario;

    await _saveState();
    await _onScenarioUpdated?.call(_scenario);
  }

  /// Makes the path [path] fail with [failure], or answer normally when
  /// [failure] is `null`. Every other key of the scenario stays.
  ///
  /// The [path] parameter is the path of the request.
  /// The [failure] parameter is the answer that replaces the payload.
  Future<void> setFailure(String path, MockApiFailure? failure) {
    final json = _scenario.toJson();
    final current = json[MockScenario.failuresKey];
    final failures = <String, Object?>{
      if (current is Map<String, Object?>) ...current,
    };

    if (failure == null) {
      failures.remove(path);
    } else {
      failures[path] = failure.toJson();
    }

    if (failures.isEmpty) {
      json.remove(MockScenario.failuresKey);
    } else {
      json[MockScenario.failuresKey] = failures;
    }

    return updateScenario(MockScenario.fromJson(json));
  }

  /// Whether [next] holds a change that only a restart of the app applies.
  ///
  /// The comparison is against the scenario of the launch, on the
  /// `restartKeys` of each section.
  ///
  /// The [next] parameter is the scenario the tester wants.
  bool requiresRestart(MockScenario next) {
    final launch = _launchScenario.toJson();
    final wanted = next.toJson();

    return sections.any((section) => section.changesRestartKey(launch, wanted));
  }

  /// Saves the manual walk, or ends it when [walk] is `null`.
  ///
  /// The [walk] parameter is where the walk stands.
  Future<void> saveWalk(AutomationWalkProgress? walk) async {
    _walk = walk;

    await _saveState();
  }

  /// Saves the `failures` JSON of the outcome the tester chose.
  ///
  /// The [failures] parameter is the `failures` JSON of the outcome.
  Future<void> saveOutcomeFailures(Map<String, Object?> failures) async {
    _outcomeFailures = failures;

    await _saveState();
  }

  Future<AutomationMock> _start() async {
    if (isEnabled) {
      final scenarioJson = await MockScenarioFile.tryConsume(
        _scenarioDirectory,
      );
      final state = await _stateStore?.read();

      final startJson =
          scenarioJson ?? state?.scenario ?? const <String, Object?>{};

      _scenario = MockScenario.fromJson(startJson);
      _launchScenario = _scenario;

      if (scenarioJson == null) {
        _walk = state?.walk;
        _outcomeFailures = state?.outcomeFailures ?? const {};
      }

      _registerCommands();
    }

    return this;
  }

  Future<void> _saveState() async {
    final scenario = _scenario.toJson();
    final walk = _walk;
    final outcomeFailures = _outcomeFailures;

    await _stateStore?.update(
      (state) => state.copyWith(
        scenario: scenario,
        walk: walk,
        hasWalk: true,
        outcomeFailures: outcomeFailures,
      ),
    );
  }

  void _registerCommands() {
    AutomationCommandRegistry.register(
      MockCommands.scenarioApply,
      _applyScenario,
    );
    AutomationCommandRegistry.register(MockCommands.journalRead, _readJournal);
  }

  // The journal is emptied last, so a run reads only what the app did after the
  // scenario was applied.
  Future<String> _applyScenario(Map<String, Object?> payload) async {
    final scenarioJson = _readScenarioJson(payload);

    await MockScenarioFile.save(_scenarioDirectory, scenarioJson);

    _scenario = MockScenario.fromJson(scenarioJson);
    _walk = null;
    _outcomeFailures = const {};

    await _saveState();
    await _onScenarioApplied?.call(_scenario);

    journal.clear();

    return jsonEncode(_buildApplyAnswer(_scenario.toJson()));
  }

  Future<String> _readJournal(Map<String, Object?> payload) async {
    await _waitForResponses();

    return jsonEncode({
      _recordsKey: journal.readAndClear(),
      _launchKey: journal.launch,
    });
  }

  Map<String, Object?> _readScenarioJson(Map<String, Object?> payload) {
    final scenarioJson = payload[_scenarioKey];

    if (scenarioJson is! Map<String, Object?>) {
      throw StateError(
        'The "${MockCommands.scenarioApply}" command needs a '
        '"$_scenarioKey" object.',
      );
    }

    return scenarioJson;
  }

  Map<String, Object?> _buildApplyAnswer(Map<String, Object?> scenarioJson) {
    final failures = scenarioJson[MockScenario.failuresKey];

    return {
      MockScenario.latencyKey: MockScenarioReader.readLatencyProfile(
        _scenario,
      ).name,
      _failuresKey: failures is Map<String, Object?>
          ? failures.keys.toList()
          : const <String>[],
    };
  }

  Future<void> _waitForResponses() async {
    try {
      await journal.waitForResponses().timeout(_journalResponseTimeout);
    } on TimeoutException {
      throw StateError(
        'The mock left ${jsonEncode(journal.requestsAwaitingResponse)} '
        'unanswered for ${_journalResponseTimeout.inSeconds} s.',
      );
    }
  }
}
