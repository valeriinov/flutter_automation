import 'package:flutter_automation/flutter_automation.dart';

/// Whether the app runs on the mock backend.
///
/// A compile-time constant of this project: a release build folds it to false
/// and drops the mock code behind it. [AutomationSettings.isEnabled] is false
/// in a release build, so no define turns the mock on there.
const bool isMockEnabled =
    AutomationSettings.isEnabled && bool.fromEnvironment('ENABLE_MOCK');
