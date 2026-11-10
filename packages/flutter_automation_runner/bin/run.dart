import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_runner/flutter_automation_runner.dart';

Future<void> main(List<String> args) async {
  try {
    final config = AutomationRunnerConfig.read();

    await AutomationRunner(args, config: config).run();
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
