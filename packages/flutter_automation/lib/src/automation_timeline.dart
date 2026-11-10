import 'dart:developer';

import 'package:flutter_automation/src/automation_settings.dart';
import 'package:flutter_automation/src/automation_timeline_label.dart';

/// {@category Utils}
///
/// Names the app's own work inside a traced frame.
///
/// The frame summary of an automation run reads the timeline back. It lists
/// what stood inside the widest build frame of the window. The engine's own
/// spans stop at `BUILD`. A span opened here puts the app's part of that frame
/// under a name of its own. A round that works on a slow frame then starts from
/// the widget that owns it, not from a guess.
///
/// [AutomationSettings.isEnabled], a compile-time constant, gates every call. A
/// build without the automation switch drops the spans together with the branch
/// that opens them. The code computes the work that a mark reports behind that
/// gate, not at the call site.
abstract final class AutomationTimeline {
  /// Runs [body] inside a timeline span and answers what it returned.
  ///
  /// The [name] parameter is the name that the span carries in the timeline. It
  /// reads back beside the engine's own `BUILD` and `LAYOUT` rows.
  /// The [body] parameter is the work the span measures.
  static T span<T>(AutomationTimelineLabel name, T Function() body) {
    if (!AutomationSettings.isEnabled) {
      return body();
    }

    return Timeline.timeSync(name.label, body);
  }

  /// Marks the point in time of the call.
  ///
  /// The [name] parameter is the name of the mark in the timeline. The mark has
  /// no duration. It records the moment of the call.
  ///
  /// The [arguments] parameter returns the values the mark carries beside its
  /// name. It is a callback, not the map itself, so a build without the switch
  /// never assembles one.
  static void instant(
    AutomationTimelineLabel name, {
    Map<String, Object?> Function()? arguments,
  }) {
    if (!AutomationSettings.isEnabled) {
      return;
    }

    Timeline.instantSync(name.label, arguments: arguments?.call());
  }
}
