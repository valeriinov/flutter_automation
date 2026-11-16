import 'package:flutter/widgets.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_scope.dart';

/// {@category Theme}
///
/// Every text the panel shows, in English.
///
/// A project that needs another language extends this class, overrides the
/// getters and the methods, and gives the subclass to
/// `AutomationPanelDefinition.strings`. The texts of the sections, the
/// profiles and the catalogue come from the project in the language of
/// [languageCode].
class AutomationPanelStrings {
  const AutomationPanelStrings();

  /// The strings of the nearest panel, the English strings outside one.
  ///
  /// The call does not subscribe [context] to the panel.
  static AutomationPanelStrings of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AutomationPanelScope>();

    return scope?.notifier?.definition.strings ??
        const AutomationPanelStrings();
  }

  /// Language code of the texts. The panel reads the texts of sections,
  /// profiles and flows under this key.
  String get languageCode => 'en';

  /// Badge of the QA button and of the panel head.
  String get qaBadge => 'QA';

  /// Tooltip of the button that goes back one page.
  String get back => 'Back';

  /// Tooltip of the cross of a sheet.
  String get close => 'Close';

  /// Tooltip of the cross of the panel.
  String get closePanel => 'Close panel';

  /// Button that closes a text dialog with no change.
  String get cancel => 'Cancel';

  /// Button that accepts the text of a dialog.
  String get ok => 'OK';

  /// Name of the state the mock starts with.
  String get defaultName => 'Default';

  /// Name of a value the tester typed.
  String get custom => 'Custom';

  /// Status row of the panel when the tester chose no outcome.
  String get defaultMock => 'Default mock';

  /// Status row of the panel when the tester changed the mock with no outcome
  /// or preset.
  String get customMock => 'Custom mock';

  /// Button that opens the presets.
  String get presets => 'Presets';

  /// Button that clears every override.
  String get reset => 'Reset';

  /// Label of the requests of a section.
  String get requests => 'Requests';

  /// Label of the profile of a section.
  String get profile => 'Profile';

  /// Label of the latency of the mock.
  String get responseLatency => 'Response latency';

  /// Latency profile with no delay.
  String get latencyFast => 'Fast';

  /// Latency profile with the delays of a real server.
  String get latencyRealistic => 'Real';

  /// Latency profile with long delays.
  String get latencySlow => 'Slow';

  /// Label of the latency choice of one request.
  String get requestLatency => 'Latency of this request';

  /// Note of the latency profile with no delay.
  String get noDelay => 'Answers at once, with no delay';

  /// Note of a profile that needs a restart.
  String get restartsTheApp => 'Restarts the app';

  /// Name of a request that never reaches the server.
  String get noNetwork => 'No network';

  /// Tooltip of the button that removes an override.
  String get removeOverride => 'Remove override';

  /// Title of the response sheet.
  String get response => 'Response';

  /// Label of the status codes.
  String get errorCode => 'Error code';

  /// Label of the backend error codes.
  String get backendErrorCode => 'Backend error code';

  /// Label and hint of the error message.
  String get message => 'Message';

  /// Note of the no network option.
  String get noNetworkNote => 'The request never reaches the server';

  /// Button that applies the override.
  String get apply => 'Apply';

  /// Button that clears the override of the request.
  String get useMockResponse => 'Use mock response';

  /// Title of the dialog that asks for a status code.
  String get statusCode => 'Status code';

  /// Hint of the preset name field.
  String get presetName => 'Preset name';

  /// Error of a preset name with a slash.
  String get presetNameRule => 'Use a name without a slash.';

  /// Button that saves the current state as a preset.
  String get saveCurrentState => 'Save current state';

  /// Tooltip of the button that deletes a preset.
  String get deletePreset => 'Delete preset';

  /// Title of the page that lists the changes of the mock.
  String get changes => 'Changes';

  /// Text of the Changes page when the mock holds its defaults.
  String get nothingChanged => 'Default mock. Nothing changed.';

  /// Button that removes every change of the mock.
  String get resetAll => 'Reset all';

  /// Label of the profiles on the Changes page.
  String get profiles => 'Profiles';

  /// Label of the scenario keys no section names, on the Changes page.
  String get otherSettings => 'Other settings';

  /// Hint of the search over the profiles of a section.
  String get profileSearchHint => 'Profile name or what it changes';

  /// What the Default profile of a section means.
  String get defaultProfileDescription =>
      'The section answers with the seed data of the mock.';

  /// Button that empties the journal.
  String get clearLog => 'Clear log';

  /// Title of the sheet that asks to empty the journal.
  String get clearLogQuestion => 'Clear the log?';

  /// What emptying the journal removes and what it keeps.
  String get clearLogMessage =>
      'The log loses every request it holds. The mock settings stay.';

  /// Title of the sheet that asks to reset a mock with no change to list.
  String get resetQuestion => 'Reset the mock?';

  /// What a reset of the mock removes.
  String get resetMessage =>
      'The outcome, the latency, the profiles and the request overrides go '
      'back to the defaults.';

  /// What applying a preset removes.
  String get applyPresetMessage =>
      'The preset replaces every current setting of the mock.';

  /// Button that deletes a preset in its confirmation sheet.
  String get delete => 'Delete';

  /// What deleting a preset means.
  String get deletePresetMessage => 'You cannot get the preset back.';

  /// Note of a confirmation sheet whose action restarts the app.
  String get appRestarts => 'The app restarts.';

  /// Title of the sheet that asks to apply a change that restarts the app.
  String get restartQuestion => 'Apply and restart the app?';

  /// What applying a change that restarts the app means.
  String get restartMessage =>
      'The change applies only after a restart of the app.';

  /// The error part of the note of a journal row answered by an override.
  String get errorAnswer => 'error';

  /// Text of an empty journal.
  String get noRequests => 'No requests yet';

  /// Title of the flows group with no group of its own.
  String get flows => 'Flows';

  /// Label of the tab that lists the flows.
  String get flowsTab => 'Flows';

  /// Label of the tab that lists the autoruns.
  String get autorunTab => 'Autorun';

  /// Label of the tab that lists the sections of the mock.
  String get sectionsTab => 'Sections';

  /// Label of the tab that lists the requests of the app.
  String get logTab => 'Log';

  /// Title of the screen that asks the tester to restart the app.
  String get restartScreenTitle => 'Close and open the app';

  /// Text of the screen that asks the tester to restart the app.
  String get restartScreenNote =>
      'The change applies when the app starts again.';

  /// Hint of the flow search field.
  String get flowSearchHint => 'Flow, outcome or request';

  /// Hint of the autorun search field.
  String get autorunSearchHint => 'Flow or outcome';

  /// Hint of the section search field.
  String get sectionSearchHint => 'Section or request';

  /// Hint of the journal search field.
  String get journalSearchHint => 'Method, path or status code';

  /// Text of a search that finds nothing.
  String get noMatches => 'Nothing matches the search';

  /// What the response sheet of a journal row names the mock answer.
  String get lastAnswer => 'last answer';

  /// Part of a flow description when the flow has a fork.
  String get oneFork => '1 fork';

  /// Title of the mock mode switch.
  String get mockMode => 'Mock mode';

  /// Note of the mock mode switch.
  String get mockModeNote => 'The app restarts when you switch';

  /// Label of the flow choice.
  String get flow => 'Flow';

  /// Label of the outcome choice.
  String get outcome => 'Outcome';

  /// Label of the recording options.
  String get recording => 'Recording';

  /// Title of the touch circles switch.
  String get showTouches => 'Show touches';

  /// Note of the touch circles switch.
  String get showTouchesNote => 'A circle where you tap';

  /// Title of the end signal switch.
  String get signalAtEnd => 'Signal at the end';

  /// Note of the end signal switch.
  String get signalAtEndNote => 'Vibration and sound';

  /// Note above the autorun button.
  String get autorunNote =>
      'The app restarts and runs the flow by itself. Start screen recording '
      'first.';

  /// Button that starts an autorun.
  String get restartAndRun => 'Restart and run';

  /// Note of the branches of a fork on the flow map.
  String get forkNote => 'The walk offers these branches at this step.';

  /// Prefix of the outcome on the flow map.
  String get resultPrefix => 'Result: ';

  /// Note above the button that starts a walk.
  String get walkRestartNote =>
      'The app restarts. Open it again to begin the walk.';

  /// Button that starts a walk.
  String get restartAndBegin => 'Restart and begin';

  /// Button that ends a walk or a run.
  String get exit => 'Exit';

  /// Button that does the next step of a walk.
  String get nextStep => 'Next step';

  /// Button that does the failed step again.
  String get tryAgain => 'Try again';

  /// Button that ends a walk and opens its summary.
  String get finish => 'Finish';

  /// Button text while the player does a step.
  String get working => 'Working…';

  /// Label of the next action of a walk.
  String get nextAction => 'Next action';

  /// Text of a walk with only waits left.
  String get waitsLeft => 'The waits that are left';

  /// Label of the branches of a fork.
  String get chooseBranch => 'Choose the branch';

  /// Text of a finished walk.
  String get walkFinished => 'The flow is finished. Tap Finish to see the run.';

  /// Label of the requests of a run.
  String get runRequests => 'Run requests';

  /// Button that shares the report of a run.
  String get shareLogs => 'Share logs';

  /// Button that starts the run again.
  String get runAgain => 'Run again';

  /// Title of the run summary.
  String get runFinished => 'Run finished';

  /// The step part of a finished walk.
  String get finished => 'finished';

  /// The start screen of a variant on the flow map.
  String startOf(String entry) => 'Start: $entry';

  /// The words of an override row.
  String overrideOf(String detail) => 'Override: $detail';

  /// The answer the mock gives to a request.
  String mockResponseOf(String description) {
    return 'Mock response: $description';
  }

  /// The head of the expanded walk plaque.
  String stepOf(int number, int count) => 'step $number of $count';

  /// The step of the collapsed walk plaque.
  String stepShort(int number, int count) => '$number/$count';

  /// The delay range of a latency profile, in milliseconds.
  String delayOf(int minMs, int maxMs) {
    return 'Answers in $minMs–$maxMs ms';
  }

  /// The latency line of a request that follows every request.
  String asEveryRequest(String delay) => 'As every request. $delay';

  /// The note of a journal row whose answer an override gave.
  String answeredByOverride(String detail) {
    return 'Answered by an override: $detail';
  }

  /// The latency part of an override row.
  String latencyOverrideOf(String profile) => '$profile latency';

  /// How long a run took.
  String seconds(int seconds) => '$seconds s';

  /// Title of the sheet that asks to apply the preset [name].
  String applyPresetQuestion(String name) => 'Apply "$name"?';

  /// Title of the sheet that asks to delete the preset [name].
  String deletePresetQuestion(String name) => 'Delete "$name"?';

  /// Title of the sheet that asks to reset the mock, with [changes] that
  /// counts its changes.
  String resetChangesQuestion(String changes) => 'Reset $changes?';

  /// Why a step failed with an error the player did not expect.
  String stepFailed(Object error) => 'The step failed: $error';

  /// Why the player cannot play the step named [step]: it carries no action.
  String stepHasNoAction(String step) {
    return '"$step" carries no action. Build the catalogue again.';
  }

  /// Why the player cannot play the step named [step]: its [action] is
  /// unknown to the player.
  String stepHasUnknownAction(String step, String action) {
    return '"$step" is a "$action" step. The player cannot play it.';
  }

  /// Why the player cannot play the step named [step]: it names no element.
  String stepHasNoTarget(String step) => '"$step" names no element to act on.';

  /// Why a wait failed: the target of [step] did not appear within
  /// [timeout].
  String stepDidNotAppear(String step, String timeout) {
    return '"$step" did not appear in $timeout.';
  }

  /// Why a wait failed: the target of [step] did not go within [timeout].
  String stepDidNotGo(String step, String timeout) {
    return '"$step" did not go in $timeout.';
  }

  /// Why a wait failed: the target of [step] did not become tappable within
  /// [timeout].
  String stepDidNotBecomeTappable(String step, String timeout) {
    return '"$step" did not become tappable in $timeout.';
  }

  /// Why a tap failed: the player cannot tap the target of [step].
  String stepCannotBeTapped(String step) => '"$step" cannot be tapped.';

  /// Why a text step failed: no text field has the focus.
  String get noFocusedTextField {
    return 'No text field has the focus. Tap the field before the text.';
  }

  /// Why a walk ended: the tester stopped it.
  String get walkStopped => 'The walk stopped.';

  /// The words for a timeout of [milliseconds], such as `500 ms`.
  String timeoutMilliseconds(int milliseconds) => '$milliseconds ms';

  /// The words for a timeout of [seconds], such as `5 s`.
  String timeoutSeconds(int seconds) => '$seconds s';

  /// Name of the latency [profile].
  String latencyLabel(MockLatencyProfile profile) {
    return switch (profile) {
      MockLatencyProfile.fast => latencyFast,
      MockLatencyProfile.realistic => latencyRealistic,
      MockLatencyProfile.slow => latencySlow,
    };
  }

  /// Title of the sheet that picks a profile of the section [sectionTitle].
  String profileSheetTitle(String sectionTitle) => '$sectionTitle profile';

  /// The words that count the steps, such as `1 step` or `3 steps`.
  String stepCount(int count) => _countOf(count, 'step');

  /// The words that count the outcomes of a flow.
  String variantCount(int count) => _countOf(count, 'outcome');

  /// The words that count the overrides of the panel.
  String overrideCount(int count) => _countOf(count, 'override');

  /// The words that count the requests of the journal.
  String requestCount(int count) => _countOf(count, 'request');

  /// The words that count the changes of the mock.
  String changeCount(int count) => _countOf(count, 'change');

  String _countOf(int count, String noun) {
    return '$count ${count == 1 ? noun : '${noun}s'}';
  }
}
