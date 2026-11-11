import 'package:flutter_automation_runner/flutter_automation_runner.dart';

import 'flows/catalog_flow.dart';

/// Entry point of the runner:
/// `fvm dart run tool/run_flows.dart catalog items`.
Future<void> main(List<String> args) {
  return runFlows(args, [catalogFlow], [signIn]);
}
