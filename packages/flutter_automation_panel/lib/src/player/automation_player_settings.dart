import 'package:flutter/foundation.dart';

/// {@category Utils}
///
/// What the player needs from the project to read a step, and how fast it
/// moves.
///
/// The date formats and the date key templates come from the catalogue, which
/// the runner builds out of the `flutter_automation:` section of the project
/// `pubspec.yaml`.
@immutable
final class AutomationPlayerSettings {
  /// Reads the language code of the app, such as `en`. A finder that holds a
  /// text per locale takes the entry of this code.
  final String Function()? readLocale;

  /// Time between two looks at the screen while the player waits.
  final Duration pollInterval;

  /// Time the player waits after a step so the screen settles.
  final Duration settleDelay;

  /// Time the touch circle shows before the finger goes down.
  final Duration touchLead;

  /// Time between a finger down and a finger up of a tap.
  final Duration touchHold;

  /// Time the touch circle stays after the finger goes up.
  final Duration touchTrail;

  /// Time the player gives a step that sets none.
  final Duration defaultTimeout;

  const AutomationPlayerSettings({
    this.readLocale,
    this.pollInterval = const Duration(milliseconds: 100),
    this.settleDelay = const Duration(milliseconds: 350),
    this.touchLead = const Duration(milliseconds: 250),
    this.touchHold = const Duration(milliseconds: 60),
    this.touchTrail = const Duration(milliseconds: 200),
    this.defaultTimeout = const Duration(seconds: 10),
  });
}
