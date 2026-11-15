/// Whether the app runs on the mock backend.
///
/// A compile-time constant of this project: a build without the define folds
/// it to false and drops the mock code behind it. A QA release build sets the
/// define next to `ENABLE_AUTOMATION_MARKING`.
const bool isMockEnabled = bool.fromEnvironment('ENABLE_MOCK');
