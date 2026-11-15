import 'package:flutter_automation_runner/flutter_automation_runner.dart';

import 'flows/catalog_flow.dart';
import 'package:example/mock/catalog_mock_section.dart';

/// Entry point of the runner:
/// `fvm dart run tool/run_flows.dart catalog items`.
Future<void> main(List<String> args) {
  return runFlows(args, [catalogFlow], sections: [catalogMockSection]);
}
