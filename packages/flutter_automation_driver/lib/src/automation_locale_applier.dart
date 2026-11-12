import 'dart:async';

/// Applies a language to the app when the `locale.apply` command arrives.
///
/// The [languageCode] parameter is the language code the run asks for.
typedef AutomationLocaleApplier = FutureOr<void> Function(String languageCode);
