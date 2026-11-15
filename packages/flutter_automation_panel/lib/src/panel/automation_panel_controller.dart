import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/src/panel/automation_journal_record.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_definition.dart';

/// {@category StateManagement}
///
/// The state of the panel: what the mock holds and the changes a tester makes.
///
/// The controller applies a change to the mock at once and tells its listeners.
/// A scenario that an agent command replaces does not reach the listeners.
///
/// The controller also follows the journal of the mock: a request of a later
/// step moves the manual walk forward. It handles the system back button while
/// the panel is open, so the project creates it before the app builds its
/// widgets.
class AutomationPanelController extends ChangeNotifier
    with WidgetsBindingObserver {
  /// The definition the panel shows.
  final AutomationPanelDefinition definition;

  /// Key of the navigator that holds the pages of the panel.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Whether the panel page of the app shows now.
  bool isPanelOpen = false;

  /// Whether the walk strip is open.
  bool isWalkExpanded = false;

  /// Whether the tester swiped the walk strip away.
  bool isWalkHidden = false;

  /// Title of the outcome that the tester chose last, missing when none.
  String? outcomeTitle;

  Map<String, MockApiFailure> _variantFailures = const {};
  int _lastSeenSeq = -1;
  bool _isDisposed = false;

  /// Creates the controller of [definition].
  AutomationPanelController(this.definition) {
    _variantFailures = _readFailures({
      MockScenario.failuresKey: mock.outcomeFailures,
    });

    WidgetsFlutterBinding.ensureInitialized().addObserver(this);
    mock.journal.addListener(_followJournal);
  }

  /// The mock the panel changes.
  AutomationMock get mock => definition.mock;

  /// Failed paths the scenario holds.
  Map<String, MockApiFailure> get failures => mock.failures;

  /// How many requests answer with an override.
  int get overrideCount => failures.length;

  /// Whether the scenario differs from the mock defaults.
  bool get isChanged => mock.scenario.toJson().isNotEmpty;

  /// The manual walk in progress, missing when none runs.
  AutomationWalkProgress? get walk => mock.walk;

  /// The flow of the walk in progress, missing when none runs.
  AutomationCatalogueFlow? get walkFlow {
    final current = walk;

    if (current == null) {
      return null;
    }

    return _findFlow(current.flow);
  }

  /// The steps the walk shows: the steps of its variant that a person sees.
  List<AutomationCatalogueStep> get walkSteps {
    final variant = _walkVariant;

    if (variant == null) {
      return const [];
    }

    return variant.steps.where((step) => !step.isService).toList();
  }

  AutomationCatalogueVariant? get _walkVariant {
    final current = walk;

    return walkFlow?.variants.firstWhereOrNull(
      (variant) => variant.name == current?.variant,
    );
  }

  Map<String, MockApiFailure> get _testerFailures {
    return {
      for (final MapEntry(:key, :value) in failures.entries)
        if (_variantFailures[key] != value) key: value,
    };
  }

  /// The failure that replaces the answer of [path], missing when the mock
  /// answers it.
  ///
  /// A failure set for a path also fails the paths one segment longer, as the
  /// mock does for an endpoint with a path id.
  MockApiFailure? failureOf(String path) {
    final key = _resolveFailureKey(path);

    if (key == null) {
      return null;
    }

    return failures[key];
  }

  @override
  Future<bool> didPopRoute() async {
    final navigator = navigatorKey.currentState;

    if (!isPanelOpen || navigator == null) {
      return false;
    }

    final didPop = await navigator.maybePop();

    if (!didPop) {
      closePanel();
    }

    return true;
  }

  /// Makes [path] answer with [failure], or with the mock answer when [failure]
  /// is `null`.
  ///
  /// A `null` [failure] clears the override that [failureOf] names for
  /// [path], also when the override stands on the shorter path.
  Future<void> setFailure(String path, MockApiFailure? failure) async {
    final before = mock.scenario;
    final key = failure == null ? _resolveFailureKey(path) ?? path : path;
    final isOutcomeFailure =
        failure == null && _variantFailures.containsKey(key);

    await mock.setFailure(key, failure);

    if (isOutcomeFailure) {
      _variantFailures = {..._variantFailures}..remove(key);

      await mock.saveOutcomeFailures(_failuresMap(_variantFailures));
    }

    await _askForRestart(before, mock.scenario);

    notifyListeners();
  }

  /// Replaces the scenario with [scenario] and keeps the overrides of the
  /// tester. The failures of the outcome and the overrides of the tester merge,
  /// and a tester override wins on the same path.
  ///
  /// The [scenario] parameter is the scenario JSON of the outcome.
  /// The [title] parameter names the outcome in the status row.
  /// The [walk] parameter is a manual walk to save with the scenario, so a
  /// restart keeps it.
  /// Returns whether the scenario needs a restart of the app that has not
  /// happened yet. A project then stops here and starts no flow.
  Future<bool> applyOutcome(
    Map<String, Object?> scenario, {
    String? title,
    AutomationWalkProgress? walk,
  }) async {
    final tester = _testerFailures;

    _variantFailures = _readFailures(scenario);

    await mock.saveOutcomeFailures(_failuresMap(_variantFailures));

    final next = MockScenario.fromJson({
      ...scenario,
      ..._failuresJson({..._variantFailures, ...tester}),
    });
    final before = mock.scenario;

    outcomeTitle = title;

    if (walk != null) {
      isWalkHidden = false;
      isWalkExpanded = false;

      await mock.saveWalk(walk);
    }

    await mock.updateScenario(next);

    notifyListeners();

    await _askForRestart(before, next);

    return mock.requiresRestart(next);
  }

  /// Replaces the scenario with [scenario], as `updateScenario` does.
  ///
  /// The [title] parameter names the new state in the status row. The current
  /// name stays when it is missing.
  Future<void> updateScenario(MockScenario scenario, {String? title}) async {
    final before = mock.scenario;

    if (title != null) {
      outcomeTitle = title;
    }

    await mock.updateScenario(scenario);
    await _askForRestart(before, scenario);

    notifyListeners();
  }

  /// Clears every override and every setting of the scenario.
  Future<void> reset() async {
    outcomeTitle = null;
    _variantFailures = const {};

    await mock.saveOutcomeFailures(const {});
    await mock.saveWalk(null);
    await updateScenario(const MockScenario([]));
  }

  /// Whether [scenario] holds a change that needs a restart.
  bool requiresRestart(Map<String, Object?> scenario) {
    return mock.requiresRestart(MockScenario.fromJson(scenario));
  }

  /// Starts a manual walk of [variant] of [flow].
  Future<void> startWalk(String flow, String variant) async {
    isWalkHidden = false;
    isWalkExpanded = false;

    await mock.saveWalk(AutomationWalkProgress(flow: flow, variant: variant));

    notifyListeners();
  }

  /// Moves the walk to the step [stepIndex].
  Future<void> moveWalk(int stepIndex) async {
    final current = walk;

    if (current == null || current.stepIndex == stepIndex) {
      return;
    }

    await mock.saveWalk(current.atStep(stepIndex));

    notifyListeners();
  }

  /// Ends the walk.
  Future<void> finishWalk() async {
    await mock.saveWalk(null);

    notifyListeners();
  }

  /// Opens or closes the walk strip.
  void toggleWalk() {
    isWalkExpanded = !isWalkExpanded;

    notifyListeners();
  }

  /// Hides the walk strip until the tester opens the panel again.
  void hideWalk() {
    isWalkHidden = true;
    isWalkExpanded = false;

    notifyListeners();
  }

  /// Shows the panel page of the app and shows the walk strip again when the
  /// tester hid it.
  void openPanel() {
    isPanelOpen = true;
    isWalkHidden = false;

    notifyListeners();
  }

  /// Closes the panel page of the app.
  void closePanel() {
    isPanelOpen = false;

    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) {
      return;
    }

    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;

    WidgetsBinding.instance.removeObserver(this);
    mock.journal.removeListener(_followJournal);
    super.dispose();
  }

  AutomationCatalogueFlow? _findFlow(String name) {
    return definition.catalogue.flows.firstWhereOrNull(
      (flow) => flow.name == name,
    );
  }

  String? _resolveFailureKey(String path) {
    final current = failures;
    final parentEnd = path.lastIndexOf('/');

    if (current.containsKey(path)) {
      return path;
    }

    if (parentEnd <= 0) {
      return null;
    }

    final parent = path.substring(0, parentEnd);

    return current.containsKey(parent) ? parent : null;
  }

  Map<String, MockApiFailure> _readFailures(Map<String, Object?> scenario) {
    final json = scenario[MockScenario.failuresKey];

    if (json is! Map<String, Object?>) {
      return const {};
    }

    return {
      for (final MapEntry(:key, :value) in json.entries)
        if (value is Map<String, Object?>) key: MockApiFailure.fromJson(value),
    };
  }

  Map<String, Object?> _failuresJson(Map<String, MockApiFailure> failures) {
    if (failures.isEmpty) {
      return const {};
    }

    return {MockScenario.failuresKey: _failuresMap(failures)};
  }

  Map<String, Object?> _failuresMap(Map<String, MockApiFailure> failures) {
    return {
      for (final MapEntry(:key, :value) in failures.entries)
        key: value.toJson(),
    };
  }

  Future<void> _askForRestart(MockScenario before, MockScenario next) async {
    if (!_changesRestartKey(before, next)) {
      return;
    }

    if (mock.requiresRestart(next)) {
      await definition.onRestartRequired();
    }
  }

  bool _changesRestartKey(MockScenario before, MockScenario next) {
    final current = before.toJson();
    final wanted = next.toJson();

    return mock.sections.any(
      (section) => section.changesRestartKey(current, wanted),
    );
  }

  void _followJournal() {
    final records = mock.journal.records;

    if (records.isEmpty) {
      _lastSeenSeq = -1;

      return;
    }

    records.forEach(_followRecord);
  }

  void _followRecord(Map<String, Object?> record) {
    final seq = AutomationJournalRecord.seqOf(record);
    final path = AutomationJournalRecord.pathOf(record);

    if (seq == null || path == null) {
      return;
    }

    if (seq <= _lastSeenSeq) {
      return;
    }

    _lastSeenSeq = seq;

    _moveWalkPast(path);
  }

  void _moveWalkPast(String path) {
    final current = walk;
    final steps = walkSteps;

    if (current == null) {
      return;
    }

    for (int index = current.stepIndex; index < steps.length; index += 1) {
      if (steps[index].requests.any((request) => request.path == path)) {
        moveWalk(min(index + 1, steps.length - 1));

        return;
      }
    }
  }
}
