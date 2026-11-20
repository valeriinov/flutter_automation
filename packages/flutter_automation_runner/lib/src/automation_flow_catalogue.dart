import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_runner/src/automation_block_library.dart';
import 'package:flutter_automation_runner/src/automation_finder_kind.dart';
import 'package:flutter_automation_runner/src/automation_flow.dart';
import 'package:flutter_automation_runner/src/automation_runner_config.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

/// {@category Utils}
///
/// Each flow and each block of a project, as the decoded JSON objects the
/// `--catalogue` command of its runner prints, before a `Use` expands.
///
/// The catalogue holds the flows that measure motion with a `probeSeries`
/// step too.
///
/// A process reads the catalogue of one root once.
/// A second read of the same root takes the first answer.
final class AutomationFlowCatalogue {
  static final _byRoot = <String, AutomationFlowCatalogue>{};

  static const _flowsKey = 'flows';
  static const _blocksKey = 'blocks';
  static const _errorKey = 'error';
  static const _variantsKey = 'variants';
  static const _pubspecPath = 'pubspec.yaml';

  /// The directory the runner starts in and the `pubspec.yaml` of the project
  /// stands in.
  final String rootPath;

  /// Flow objects by flow name, in the order the runner lists them.
  ///
  /// The map is a read-only copy of the map the constructor received.
  final Map<String, Object?> flows;

  /// Block objects by block name.
  ///
  /// The map is a read-only copy of the map the constructor received.
  final Map<String, Object?> blocks;

  late final AutomationBlockLibrary _blockLibrary =
      AutomationBlockLibrary.fromJson(blocks);

  late final AutomationRunnerConfig _config = AutomationRunnerConfig.read(
    '$rootPath/$_pubspecPath',
  );

  AutomationFlowCatalogue({
    required this.rootPath,
    required Map<String, Object?> flows,
    required Map<String, Object?> blocks,
  }) : flows = Map.unmodifiable(flows),
       blocks = Map.unmodifiable(blocks);

  /// The catalogue of the runner that starts at [runnerEntry] in [rootPath].
  ///
  /// The [commandPrefix] parameter holds the words put before `dart`, such as
  /// `['fvm']`; it is empty when the project calls `dart` directly.
  ///
  /// Throws an [AutomationRunnerException] when the runner fails.
  factory AutomationFlowCatalogue.read(
    String rootPath,
    String runnerEntry, {
    List<String> commandPrefix = const [],
  }) {
    return _byRoot[rootPath] ??= _run(rootPath, runnerEntry, commandPrefix);
  }

  /// Decodes the [text] the runner printed for `--catalogue`.
  ///
  /// Throws an [AutomationRunnerException] when the text is the error line of
  /// the runner or holds no flows or no blocks object.
  factory AutomationFlowCatalogue.decode(
    String text, {
    required String rootPath,
  }) {
    final json = _decodeObject(text, 'The runner catalogue');
    final error = json[_errorKey];

    if (error != null) {
      throw AutomationRunnerException('The runner failed: $error');
    }

    return AutomationFlowCatalogue(
      rootPath: rootPath,
      flows: _readObject(json[_flowsKey], 'The flows of the runner catalogue'),
      blocks: _readObject(
        json[_blocksKey],
        'The blocks of the runner catalogue',
      ),
    );
  }

  /// Makes the reads of the root of [catalogue] answer with it, so a test
  /// holds the flows in memory and starts no runner.
  static void seed(AutomationFlowCatalogue catalogue) {
    _byRoot[catalogue.rootPath] = catalogue;
  }

  /// The `defaultLocale` of the project.
  String get defaultLocale => _config.defaultLocale;

  /// The finder kinds of the built-in set and the ones the project declares.
  AutomationFinderRegistry get finders => _config.finderRegistry;

  /// Whether a run of the flow [name] that names no variant walks [variant].
  ///
  /// The default variant is the declared `defaultVariant`, else the only
  /// variant. Throws an [AutomationRunnerException] when the flow is not a
  /// JSON object.
  bool isDefaultVariant(String name, String variant) {
    final json = _readObject(flows[name], 'The flow "$name"');
    final variants = json[_variantsKey];

    if (variants is! Map<String, Object?>) {
      return false;
    }

    return AutomationFlow.resolveDefaultVariant(
          json['defaultVariant'],
          variants,
        ) ==
        variant;
  }

  /// Each variant of each flow, resolved for [locale] and in the order of
  /// [flows].
  ///
  /// The default [locale] is the `defaultLocale` of the project.
  /// Throws an [AutomationRunnerException] when a flow has no `variants` map.
  List<AutomationFlow> resolveFlows({String? locale}) {
    return [
      for (final MapEntry(key: name, value: flow) in flows.entries)
        for (final variant in _readVariantNames(name, flow))
          resolveFlow(name, variant, locale: locale),
    ];
  }

  /// The variant [variant] of the flow [name], resolved for [locale].
  ///
  /// The default [locale] is the `defaultLocale` of the project.
  AutomationFlow resolveFlow(String name, String variant, {String? locale}) {
    return AutomationFlow.fromJson(
      name: name,
      variant: variant,
      json: flows[name],
      blocks: _blockLibrary,
      finders: _config.finderRegistry,
      locale: locale ?? _config.defaultLocale,
    );
  }

  static Iterable<String> _readVariantNames(String name, Object? flow) {
    final json = _readObject(flow, 'The flow "$name"');
    final variants = json[_variantsKey];

    if (variants is! Map<String, Object?>) {
      throw AutomationRunnerException(
        'Flow "$name" has no "$_variantsKey" map.',
      );
    }

    return variants.keys;
  }

  static AutomationFlowCatalogue _run(
    String rootPath,
    String runnerEntry,
    List<String> commandPrefix,
  ) {
    final words = [...commandPrefix, 'dart'];
    final result = Process.runSync(words.first, [
      ...words.skip(1),
      'run',
      runnerEntry,
      '--catalogue',
    ], workingDirectory: rootPath);
    final lines = (result.stdout as String).trimRight().split('\n');

    if (result.exitCode != 0) {
      throw AutomationRunnerException(
        'The runner exited with ${result.exitCode}: ${result.stderr}',
      );
    }

    return AutomationFlowCatalogue.decode(lines.last, rootPath: rootPath);
  }

  static Map<String, Object?> _decodeObject(String text, String subject) {
    try {
      return _readObject(jsonDecode(text), subject);
    } on FormatException catch (error) {
      throw AutomationRunnerException('$subject is not JSON: ${error.message}');
    }
  }

  static Map<String, Object?> _readObject(Object? json, String subject) {
    if (json is Map<String, Object?>) {
      return json;
    }

    throw AutomationRunnerException('$subject is not a JSON object.');
  }
}
