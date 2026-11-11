import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_failure.dart';
import 'package:flutter_automation_mock/src/mock_scenario_file.dart';
import 'package:flutter_automation_mock/src/scenario/mock_commands.dart';
import 'package:flutter_automation_mock/src/scenario/mock_feature.dart';
import 'package:flutter_automation_mock/src/scenario/mock_scenario.dart';
import 'package:flutter_automation_mock/src/state/mock_frame_texts.dart';
import 'package:flutter_automation_mock/src/state/mock_frame_widgets.dart';
import 'package:flutter_automation_mock/src/state/mock_journal.dart';
import 'package:flutter_automation_mock/src/transport/mock_latency.dart';
import 'package:flutter_automation_mock/src/transport/mock_latency_profile.dart';

/// {@category Utils}
///
/// Hook the project runs after the mock applied the [scenario] of a run.
typedef MockApplyCallback = FutureOr<void> Function(MockScenario scenario);

/// {@category Utils}
///
/// Hook the project runs after the mock took the [languageCode] of a run.
typedef MockLocaleCallback = FutureOr<void> Function(String languageCode);

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
/// An enabled mock registers three commands in [AutomationCommandHandler]:
///
/// - `mock.apply` takes `{"config": <scenario JSON>}`, saves the scenario for
///   the next launch, runs `onApply` and empties the [journal]. It answers
///   `{"latency": <name>, "failures": [<path>]}`.
/// - `journal.read` takes `{"texts": bool, "widgets": bool}` and answers
///   `{"records": [...], "launch": {...}}` with `"texts"` and `"widgets"` of
///   the frame when asked. It empties the [journal].
/// - `locale.apply` takes `{"locale": <language code>}`, runs `onLocale` and
///   answers `{"locale": <language code>}`.
class AutomationMock {
  static const _defaultLatencySeed = 0;
  static const _configKey = 'config';
  static const _localeKey = 'locale';
  static const _recordsKey = 'records';
  static const _launchKey = 'launch';
  static const _textsKey = 'texts';
  static const _widgetsKey = 'widgets';
  static const _failuresKey = 'failures';
  static const _defaultJournalResponseTimeout = Duration(seconds: 10);

  /// What the app did while a run walked it.
  final MockJournal journal = MockJournal();

  /// Sections of the mock the project declared.
  ///
  /// The package keeps the list for tools that build a form from the field
  /// schema. Nothing in the package reads it.
  final List<MockFeature<Object?>> features;

  /// Whether the app runs on the mock.
  final bool isEnabled;

  final String _scenarioDirectory;
  final MockApplyCallback? _onApply;
  final MockLocaleCallback? _onLocale;
  final Duration _journalResponseTimeout;

  MockScenario _scenario;
  String? _languageCode;

  AutomationMock._({
    required this.isEnabled,
    required this.features,
    required String scenarioDirectory,
    required MockApplyCallback? onApply,
    required MockLocaleCallback? onLocale,
    required Duration journalResponseTimeout,
  }) : _scenarioDirectory = scenarioDirectory,
       _scenario = const MockScenario([]),
       _onApply = onApply,
       _onLocale = onLocale,
       _journalResponseTimeout = journalResponseTimeout;

  /// Starts the mock before the dependency injection of the project.
  ///
  /// The scenario of the run is the one the previous `mock.apply` saved in
  /// [scenarioDirectory], or an empty one when it saved none. The launch reads
  /// the file once and removes it.
  ///
  /// The [isEnabled] parameter is the project's decision to run on the mock.
  /// The [scenarioDirectory] parameter is a writable folder that holds the
  /// scenario file between launches.
  /// The [features] parameter lists the sections of the mock; the package only
  /// keeps it.
  /// The [onApply] parameter runs after `mock.apply` applied its own part.
  /// The [onLocale] parameter runs after `locale.apply` took the language.
  /// The [journalResponseTimeout] parameter bounds how long `journal.read`
  /// waits for the requests that the mock still has to answer.
  static Future<AutomationMock> init({
    required bool isEnabled,
    required String scenarioDirectory,
    List<MockFeature<Object?>> features = const [],
    MockApplyCallback? onApply,
    MockLocaleCallback? onLocale,
    Duration journalResponseTimeout = _defaultJournalResponseTimeout,
  }) {
    // The AOT compiler drops the fakes of a release build only while the
    // constructor runs outside an async body and gets a constant isEnabled.
    return AutomationMock._(
      isEnabled: isEnabled,
      features: features,
      scenarioDirectory: scenarioDirectory,
      onApply: onApply,
      onLocale: onLocale,
      journalResponseTimeout: journalResponseTimeout,
    )._start();
  }

