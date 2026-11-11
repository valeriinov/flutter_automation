import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_runner/src/automation_runner.dart';
import 'package:flutter_automation_runner/src/automation_runner_config.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';
import 'package:flutter_automation_runner/src/definition/automation_flow_definition.dart';
import 'package:flutter_automation_runner/src/definition/flow_block.dart';

/// {@category Utils}
///
/// Runs the flow that [args] name, out of the flows and blocks the project
/// declares in Dart.
///
/// A project calls it from its entry point. The first argument is the flow
/// name. A failure that the runner names prints its message to stderr and ends
/// the last stdout line with `{"error": "<message>"}`, so a caller parses one
/// line. The process then exits with the error exit code.
///
/// The [args] parameter is the command line. The [flows] parameter holds the
/// flows a run may ask for. The [blocks] parameter holds the blocks their
/// variants use. The [config] parameter is the project's values, read from
/// `pubspec.yaml` of the working directory when the caller passes none.
Future<void> runFlows(
  List<String> args,
  List<AutomationFlowDefinition> flows,
  List<FlowBlock> blocks, {
  AutomationRunnerConfig? config,
}) async {
  try {
    await AutomationRunner.fromDefinitions(
      args,
      config: config ?? AutomationRunnerConfig.read(),
      flows: flows,
      blocks: blocks,
    ).run();
  } on AutomationRunnerException catch (error) {
    stderr.writeln(error.message);
    // The last stdout line is the report whatever happened, so a caller parses
    // one line instead of telling a failure apart from a wrapper's banner.
    stdout.writeln(jsonEncode({'error': error.message}));
    // A refused connection leaves the vm_service retry loop scheduled, and the
    // isolate outlives main while it runs. Leave through exit() instead.
    exit(AutomationRunnerException.errorExitCode);
  }
}
