import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_panel/src/pages/automation_catalogue_text.dart';
import 'package:flutter_automation_panel/src/panel/automation_journal_record.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_definition.dart';
import 'package:flutter_automation_panel/src/panel/automation_run_summary.dart';
import 'package:flutter_automation_panel/src/player/automation_flow_player.dart';
import 'package:flutter_automation_panel/src/player/automation_player_exception.dart';

/// {@category StateManagement}
///
/// The state of the panel: what the mock holds and the changes a tester makes.
///
/// The controller applies a change to the mock at once and tells its listeners.
/// A scenario that an agent command replaces does not reach the listeners.
///
/// The controller also drives the walk of a flow. A manual walk does one
/// action per [playNext]. An autorun does every step in a row. The
/// [AutomationFlowPlayer] does each step inside the app. The controller
/// handles the system back button while the panel is open and while a walk
/// runs. The project therefore creates it before the app builds its widgets.
class AutomationPanelController extends ChangeNotifier
    with WidgetsBindingObserver {
  /// The definition the panel shows.
  final AutomationPanelDefinition definition;

  /// Plays the steps of the walk inside the app.
  final AutomationFlowPlayer player;

  /// Key of the navigator that holds the pages of the panel.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Whether the panel page of the app shows now.
  bool isPanelOpen = false;

  /// Whether the walk plaque is open.
  bool isWalkExpanded = false;

  /// Whether the player does a step now.
  bool isWalkBusy = false;

  /// Whether the launcher shows its controls. The launcher sets it. A walk
  /// blocks the finger and the system back button only while it is true.
  bool isLauncherVisible = false;

  /// Why the player stopped, missing when it did not.
  String? walkFailure;

  /// What the last autorun did, missing until an autorun ends.
  AutomationRunSummary? runSummary;

  /// Title of the outcome that the tester chose last, missing when none.
  String? outcomeTitle;

  Map<String, MockApiFailure> _variantFailures = const {};
  int _resolvedForkStep = -1;
  int _runToken = 0;
  bool _hasResumed = false;
  bool _isDisposed = false;
  Stopwatch? _runWatch;

  /// Creates the controller of [definition].
  ///
  /// The [player] parameter plays the steps. It defaults to a player over the
  /// `playerSettings` and the `catalogue` of [definition].
  AutomationPanelController(this.definition, {AutomationFlowPlayer? player})
    : player =
          player ??
          AutomationFlowPlayer(
            settings: definition.playerSettings,
            catalogue: definition.catalogue,
          ) {
    _variantFailures = _readFailures({
      MockScenario.failuresKey: mock.outcomeFailures,
    });

    WidgetsFlutterBinding.ensureInitialized().addObserver(this);
  }

  /// The mock the panel changes.
  AutomationMock get mock => definition.mock;

  /// Failed paths the scenario holds.
  Map<String, MockApiFailure> get failures => mock.failures;

  /// How many requests answer with an override.
  int get overrideCount => failures.length;

  /// Whether the scenario differs from the mock defaults.
  bool get isChanged => mock.scenario.toJson().isNotEmpty;

  /// The walk in progress, missing when none runs.
  AutomationWalkProgress? get walk => mock.walk;

  /// The flow of the walk in progress, missing when none runs.
  AutomationCatalogueFlow? get walkFlow {
    final current = walk;

    if (current == null) {
      return null;
    }

    return _findFlow(current.flow);
  }

  /// The variant the walk follows, missing when none runs.
  AutomationCatalogueVariant? get walkVariant {
    final current = walk;

    return walkFlow?.variants.firstWhereOrNull(
      (variant) => variant.name == current?.variant,
    );
  }

  /// The steps of the walk, service steps included. [AutomationWalkProgress]
  /// counts in these steps.
  List<AutomationCatalogueStep> get walkSteps => walkVariant?.steps ?? const [];

  /// Whether a walk is in progress and its variant is in the catalogue.
  bool get isWalkActive => walk != null && walkVariant != null;

  /// Whether the walk blocks the finger and the system back button: a walk is
  /// in progress and the launcher shows its controls.
  bool get isInputBlocked => isLauncherVisible && isWalkActive;

  /// Whether an autorun plays its steps now. The launcher hides the plaque
  /// and the QA button then.
  bool get isAutorunPlaying {
    return walk?.mode == AutomationWalkMode.autorun && isWalkBusy;
  }

  /// Whether the walk has done every step.
  bool get isWalkFinished {
    final current = walk;

    return current != null && current.stepIndex >= walkSteps.length;
  }

  /// The next action of the walk, missing when none is left.
  AutomationCatalogueStep? get nextAction {
    final current = walk;
    final steps = walkSteps;

    if (current == null) {
      return null;
    }

    return steps
        .skip(current.stepIndex)
        .firstWhereOrNull(AutomationFlowPlayer.isAction);
  }

  /// How many actions the walk has done.
  int get doneActionCount {
    final current = walk;

    return walkSteps
        .take(current?.stepIndex ?? 0)
        .where(AutomationFlowPlayer.isAction)
        .length;
  }

  /// How many actions the variant of the walk holds.
  int get actionCount {
    return walkSteps.where(AutomationFlowPlayer.isAction).length;
  }

  /// The fork the walk waits at, missing when the walk stands elsewhere, the
  /// tester chose already or fewer than two branches can be taken.
  AutomationCatalogueFork? get pendingFork {
    final fork = walkFlow?.fork;
    final current = walk;

    if (fork == null || current == null) {
      return null;
    }

    final isAtFork = current.stepIndex == fork.stepIndex;

    if (!isAtFork || _resolvedForkStep == fork.stepIndex) {
      return null;
    }

    return forkChoices.length < 2 ? null : fork;
  }

  /// The branches the tester can take at the fork without a restart.
  List<AutomationCatalogueBranch> get forkChoices {
    final flow = walkFlow;
    final fork = flow?.fork;

    if (flow == null || fork == null) {
      return const [];
    }

    return fork.branches.where((branch) {
      final variant = _findVariant(flow, branch.variant);

      return variant != null && !requiresRestart(variant.scenario);
    }).toList();
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
      return isInputBlocked;
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
  /// The [walk] parameter is a walk to save with the scenario, so a restart
  /// keeps it.
  /// Returns whether the scenario needs a restart of the app that has not
  /// happened yet. A project then stops here and starts no flow.
  Future<bool> applyOutcome(
    Map<String, Object?> scenario, {
    String? title,
    AutomationWalkProgress? walk,
  }) async {
    final saved = await _saveOutcome(scenario, title: title, walk: walk);

    await _askForRestart(saved.before, saved.next);

    return mock.requiresRestart(saved.next);
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
    await exitWalk();
    await updateScenario(const MockScenario([]));
  }

  /// Whether [scenario] holds a change that needs a restart.
  bool requiresRestart(Map<String, Object?> scenario) {
    return mock.requiresRestart(MockScenario.fromJson(scenario));
  }

  /// Saves a walk of [variant] of [flow] with the scenario of the variant and
  /// calls `onRestartRequired` of the definition once, whatever the scenario
  /// held before. The walk begins after the restart.
  ///
  /// The [flow] parameter is the name of the flow. The [variant] parameter is
  /// the name of the variant. The [mode] parameter says who moves the walk.
  /// The [shouldShowTouches] and [shouldSignalEnd] parameters are the options
  /// of an autorun.
  Future<void> startWalk(
    String flow,
    String variant, {
    AutomationWalkMode mode = AutomationWalkMode.manual,
    bool shouldShowTouches = true,
    bool shouldSignalEnd = true,
  }) async {
    final chosen = _findVariant(_findFlow(flow), variant);

    _runToken += 1;
    _resolvedForkStep = -1;
    isWalkBusy = false;
    isWalkExpanded = false;
    walkFailure = null;
    runSummary = null;

    await _saveOutcome(
      chosen?.scenario ?? const {},
      title: AutomationCatalogueText.english(chosen?.title, variant),
      walk: AutomationWalkProgress(
        flow: flow,
        variant: variant,
        mode: mode,
        shouldShowTouches: shouldShowTouches,
        shouldSignalEnd: shouldSignalEnd,
      ),
    );
    await definition.onRestartRequired();
  }

  /// Does the next action of the walk and the waits that follow it.
  ///
  /// The walk stops before the fork, where the tester picks a branch, and when
  /// the player cannot do a step. [walkFailure] then holds the reason.
  Future<void> playNext() => _play(isUntilAction: true);

  /// Does every step left of the walk. An autorun ends with [runSummary].
  Future<void> runWalk() => _play(isUntilAction: false);

  /// Takes the branch [variant] at the fork the walk waits at: the scenario of
  /// the variant applies and the walk goes on in the variant.
  Future<void> chooseBranch(String variant) async {
    final current = walk;
    final flow = walkFlow;
    final fork = pendingFork;
    final chosen = flow == null ? null : _findVariant(flow, variant);

    if (current == null || fork == null || chosen == null) {
      return;
    }

    _resolvedForkStep = fork.stepIndex;

    await applyOutcome(
      chosen.scenario,
      title: AutomationCatalogueText.english(chosen.title, variant),
      walk: current.onVariant(variant),
    );
  }

  /// Ends the walk and gives the finger back. The app stays on its screen.
  Future<void> exitWalk() async {
    _runToken += 1;
    _resolvedForkStep = -1;
    isWalkBusy = false;
    isWalkExpanded = false;
    walkFailure = null;
    runSummary = null;

    await mock.saveWalk(null);

    notifyListeners();
  }

  /// Starts the autorun that the last launch saved. The launcher calls it once
  /// after its first frame.
  void resumeWalk() {
    if (_hasResumed) {
      return;
    }

    _hasResumed = true;

    if (walk?.mode == AutomationWalkMode.autorun) {
      runWalk();
    }
  }

  /// Opens or closes the walk plaque.
  void toggleWalk() {
    isWalkExpanded = !isWalkExpanded;

    notifyListeners();
  }

  /// Shows the panel page of the app.
  void openPanel() {
    isPanelOpen = true;

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
    _runToken += 1;

    WidgetsBinding.instance.removeObserver(this);
    player.dispose();
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

  Future<({MockScenario before, MockScenario next})> _saveOutcome(
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
      await mock.saveWalk(walk);
    }

    await mock.updateScenario(next);

    notifyListeners();

    return (before: before, next: next);
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

  AutomationCatalogueVariant? _findVariant(
    AutomationCatalogueFlow? flow,
    String name,
  ) {
    return flow?.variants.firstWhereOrNull((variant) => variant.name == name);
  }

  Future<void> _play({required bool isUntilAction}) async {
    if (walk == null || walkVariant == null || isWalkBusy) {
      return;
    }

    final token = ++_runToken;

    isWalkBusy = true;
    walkFailure = null;
    _runWatch ??= Stopwatch()..start();

    notifyListeners();

    try {
      await _playSteps(token, isUntilAction: isUntilAction);
    } on AutomationPlayerException catch (error) {
      _recordFailure(token, error.reason);
    } on Object catch (error) {
      _recordFailure(token, 'The step failed: $error');
    } finally {
      if (token == _runToken) {
        isWalkBusy = false;
      }
    }

    if (token != _runToken) {
      return;
    }

    await _finishAutorun();

    notifyListeners();
  }

  Future<void> _playSteps(int token, {required bool isUntilAction}) async {
    final steps = walkSteps;
    bool didAction = false;

    while (token == _runToken) {
      final progress = walk;

      if (progress == null || progress.stepIndex >= steps.length) {
        return;
      }

      final step = steps[progress.stepIndex];

      if (_shouldPause(step, didAction, isUntilAction: isUntilAction)) {
        return;
      }

      await player.play(step, isStopped: () => token != _runToken);

      if (token != _runToken) {
        return;
      }

      didAction = didAction || AutomationFlowPlayer.isAction(step);

      await mock.saveWalk(progress.atStep(progress.stepIndex + 1));

      notifyListeners();
    }
  }

  bool _shouldPause(
    AutomationCatalogueStep step,
    bool didAction, {
    required bool isUntilAction,
  }) {
    final isNextAction = didAction && AutomationFlowPlayer.isAction(step);

    return isUntilAction && (isNextAction || pendingFork != null);
  }

  void _recordFailure(int token, String reason) {
    if (token == _runToken) {
      walkFailure = reason;
      isWalkExpanded = true;
    }
  }

  Future<void> _finishAutorun() async {
    final current = walk;
    final variant = walkVariant;

    if (current == null || variant == null || walkFailure != null) {
      return;
    }

    if (current.mode != AutomationWalkMode.autorun || !isWalkFinished) {
      return;
    }

    runSummary = AutomationRunSummary(
      flow: current.flow,
      variant: current.variant,
      outcome: AutomationCatalogueText.english(variant.title, variant.name),
      stepCount: actionCount,
      duration: _runWatch?.elapsed ?? Duration.zero,
      requests: _readRunRequests(),
      shouldShowTouches: current.shouldShowTouches,
      shouldSignalEnd: current.shouldSignalEnd,
    );
    _runWatch = null;

    await mock.saveWalk(null);

    if (current.shouldSignalEnd) {
      await _signalEnd();
    }
  }

  List<AutomationCatalogueRequest> _readRunRequests() {
    return [
      for (final record in mock.journal.records)
        if (AutomationJournalRecord.pathOf(record) != null)
          AutomationCatalogueRequest(
            method: AutomationJournalRecord.methodOf(record),
            path: AutomationJournalRecord.pathOf(record) ?? '',
            statusCode: AutomationJournalRecord.statusCodeOf(record),
          ),
    ];
  }

  Future<void> _signalEnd() async {
    await HapticFeedback.vibrate();
    await SystemSound.play(SystemSoundType.alert);
  }
}
