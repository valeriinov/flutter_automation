/// {@category Theme}
///
/// Every text the panel shows. The panel is English only, and its widgets take
/// their texts only from here.
abstract final class AutomationPanelStrings {
  /// Badge of the QA button and of the panel head.
  static const qaBadge = 'QA';

  /// Tooltip of the button that goes back one page.
  static const back = 'Back';

  /// Tooltip of the cross of a sheet.
  static const close = 'Close';

  /// Tooltip of the cross of the panel.
  static const closePanel = 'Close panel';

  /// Button that closes a text dialog with no change.
  static const cancel = 'Cancel';

  /// Button that accepts the text of a dialog.
  static const ok = 'OK';

  /// Name of the state the mock starts with.
  static const defaultName = 'Default';

  /// Name of a value the tester typed.
  static const custom = 'Custom';

  /// Status row of the panel when the tester chose no outcome.
  static const defaultMock = 'Default mock';

  /// Button that opens the presets.
  static const presets = 'Presets';

  /// Button that clears every override.
  static const reset = 'Reset';

  /// Label of the requests of a section.
  static const requests = 'Requests';

  /// Label of the profile of a section.
  static const profile = 'Profile';

  /// Label of the latency of the mock.
  static const responseLatency = 'Response latency';

  /// Latency profile with no delay.
  static const latencyFast = 'Fast';

  /// Latency profile with the delays of a real server.
  static const latencyRealistic = 'Real';

  /// Latency profile with long delays.
  static const latencySlow = 'Slow';

  /// Note of a profile that needs a restart.
  static const restartsTheApp = '⟳ Restarts the app';

  /// Name of a request that never reaches the server.
  static const noNetwork = 'No network';

  /// Tooltip of the button that removes an override.
  static const removeOverride = 'Remove override';

  /// Title of the response sheet.
  static const response = 'Response';

  /// Label of the status codes.
  static const errorCode = 'Error code';

  /// Label of the backend error codes.
  static const backendErrorCode = 'Backend error code';

  /// Label and hint of the error message.
  static const message = 'Message';

  /// Note of the no network option.
  static const noNetworkNote = 'The request never reaches the server';

  /// Button that applies the override.
  static const apply = 'Apply';

  /// Button that clears the override of the request.
  static const useMockResponse = 'Use mock response';

  /// Title of the dialog that asks for a status code.
  static const statusCode = 'Status code';

  /// Hint of the preset name field.
  static const presetName = 'Preset name';

  /// Error of a preset name with a slash.
  static const presetNameRule = 'Use a name without a slash.';

  /// Button that saves the current state as a preset.
  static const saveCurrentState = 'Save current state';

  /// Tooltip of the button that deletes a preset.
  static const deletePreset = 'Delete preset';

  /// Text of an empty journal.
  static const noRequests = 'No requests yet';

  /// Title of the flows group with no group of its own.
  static const flows = 'Flows';

  /// Hint of the flow search field.
  static const flowSearchHint = 'Flow, outcome or request';

  /// Hint of the autorun search field.
  static const autorunSearchHint = 'Flow or outcome';

  /// Hint of the section search field.
  static const sectionSearchHint = 'Section or request';

  /// Hint of the journal search field.
  static const journalSearchHint = 'Method, path or status code';

  /// Text of a search that finds nothing.
  static const noMatches = 'Nothing matches the search';

  /// What the response sheet of a journal row names the mock answer.
  static const lastAnswer = 'last answer';

  /// Part of a flow description when the flow has a fork.
  static const oneFork = '1 fork';

  /// Title of the mock mode switch.
  static const mockMode = 'Mock mode';

  /// Note of the mock mode switch.
  static const mockModeNote = 'The app restarts when you switch';

  /// Label of the flow choice.
  static const flow = 'Flow';

  /// Label of the outcome choice.
  static const outcome = 'Outcome';

  /// Label of the recording options.
  static const recording = 'Recording';

  /// Title of the touch circles switch.
  static const showTouches = 'Show touches';

  /// Note of the touch circles switch.
  static const showTouchesNote = 'A circle where you tap';

  /// Title of the end signal switch.
  static const signalAtEnd = 'Signal at the end';

  /// Note of the end signal switch.
  static const signalAtEndNote = 'Vibration and sound';

  /// Note above the autorun button.
  static const autorunNote =
      'The app restarts and runs the flow by itself. Start screen recording '
      'first.';

  /// Button that starts an autorun.
  static const restartAndRun = 'Restart and run';

  /// Note of the branches of a fork on the flow map.
  static const forkNote = 'The walk offers these branches at this step.';

  /// Prefix of the outcome on the flow map.
  static const resultPrefix = 'Result: ';

  /// Note above the button that starts a walk.
  static const walkRestartNote =
      'The app restarts. Open it again to begin the walk.';

  /// Button that starts a walk.
  static const restartAndBegin = 'Restart and begin';

  /// Button that ends a walk or a run.
  static const exit = 'Exit';

  /// Button that does the next step of a walk.
  static const nextStep = 'Next step';

  /// Button that does the failed step again.
  static const tryAgain = 'Try again';

  /// Button that ends a walk and opens its summary.
  static const finish = 'Finish';

  /// Button text while the player does a step.
  static const working = 'Working…';

  /// Label of the next action of a walk.
  static const nextAction = 'Next action';

  /// Text of a walk with only waits left.
  static const waitsLeft = 'The waits that are left';

  /// Label of the branches of a fork.
  static const chooseBranch = 'Choose the branch';

  /// Text of a finished walk.
  static const walkFinished =
      'The flow is finished. Tap Finish to see the run.';

  /// Label of the requests of a run.
  static const runRequests = 'Run requests';

  /// Button that shares the report of a run.
  static const shareLogs = 'Share logs';

  /// Button that starts the run again.
  static const runAgain = 'Run again';

  /// Title of the run summary.
  static const runFinished = 'Run finished';

  /// The step part of a finished walk.
  static const finished = 'finished';

  /// Noun that counts steps.
  static const stepNoun = 'step';

  /// Noun that counts outcomes.
  static const outcomeNoun = 'outcome';

  /// Noun that counts overrides.
  static const overrideNoun = 'override';

  /// The start screen of a variant on the flow map.
  static String startOf(String entry) => 'Start: $entry';

  /// The words of an override row.
  static String overrideOf(String detail) => 'Override: $detail';

  /// The answer the mock gives to a request.
  static String mockResponseOf(String description) {
    return 'Mock response: $description';
  }

  /// The head of the expanded walk plaque.
  static String stepOf(int number, int count) => 'step $number of $count';

  /// The step of the collapsed walk plaque.
  static String stepShort(int number, int count) => '$number/$count';

  /// How long a run took.
  static String seconds(int seconds) => '$seconds s';

  /// Why a step failed with an error the player did not expect.
  static String stepFailed(Object error) => 'The step failed: $error';
}