  /// Scenario of the run: the saved one at launch, the applied one after
  /// `mock.apply`.
  MockScenario get scenario => _scenario;

  /// Latency of a mocked answer: the profile of the `latency` key of the
  /// [scenario] (`realistic` when absent or unknown) and the `latencySeed` key
  /// (0 when absent).
  MockLatency get latency {
    final json = _scenario.toJson();
    final seed = json[MockScenario.latencySeedKey];
    final profileName = json[MockScenario.latencyKey];

    return MockLatency(
      profile:
          MockLatencyProfile.values.asNameMap()[profileName] ??
          MockLatencyProfile.realistic,
      seed: seed is int ? seed : _defaultLatencySeed,
    );
  }

  /// Failed paths of the `failures` key of the [scenario]: path to failure.
  Map<String, MockApiFailure> get failures {
    final failures = _scenario.toJson()[MockScenario.failuresKey];

    if (failures is! Map<String, Object?>) {
      return const {};
    }

    return {
      for (final MapEntry(:key, :value) in failures.entries)
        if (value is Map<String, Object?>) key: MockApiFailure.fromJson(value),
    };
  }

  /// Language code the last `locale.apply` took, null before it.
  String? get languageCode => _languageCode;

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

  /// Settings of [feature] in the current [scenario].
  S settingsOf<S>(MockFeature<S> feature) => scenario.settingsOf(feature);

  Future<AutomationMock> _start() async {
    if (isEnabled) {
      final scenarioJson = await MockScenarioFile.consume(_scenarioDirectory);

      _scenario = MockScenario.fromJson(scenarioJson);

      _registerCommands();
    }

    return this;
  }

  void _registerCommands() {
    AutomationCommandHandler.register(MockCommands.apply, _applyScenario);
    AutomationCommandHandler.register(MockCommands.journalRead, _readJournal);
    AutomationCommandHandler.register(MockCommands.localeApply, _applyLocale);
  }

  // The journal is emptied last, so a run reads only what the app did after the
  // scenario was applied.
  Future<String> _applyScenario(Map<String, Object?> payload) async {
    final config = _readConfig(payload);

    await MockScenarioFile.save(_scenarioDirectory, config);

    _scenario = MockScenario.fromJson(config);

    await _onApply?.call(_scenario);

    journal.clear();

    return jsonEncode(_buildApplyAnswer(_scenario.toJson()));
  }

  Future<String> _readJournal(Map<String, Object?> payload) async {
    await _waitForResponses();

    return jsonEncode({
      _recordsKey: journal.readAndClear(),
      _launchKey: journal.launch,
      if (payload[_textsKey] == true)
        _textsKey: ?_tryReadFrame(MockFrameTexts.read),
      if (payload[_widgetsKey] == true)
        _widgetsKey: ?_tryReadFrame(MockFrameWidgets.read),
    });
  }

  Future<String> _applyLocale(Map<String, Object?> payload) async {
    final languageCode = _readLanguageCode(payload);

    _languageCode = languageCode;

    await _onLocale?.call(languageCode);

    return jsonEncode({_localeKey: languageCode});
  }

  Map<String, Object?> _readConfig(Map<String, Object?> payload) {
    final config = payload[_configKey];

    if (config is! Map<String, Object?>) {
      throw StateError(
        'The "${MockCommands.apply}" command needs a "$_configKey" object.',
      );
    }

    return config;
  }

  String _readLanguageCode(Map<String, Object?> payload) {
    final languageCode = payload[_localeKey];

    if (languageCode is! String) {
      throw StateError(
        'The "${MockCommands.localeApply}" command needs a '
        '"$_localeKey" string.',
      );
    }

    return languageCode;
  }

  Map<String, Object?> _buildApplyAnswer(Map<String, Object?> scenarioJson) {
    final failures = scenarioJson[MockScenario.failuresKey];

    return {
      MockScenario.latencyKey: latency.profile.name,
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

  List<String>? _tryReadFrame(
    List<String> Function(Element root, Rect window) read,
  ) {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    final rootElement = WidgetsBinding.instance.rootElement;

    if (view == null || rootElement == null) {
      return null;
    }

    final windowSize = view.physicalSize / view.devicePixelRatio;

    return read(rootElement, Offset.zero & windowSize);
  }
}
